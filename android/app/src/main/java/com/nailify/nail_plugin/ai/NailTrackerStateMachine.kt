/*
 * NailTrackerStateMachine.kt — Hybrid tracking pipeline.
 *
 * ═══════════════════════════════════════════════════════════════
 * GIẢI PHÁP B: MediaPipe State Machine Tracking
 * ═══════════════════════════════════════════════════════════════
 *
 * VẤN ĐỀ CŨ: Render frame CHỜ AI YOLO chạy (~400ms / frame) → FPS render
 * thấp, móng giật/lag khi tay di chuyển.
 *
 * GIẢI PHÁP: Tách rõ 2 phase:
 *
 *   1. SEARCHING (YOLO): Khi mới bắt đầu hoặc vừa mất dấu, gọi YOLO để
 *      "khóa" (anchor) móng với các hằng số sinh trắc học:
 *        - nailCenterRef  : centroid móng (pixel)
 *        - anchorJointRef : tọa độ khớp PIP lúc khóa (pixel)
 *        - polygonTemplate: polygon gốc của YOLO (lưu trữ raw, KHÔNG tổng hợp)
 *        - bbox ref / scale reference
 *
 *   2. TRACKING (MediaPipe, mỗi camera frame): YOLO KHÔNG chạy. Dùng
 *      MediaPipe Hand Landmarker để bám theo khớp PIP hiện tại → Affine
 *      transform polygon gốc bám theo chuyển động tay ở tốc độ camera
 *      (15-25 FPS render). Hình dạng polygon BẢO TOÀN 100% từ YOLO.
 *
 *   3. LOST: Khi MediaPipe không tìm thấy tay (landmarks rỗng) → xóa
 *      toàn bộ tracks và quay về SEARCHING ở frame tiếp theo có tay.
 *
 * Thuật toán Affine (giữ polygon YOLO gốc):
 *
 *      delta_old  = nailCenterRef - anchorJointRef
 *      delta_new  = nailCenterNew - anchorJointNew
 *
 *      Mỗi điểm P của polygon gốc:
 *          local  = P - nailCenterRef
 *          P_new  = nailCenterNew + local * (length_new / length_old)
 *
 * Vì nailCenter được derive dựa trên anchorJoint offset (constant vector lúc
 * khóa), nên khi anchorJoint dịch chuyển, nailCenter dịch đúng cùng vector.
 * Scale factor = distance(pip_new, tip_new) / distance(pip_ref, tip_ref).
 *
 * KHÔI PHỤC: Khi nhận YOLO detection mới (SEARCHING xong), reset constants.
 */
package com.nailify.nail_plugin.ai

import android.graphics.PointF
import android.util.Log
import kotlin.math.hypot

class NailTrackerStateMachine {

    companion object {
        private const val TAG = "NailTrackerStateMachine"

        /** Số frame tracking liên tiếp mất MediaPipe → chuyển LOST. */
        private const val LOST_AFTER_MISS_FRAMES = 3

        /**
         * YOLO YÊU CẦU detection có confidence ≥ threshold này mới tính là
         * SEARCHING thành công (re-anchor).
         */
        private const val SEARCHING_MIN_CONFIDENCE = 0.6f

        /**
         * Độ dịch chuyển tối đa giữa MediaPipe joints (normalized) trên 2 frame
         * liên tiếp để coi là "outlier"; nếu lớn hơn thì fallback về detection
         * gốc.
         */
        private const val JOINT_JUMP_THRESHOLD = 0.15f
    }

    enum class Phase { SEARCHING, TRACKING, LOST }

    /**
     * Per-class state lưu trữ giữa các frame.
     *
     * @property nailCenterRef   Centroid móng YOLO lúc anchor (pixel).
     * @property anchorJointRef  Tọa độ khớp anchor (PIP) lúc anchor (pixel).
     * @property tipRef          Tọa độ đầu ngón lúc anchor (pixel).
     * @property bboxRef         BBox gốc (pixel) — phòng khi affine bất thường.
     * @property polygonTemplate Polygon 4 góc GỐC từ YOLO (giữ nguyên hình).
     * @property nailBedTemplate nailBedPolygon gốc từ YOLO (giữ nguyên).
     * @property pcaDirection   Hướng PCA gốc (để fill forwardVector khi track).
     * @property designPath      asset path design đã chọn.
     * @property clsId / clsName / trackId
     */
    private data class NailTrack(
        var nailCenterRef: PointF,
        var anchorJointRef: PointF,
        var tipRef: PointF,
        var bboxRef: FloatArray,                // [cx, cy, w, h]
        var polygonTemplate: List<PointF>,
        var nailBedTemplate: List<PointF>,
        var pcaDirection: PointF?,
        var designPath: String?,
        val clsId: Int,
        val clsName: String,
        val trackId: Int,
        var missFrames: Int = 0,
    )

    private val tracks = HashMap<Int, NailTrack>()
    private var currentPhase: Phase = Phase.SEARCHING
    private var lastJointPositions: Map<Int, PointF> = emptyMap()
    private var lastTipPositions: Map<Int, PointF> = emptyMap()
    private var lastFrameWidth: Int = 0
    private var lastFrameHeight: Int = 0
    private var trackIdCounter = 1

    // ── Statistics ────────────────────────────────────────────────────────
    private var lastSyntheticCount = 0
    private var lastSearchDetections = 0
    private var framesTrackedSinceSearch = 0

    /**
     * Mỗi camera frame, gọi hàm này.
     *
     * @param yoloDetections    List detection mới nhất từ YOLO (search hit). Có thể rỗng.
     * @param fingerVectors     Map clsId -> forward unit vector (MediaPipe).
     * @param tipPositions      Map clsId -> TIP pixel position (MediaPipe).
     * @param jointPositions    Map clsId -> PIP pixel position (MediaPipe anchor).
     * @param frameW / frameH   Kích thước frame (pixel) để scale nếu cần.
     *
     * @return Pair(phase, detections). Caller (PipelineExecutor) quyết định
     *         có cần chạy lại YOLO không dựa trên phase.
     */
    fun update(
        yoloDetections: List<NailDetection>,
        fingerVectors: Map<Int, PointF>,
        tipPositions: Map<Int, PointF>,
        jointPositions: Map<Int, PointF>,
        frameW: Int,
        frameH: Int,
    ): Pair<Phase, List<NailDetection>> {
        lastFrameWidth = frameW
        lastFrameHeight = frameH
        lastTipPositions = tipPositions

        // ── STATE TRANSITION: xác định phase mới ────────────────────────
        val hasHand = jointPositions.isNotEmpty()
        when (currentPhase) {
            Phase.SEARCHING -> {
                // Có YOLO detection → chuyển sang TRACKING nếu MP thấy tay.
                // Thiếu 1 trong 2 → giữ SEARCHING (chờ YOLO mới).
                if (yoloDetections.isNotEmpty() && hasHand) {
                    anchorFromYolo(yoloDetections, jointPositions, tipPositions, fingerVectors)
                    currentPhase = Phase.TRACKING
                    framesTrackedSinceSearch = 0
                    Log.i(TAG, "SEARCHING → TRACKING (anchored ${tracks.size} tracks)")
                } else if (yoloDetections.isNotEmpty() && !hasHand) {
                    // YOLO thấy móng nhưng MediaPipe chưa thấy tay → lưu tracks
                    // và đợi frame MP tới (không re-anchor mỗi frame).
                    anchorFromYolo(yoloDetections, jointPositions, tipPositions, fingerVectors)
                }
            }
            Phase.TRACKING -> {
                if (!hasHand) {
                    val allMissed = tracks.values.all { it.missFrames >= LOST_AFTER_MISS_FRAMES }
                    if (allMissed) {
                        currentPhase = Phase.LOST
                        Log.i(TAG, "TRACKING → LOST (no MP landmarks)")
                    }
                } else {
                    // Reset miss counter trên tracks còn anchor khớp.
                    for ((clsId, tr) in tracks) {
                        if (jointPositions.containsKey(clsId)) tr.missFrames = 0
                        else tr.missFrames++
                    }
                    // Trường hợp MP chỉ thấy tay mới mà tracks cũ chưa có joint
                    // → giữ TRACKING và tiếp tục render với detections rỗng cho
                    // đến khi YOLO được gọi lại từ SEARCHING.
                }
            }
            Phase.LOST -> {
                if (hasHand) {
                    // Quay lại SEARCHING — pipeline sẽ gọi YOLO lại.
                    currentPhase = Phase.SEARCHING
                    tracks.clear()
                    Log.i(TAG, "LOST → SEARCHING (hand re-detected)")
                }
            }
        }

        lastJointPositions = jointPositions

        // ── RENDER OUTPUT: luôn trả về detections cho renderer ──────────
        val outDetections: List<NailDetection> = when (currentPhase) {
            Phase.SEARCHING -> {
                // Tracking CHƯA sẵn sàng — chỉ trả về detections từ YOLO nếu
                // pipeline vừa chạy. Trong state machine mode chính, SEARCHING
                // thường chỉ kéo dài 1 frame (cho đến khi MP thấy tay).
                if (tracks.isNotEmpty()) synthesizeDetections(jointPositions, tipPositions, fingerVectors)
                else emptyList()
            }
            Phase.TRACKING -> synthesizeDetections(jointPositions, tipPositions, fingerVectors)
            Phase.LOST -> emptyList()
        }

        framesTrackedSinceSearch++
        lastSyntheticCount = outDetections.size
        return currentPhase to outDetections
    }

    /**
     * Anchor lại từ YOLO — reset constants cho state machine.
     */
    private fun anchorFromYolo(
        detections: List<NailDetection>,
        jointPositions: Map<Int, PointF>,
        tipPositions: Map<Int, PointF>,
        fingerVectors: Map<Int, PointF>,
    ) {
        tracks.clear()
        lastSearchDetections = detections.size
        for (det in detections) {
            val joint = jointPositions[det.clsId]
            val tip = tipPositions[det.clsId]
            val nailCenter = PointF(det.bboxCx, det.bboxCy)
            // Nếu MediaPipe chưa có joint/tip cho ngón này lúc anchor,
            // dùng nail center ± giá trị ước lượng dựa trên forward vector.
            val effectiveJoint = joint ?: estimateJointFromVector(
                nailCenter, fingerVectors[det.clsId], fallbackOffsetPx = 30f, oppositeOfForward = true
            )
            val effectiveTip = tip ?: estimateJointFromVector(
                nailCenter, fingerVectors[det.clsId], fallbackOffsetPx = 60f, oppositeOfForward = false
            )
            tracks[det.clsId] = NailTrack(
                nailCenterRef = nailCenter,
                anchorJointRef = effectiveJoint,
                tipRef = effectiveTip,
                bboxRef = floatArrayOf(det.bboxCx, det.bboxCy, det.bboxW, det.bboxH),
                polygonTemplate = det.polygon.map { PointF(it.x, it.y) },
                nailBedTemplate = if (det.nailBedPolygon.size >= 3) det.nailBedPolygon.map { PointF(it.x, it.y) } else det.polygon.map { PointF(it.x, it.y) },
                pcaDirection = det.pcaDirection?.let { PointF(it.x, it.y) },
                designPath = det.designAssetPath,
                clsId = det.clsId,
                clsName = det.clsName,
                trackId = trackIdCounter++,
                missFrames = 0,
            )
        }
    }

    private fun estimateJointFromVector(
        nailCenter: PointF,
        forward: PointF?,
        fallbackOffsetPx: Float,
        oppositeOfForward: Boolean,
    ): PointF {
        if (forward == null) {
            // Fallback: dùng offset xuống dưới (joint base nằm về phía wrist).
            return PointF(nailCenter.x, nailCenter.y + fallbackOffsetPx)
        }
        val (fx, fy) = if (oppositeOfForward) -forward.x to -forward.y else forward.x to forward.y
        return PointF(nailCenter.x + fx * fallbackOffsetPx, nailCenter.y + fy * fallbackOffsetPx)
    }

    /**
     * Tạo Synthetic detections cho renderer bằng cách áp dụng affine.
     */
    private fun synthesizeDetections(
        jointPositions: Map<Int, PointF>,
        tipPositions: Map<Int, PointF>,
        fingerVectors: Map<Int, PointF>,
    ): List<NailDetection> {
        if (tracks.isEmpty()) return emptyList()
        val out = ArrayList<NailDetection>(tracks.size)
        for ((clsId, tr) in tracks) {
            val joint = jointPositions[clsId]
            val tip = tipPositions[clsId]
            if (joint == null) {
                tr.missFrames++
                continue
            }
            // Tính scale theo khoảng cách PIP→TIP (proxy cho chiều dài ngón).
            val newLen = hypot(
                (joint.x - (tip?.x ?: tr.tipRef.x)).toDouble(),
                (joint.y - (tip?.y ?: tr.tipRef.y)).toDouble()
            ).toFloat().coerceAtLeast(1f)
            val oldLen = hypot(
                (tr.anchorJointRef.x - tr.tipRef.x).toDouble(),
                (tr.anchorJointRef.y - tr.tipRef.y).toDouble()
            ).toFloat().coerceAtLeast(1f)
            val scale = (newLen / oldLen).coerceIn(0.7f, 1.5f)

            // Vector offset: cùng hệ số affine để centroid nail theo anchor.
            val offsetXOld = tr.nailCenterRef.x - tr.anchorJointRef.x
            val offsetYOld = tr.nailCenterRef.y - tr.anchorJointRef.y
            val nailCenterNew = PointF(joint.x + offsetXOld, joint.y + offsetYOld)

            // Apply scale + translation cho từng polygon point (giữ nguyên
            // hình gốc, chỉ co giãn theo scale từ nailCenterNew).
            val polygonNew = tr.polygonTemplate.map { p ->
                val lx = p.x - tr.nailCenterRef.x
                val ly = p.y - tr.nailCenterRef.y
                PointF(nailCenterNew.x + lx * scale, nailCenterNew.y + ly * scale)
            }
            val nailBedNew = tr.nailBedTemplate.map { p ->
                val lx = p.x - tr.nailCenterRef.x
                val ly = p.y - tr.nailCenterRef.y
                PointF(nailCenterNew.x + lx * scale, nailCenterNew.y + ly * scale)
            }

            val newBbox = with(tr.bboxRef) {
                floatArrayOf(nailCenterNew.x, nailCenterNew.y, this[2] * scale, this[3] * scale)
            }

            // Cập nhật nailCenterRef + anchorJointRef cho frame sau (để
            // tracking có "đà" / momentum mà không bị rung).
            val smoothFactor = 0.6f
            val smoothedJoint = PointF(
                tr.anchorJointRef.x * (1f - smoothFactor) + joint.x * smoothFactor,
                tr.anchorJointRef.y * (1f - smoothFactor) + joint.y * smoothFactor,
            )
            tr.anchorJointRef = smoothedJoint
            tr.nailCenterRef = PointF(nailCenterNew.x, nailCenterNew.y)
            tr.tipRef = tip ?: tr.tipRef

            out.add(
                NailDetection(
                    bboxCx = newBbox[0],
                    bboxCy = newBbox[1],
                    bboxW  = newBbox[2],
                    bboxH  = newBbox[3],
                    polygon = polygonNew,
                    confidence = 0.85f,  // synthesized → confidence cao, vẫn chắc chắn
                    clsId = tr.clsId,
                    clsName = tr.clsName,
                    trackId = tr.trackId,
                    pcaDirection = tr.pcaDirection,
                    forwardVector = fingerVectors[clsId],
                    nailBedPolygon = nailBedNew,
                    designAssetPath = tr.designPath,
                )
            )
        }
        return out
    }

    fun getPhase(): Phase = currentPhase
    fun getTrackedCount(): Int = tracks.size
    fun getSyntheticLastFrame(): Int = lastSyntheticCount
    fun getFramesTrackedSinceSearch(): Int = framesTrackedSinceSearch

    /**
     * Force reset toàn bộ state — gọi khi session stop / camera đổi.
     */
    fun reset() {
        tracks.clear()
        currentPhase = Phase.SEARCHING
        lastJointPositions = emptyMap()
        lastTipPositions = emptyMap()
        framesTrackedSinceSearch = 0
        lastSyntheticCount = 0
        lastSearchDetections = 0
    }
}
