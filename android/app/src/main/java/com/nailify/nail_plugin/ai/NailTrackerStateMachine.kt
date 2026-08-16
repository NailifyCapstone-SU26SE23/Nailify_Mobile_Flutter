/*
 * NailTrackerStateMachine.kt — Hybrid tracking pipeline (v2 — fixed affine math).
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
 *      "khóa" (anchor) móng với các HẰNG SỐ TUYỆT ĐỐI (absolute constants):
 *        - nailCenterRef        : centroid móng YOLO (pixel)
 *        - anchorJointRef       : khớp PIP lúc khóa (pixel) — BẤT BIẾN
 *        - tipRef               : đầu ngón lúc khóa (pixel)
 *        - forwardRef           : unit vector (tip − joint) lúc khóa — BẤT BIẾN
 *        - lenRef               : khoảng cách joint→tip lúc khóa
 *        - nailOffsetFromJoint  : vector nailCenter - anchorJoint (constant)
 *        - polygonTemplate      : polygon GỐC YOLO — BẤT BIẾN
 *        - nailBedTemplate      : nailBedPolygon GỐC YOLO — BẤT BIẾN
 *
 *   2. TRACKING (MediaPipe, mỗi camera frame): YOLO KHÔNG chạy. Với mỗi
 *      frame, tính 3 phép biến đổi affine từ MediaPipe hiện tại:
 *          Translate = (joint_new + nailOffsetFromJoint) - nailCenterRef
 *          Scale    = lenNew / lenRef   (uniform scale, không phá hình)
 *          Rotate   = atan2(cross, dot) giữa forwardRef và forwardNew
 *
 *      Sau đó áp dụng lên từng điểm của polygonTemplate để có polygon mới.
 *
 *   3. LOST: Khi jointPositions rỗng → tất cả tracks miss → trả về empty
 *      detections ngay frame đó (không render móng đóng băng).
 *
 * ═══════════════════════════════════════════════════════════════
 * TOÁN HỌC AFFINE (đã sửa các bug trước):
 * ═══════════════════════════════════════════════════════════════
 *
 *   Với mỗi điểm P của polygonTemplate GỐC:
 *
 *     1. local = P - nailCenterRef      (đưa về gốc tọa độ nail center)
 *     2. localRot = R(theta) * local    (xoay quanh nailCenterRef)
 *        R(theta) = | cos -sin |
 *                   | sin  cos |
 *     3. localScaled = localRot * scale (co giãn đều)
 *     4. P_new = nailCenterNew + localScaled
 *        nailCenterNew = joint_new + nailOffsetFromJoint
 *
 *   Lưu ý:
 *     - nailCenterRef, anchorJointRef, forwardRef KHÔNG BAO GIỜ bị ghi đè
 *       bởi giá trị làm mượt (EMA) sau khi anchor. Đây là fix bug "drift"
 *       của phiên bản cũ.
 *     - forwardNew được tính từ MediaPipe (joint→tip) mỗi frame, KHÔNG
 *       cần làm mượt vì MediaPipe đã ổn định ở 25 FPS.
 *     - Khi MediaPipe không có landmark (jointPositions rỗng) → TRACKING
 *       trả về empty list → renderer KHÔNG vẽ móng (fix bug "đóng băng").
 */
package com.nailify.nail_plugin.ai

import android.graphics.PointF
import android.util.Log
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.sqrt

/**
 * Pack gắn kết quả YOLO với MP snapshot tại thời điểm YOLO được submit.
 * Dùng làm input cho [NailTrackerStateMachine.anchorWithPairedSnapshot] để
 * đảm bảo anchor đồng bộ về thời gian (Time-Capsule).
 */
data class YoloResultPack(
    val detections: List<NailDetection>,
    val jointPositions: Map<Int, PointF>,
    val tipPositions: Map<Int, PointF>,
    /**
     * Fix #2 (TIP anchor): vị trí TIP (đầu ngón tay) dùng làm anchor cho nail.
     * Nếu rỗng → caller fallback về tipPositions.
     */
    val anchorPositions: Map<Int, PointF> = emptyMap(),
    val fingerVectors: Map<Int, PointF>
)

class NailTrackerStateMachine {

    companion object {
        private const val TAG = "NailTrackerStateMachine"

        /**
         * Số frame tracking liên tiếp mất MediaPipe → chuyển LOST. Tăng từ 1 → 5
         * (khoảng 150-200ms @30fps) để tránh SEARCHING↔TRACKING chớp giật khi MP
         * miss 1-2 frame liên tiếp (rất phổ biến khi tay còn trong khung nhưng MP
         * chưa lock landmark kịp).
         */
        private const val LOST_AFTER_MISS_FRAMES = 5

        /** Scale factor clamp để tránh nổ/nhỏ bất thường (vd: tay quá gần). */
        private const val SCALE_MIN = 0.6f
        private const val SCALE_MAX = 1.8f

        /**
         * TIP-anchor: tỉ lệ polygon móng so với đốt ngón cuối (DIP→TIP).
         * Nail center = TIP, polygon là hình chữ nhật xoay theo forward direction.
         * - widthAlong  = 0.95 × lenRef (dọc theo trục ngón tay, TIP là giữa)
         * - widthAcross = 0.65 × lenRef (vuông góc ngón tay)
         * Như vậy nail ăn ra 2 phía: phần nửa dưới (toward DIP) và phần nửa trên (ra khỏi TIP).
         * → Móng nằm NGAY TẠI TIP, đúng như nail_fig.jpg (móng dính sát đầu ngón).
         */
        private const val NAIL_HALF_U = 0.475f  // half-length along forward
        private const val NAIL_HALF_V = 0.325f  // half-width across forward

        /**
         * Fix #4 (Fist detection): TIP-DIP distance dưới ngưỡng này × frameW
         * → tín hiệu nắm đấm. Threshold = frameW × 0.04 (~13px trên 320,
         * ~26px trên 640) — nhỏ vì khi nắm đấm TIP và DIP gần nhau còn vài px.
         */
        private const val FIST_THRESHOLD_RATIO = 0.04f

        /**
         * Fix #4: số frame fist liên tiếp trước khi remove track. 3 frame ~100ms
         * đủ chắc chắn không phải MP estimate thoáng qua (vd: tay rung nhẹ).
         */
        private const val FIST_FRAMES_TO_REMOVE = 3
    }

    enum class Phase { SEARCHING, TRACKING, LOST }

    /**
     * Per-class state. Tất cả field có tiền tố "Ref" là HẰNG SỐ TUYỆT ĐỐI —
     * KHÔNG được cập nhật sau khi anchor, chỉ được thay thế khi anchor mới.
     *
     * Lưu ý ngữ nghĩa (sau cập nhật v3):
     *   - "anchorJointRef" thực chất là DIP (đốt sát đầu ngón), không phải PIP.
     *     Tên giữ nguyên để không phải refactor rộng, nhưng giá trị luôn là DIP pixel.
     *   - "nailOffsetFromJoint" là nailCenterRef − anchorJointRef (= DIP offset).
     *   - "forwardRef" = unit vector (TIP − DIP).
     */
    private data class NailTrack(
        // ── HẰNG SỐ ANCHOR (BẤT BIẾN trong suốt TRACKING) ──
        val nailCenterRef: PointF,
        val anchorJointRef: PointF,             // Fix #2: TIP pixel (anchor chính)
        val tipRef: PointF,                      // TIP (đầu ngón tay) pixel (= anchorJointRef)
        val forwardRef: PointF,                  // unit vector (TIP − DIP)
        val lenRef: Float,                       // DIP→TIP distance lúc anchor
        val nailOffsetFromJoint: PointF,         // nailCenterRef − TIP (Fix #2)
        val polygonTemplate: List<PointF>,       // BẤT BIẾN
        val nailBedTemplate: List<PointF>,       // BẤT BIẾN
        val bboxRef: FloatArray,                 // [cx, cy, w, h] lúc anchor
        val pcaDirection: PointF?,               // dùng cho renderer direction
        val designPath: String?,
        val clsId: Int,
        val clsName: String,
        val trackId: Int,
        // ── ĐẾM MISS FRAMES (để quyết định LOST) ──
        var missFrames: Int = 0,
        // Fix #4: số frame liên tiếp có TIP-DIP distance < ngưỡng (nắm đấm).
        // Khi >= FIST_FRAMES_TO_REMOVE → remove track.
        var fistFrames: Int = 0,
    )

    private val tracks = HashMap<Int, NailTrack>()
    private var currentPhase: Phase = Phase.SEARCHING
    private var lastJointPositions: Map<Int, PointF> = emptyMap()
    private var lastTipPositions: Map<Int, PointF> = emptyMap()
    private var lastFrameWidth: Int = 0
    private var lastFrameHeight: Int = 0
    private var trackIdCounter = 1

    // Stats
    private var lastSyntheticCount = 0
    private var lastSearchDetections = 0
    private var framesTrackedSinceSearch = 0

    /**
     * Mỗi camera frame, gọi hàm này.
     *
     * Time-Capsule: Nếu `yoloPack` được truyền vào (YOLO vừa chạy xong và mang
     * theo MP snapshot tại thời điểm YOLO được submit), anchor dùng `jointPositions`
     * của pack (đồng bộ với YOLO bbox) thay vì `jointPositions` của camera frame
     * hiện tại — vì YOLO chạy mất ~300ms và trong lúc đó tay đã di chuyển.
     *
     * @return Pair(phase, detections). Caller quyết định render và có cần
     *         gọi YOLO dựa trên phase.
     */
    fun update(
        yoloPack: YoloResultPack?,
        fingerVectors: Map<Int, PointF>,
        tipPositions: Map<Int, PointF>,
        jointPositions: Map<Int, PointF>,
        frameW: Int,
        frameH: Int,
    ): Pair<Phase, List<NailDetection>> {
        lastFrameWidth = frameW
        lastFrameHeight = frameH
        lastTipPositions = tipPositions

        val hasHand = jointPositions.isNotEmpty()
        val yoloDetections = yoloPack?.detections ?: emptyList()

        // ── STATE TRANSITION ─────────────────────────────────────────────
        when (currentPhase) {
            Phase.SEARCHING -> {
                if (yoloPack != null && yoloDetections.isNotEmpty()) {
                    // TIME-CAPSULE: dùng MP từ pack (đồng bộ với YOLO), fallback
                    // sang MP camera-frame hiện tại nếu pack rỗng (YOLO đã chạy
                    // lúc MP chưa có landmark → vẫn cố gắng anchor với best-effort).
                    // Fix #2: anchor = TIP (pack.tipPositions), jointPositions = DIP.
                    val anchorsAtSubmit = yoloPack.anchorPositions.ifEmpty { yoloPack.tipPositions }
                    val dipsAtSubmit = yoloPack.jointPositions
                    val anchorsNow = anchorsAtSubmit.ifEmpty { tipPositions }
                    val dipsNow = dipsAtSubmit.ifEmpty { jointPositions }
                    anchorFromYolo(yoloDetections, anchorsNow, dipsNow)
                    if (hasHand && tracks.isNotEmpty()) {
                        currentPhase = Phase.TRACKING
                        framesTrackedSinceSearch = 0
                        Log.i(TAG, "SEARCHING → TRACKING (anchored ${tracks.size}/5 tracks)")
                    } else if (tracks.isEmpty()) {
                        Log.w(TAG, "SEARCHING: YOLO detected ${yoloDetections.size} nails but no MP match — waiting for next cycle")
                    } else {
                        Log.i(TAG, "SEARCHING → TRACKING pending (no hand in current frame, tracks=${tracks.size})")
                    }
                }
            }
            Phase.TRACKING -> {
                if (!hasHand) {
                    // Mất tay hoàn toàn → tăng miss và chuyển LOST khi đạt ngưỡng.
                    val allMissed = tracks.values.all { it.missFrames >= LOST_AFTER_MISS_FRAMES - 1 }
                    if (allMissed) {
                        currentPhase = Phase.LOST
                        // Fix C: clear tracks ngay khi vào LOST (đã qua LOST_AFTER_MISS_FRAMES
                        // = 5 frames ~150-200ms, đủ an toàn). Tránh renderer vẽ nail ảo
                        // ở vị trí cũ khi tay đã ra khỏi camera.
                        tracks.clear()
                        Log.i(TAG, "TRACKING → LOST (cleared ${tracks.size} stale tracks, no MP landmarks)")
                    }
                    for (tr in tracks.values) tr.missFrames++
                } else {
                    // Track theo clsId — reset miss cho tracks có joint; tăng cho track không có.
                    // Fix #4: thêm fist detection — nếu TIP-DIP distance nhỏ → đếm fistFrames,
                    // đủ ngưỡng thì remove track (coi như móng biến mất khi nắm đấm).
                    val fistThresholdPx = lastFrameWidth * FIST_THRESHOLD_RATIO
                    val tracksToRemove = ArrayList<Int>()
                    for ((clsId, tr) in tracks) {
                        if (jointPositions.containsKey(clsId)) {
                            tr.missFrames = 0
                            val tip = tipPositions[clsId]
                            val dip = jointPositions[clsId]
                            if (tip != null && dip != null) {
                                val dx = tip.x - dip.x
                                val dy = tip.y - dip.y
                                val dist = sqrt(dx * dx + dy * dy)
                                if (dist < fistThresholdPx) {
                                    tr.fistFrames++
                                    if (tr.fistFrames >= FIST_FRAMES_TO_REMOVE) {
                                        tracksToRemove.add(clsId)
                                    }
                                } else {
                                    tr.fistFrames = 0
                                }
                            }
                        } else {
                            tr.missFrames++
                        }
                    }
                    for (clsId in tracksToRemove) {
                        val tr = tracks.remove(clsId)
                        Log.i(TAG, "track removed: fist detected for clsId=$clsId (${tr?.clsName})")
                    }
                    // Fix #4: nếu tất cả track bị remove → chuyển SEARCHING để YOLO
                    // re-scan (không đợi 3s periodic). Khi mở tay lại → YOLO chạy ngay.
                    if (tracks.isEmpty() && tracksToRemove.isNotEmpty()) {
                        currentPhase = Phase.SEARCHING
                        Log.i(TAG, "TRACKING → SEARCHING (all tracks removed by fist, re-anchor immediately)")
                    }
                }
            }
            Phase.LOST -> {
                if (hasHand) {
                    currentPhase = Phase.SEARCHING
                    tracks.clear()
                    Log.i(TAG, "LOST → SEARCHING (hand re-detected)")
                }
            }
        }

        lastJointPositions = jointPositions

        // ── RENDER OUTPUT ───────────────────────────────────────────────
        // TRACKING với MP rỗng → trả empty list (renderer không vẽ móng).
        // Đây là fix bug "móng đóng băng dù tay biến mất".
        val outDetections: List<NailDetection> = when {
            tracks.isEmpty() -> emptyList()
            currentPhase == Phase.TRACKING && hasHand ->
                synthesizeDetections(jointPositions, tipPositions)
            currentPhase == Phase.SEARCHING && tracks.isNotEmpty() && hasHand ->
                // Vừa anchor xong ở frame này, dùng synthesis ngay.
                synthesizeDetections(jointPositions, tipPositions)
            else -> emptyList()
        }

        framesTrackedSinceSearch++
        lastSyntheticCount = outDetections.size
        return currentPhase to outDetections
    }

    /**
     * Public entry point để PipelineExecutor gọi NGAY sau khi YOLO chạy xong,
     * dùng Time-Capsule MP snapshot đã cache tại thời điểm YOLO được submit.
     *
     * Đây là API được ưu tiên (gọi từ aiExecutor thread); giải quyết bug lệch
     * anchor do async desync giữa YOLO frame và MP camera frame.
     *
     * Hành vi:
     *  - Nếu pack rỗng hoặc detections rỗng → không làm gì.
     *  - Ngược lại: anchor tracks bằng pack.jointPositions/tipPositions
     *    (đồng bộ với YOLO). Cờ `frameW/frameH` chỉ dùng cho stats.
     */
    fun anchorWithPairedSnapshot(
        pack: YoloResultPack,
        frameW: Int,
        frameH: Int,
    ) {
        if (pack.detections.isEmpty()) return
        lastFrameWidth = frameW
        lastFrameHeight = frameH

        // Fix #2: anchors = TIP (pack.anchorPositions nếu có, fallback = tipPositions),
        // joints = DIP (pack.jointPositions, dùng để tính forward direction).
        val anchorsMp = pack.anchorPositions.ifEmpty { pack.tipPositions }
        val dipsMp = pack.jointPositions

        anchorFromYolo(pack.detections, anchorsMp, dipsMp)

        // Nếu MP snapshot rỗng nhưng YOLO có detections → vẫn giữ SEARCHING
        // để frame MP tiếp theo có thể TRACKING. Nếu MP có → chuyển TRACKING.
        when {
            anchorsMp.isNotEmpty() && tracks.isNotEmpty() -> {
                currentPhase = Phase.TRACKING
                framesTrackedSinceSearch = 0
                Log.i(TAG, "anchorWithPairedSnapshot → TRACKING (anchored ${tracks.size}/${pack.detections.size} tracks)")
            }
            anchorsMp.isNotEmpty() && tracks.isEmpty() -> {
                Log.w(TAG, "anchorWithPairedSnapshot: YOLO detected ${pack.detections.size} but all skipped (no MP match) — will retry")
            }
            else -> {
                Log.i(TAG, "anchorWithPairedSnapshot pre-anchor (no MP in snapshot, waiting)")
            }
        }
    }

    /**
     * Anchor từ YOLO — set HẰNG SỐ TUYỆT ĐỐI (immutable trong TRACKING).
     *
     * anchorPositions/clsId là TIP pixel (anchor chính — Fix #2),
     * jointPositions/clsId là DIP pixel (chỉ để tính forward direction).
     *
     * Fix B: thêm spatial proximity lookup — tìm MP TIP nào gần bbox nail
     * nhất. Vì bbox YOLO nhỏ (~30-60px) và các MP TIP cách nhau > 60px
     * trong bàn tay bình thường, có thể ghép đúng clsId kể cả khi matching
     * theo clsId fail. Bỏ hoàn toàn fallback bbox-based ước lượng (gây
     * anchor sai lệch lớn — nail ghép xa khỏi tay).
     */
    private fun anchorFromYolo(
        detections: List<NailDetection>,
        anchorPositions: Map<Int, PointF>,  // TIP pixel (anchor chính)
        jointPositions: Map<Int, PointF>,   // DIP pixel (để tính forward)
    ) {
        tracks.clear()
        lastSearchDetections = detections.size

        // Fix B: pre-compute spatial lookup trên TIP — pair of (clsId, TIP).
        // Dùng để match YOLO bbox nếu clsId-match fail.
        val spatialAnchors: List<Pair<Int, PointF>> = anchorPositions.entries.map { it.key to it.value }

        for (det in detections) {
            val anchorMp = anchorPositions[det.clsId]  // TIP
            val dipMp = jointPositions[det.clsId]      // DIP (cho forward vector)
            var usedFallback = false
            var matchedClsId = det.clsId

            // Fix B: spatial proximity — nếu clsId-match fail, thử tìm TIP
            // MP nào gần bbox nail nhất. Giới hạn 60px (YOLO bbox nhỏ, MP
            // TIP cách nhau > 60px).
            val (effectiveAnchor, effectiveDip) = if (anchorMp != null && dipMp != null) {
                anchorMp to dipMp
            } else if (spatialAnchors.isNotEmpty()) {
                var bestCls: Int = -1
                var bestD2 = Float.POSITIVE_INFINITY
                for ((cls, p) in spatialAnchors) {
                    val dx = p.x - det.bboxCx
                    val dy = p.y - det.bboxCy
                    val d2 = dx * dx + dy * dy
                    if (d2 < bestD2) { bestD2 = d2; bestCls = cls }
                }
                val bestAnchor = anchorPositions[bestCls]
                val bestDip = jointPositions[bestCls]
                if (bestAnchor != null && bestDip != null && kotlin.math.sqrt(bestD2) <= 60f) {
                    usedFallback = true
                    matchedClsId = bestCls
                    bestAnchor to bestDip
                } else {
                    Log.w(
                        TAG,
                        "anchorFromYolo: skip clsId=${det.clsId} (${det.clsName}) — no MP TIP near bbox " +
                            "(bbox=${"%.0f,%.0f".format(det.bboxCx, det.bboxCy)}, bestDist=${"%.0f".format(kotlin.math.sqrt(bestD2))})"
                    )
                    continue
                }
            } else {
                Log.w(
                    TAG,
                    "anchorFromYolo: skip clsId=${det.clsId} (${det.clsName}) — no MP landmarks in snapshot"
                )
                continue
            }

            Log.d(
                TAG,
                "anchorFromYolo: clsId=${det.clsId} matched=$matchedClsId usedFallback=$usedFallback " +
                    "TIP=${"%.0f,%.0f".format(effectiveAnchor.x, effectiveAnchor.y)} " +
                    "nailCenter=${"%.0f,%.0f".format(det.bboxCx, det.bboxCy)}"
            )

            // forwardRef: unit vector từ DIP → TIP (hướng của đốt ngón cuối).
            // Đây vẫn là vector "thuần" của ngón tay — TIP chỉ là anchor mới.
            val fx = effectiveAnchor.x - effectiveDip.x
            val fy = effectiveAnchor.y - effectiveDip.y
            val mag = sqrt(fx * fx + fy * fy).coerceAtLeast(1e-6f)
            val forwardRef = PointF(fx / mag, fy / mag)
            val lenRef = mag

            // TIP-anchor: nail center = TIP (không phải YOLO bbox center).
            // Nail luôn bám NGAY TẠI TIP — móng dính sát đầu ngón (nail_fig.jpg).
            // YOLO bbox chỉ dùng cho debug; render dùng TIP + forward direction.
            val nailCenterRef = PointF(effectiveAnchor.x, effectiveAnchor.y)

            // Build polygon template: 4 góc chữ nhật quanh TIP, xoay theo forwardRef.
            // Local frame: u = forward (DIP→TIP direction), v = perpendicular.
            // TIP ở giữa chữ nhật: u ∈ [-NAIL_HALF_U, +NAIL_HALF_U], v ∈ [-NAIL_HALF_V, +NAIL_HALF_V].
            //
            // Lưu ý: u=NAIL_HALF_U (đầu ngón) > 0 → nail ăn ra ngoài TIP.
            //       u=-NAIL_HALF_U (về phía DIP) → nail ăn về phía DIP.
            // Theo nail_fig.jpg: móng DÍNH SÁT ĐẦU NGÓN, không trôi về gốc ngón.
            // Vì vậy ép: u_center = +NAIL_HALF_U * 0.3 (TIP hơi lệch về phía đầu hơn).
            // thực tế TIP là local u=0 → đặt TÂM polygon offset 1 chút ra ngoài TIP.
            val uCenter = lenRef * 0.05f  // dịch tâm nail ra ngoài TIP 5% len (vượt nhẹ ra ngoài)
            val halfU = lenRef * NAIL_HALF_U
            val halfV = lenRef * NAIL_HALF_V
            val perp = PointF(-forwardRef.y, forwardRef.x)  // perpendicular

            // 4 corners: TIP ở giữa, polygon xoay theo forwardRef.
            // corners = nailCenterRef + uCenter * forwardRef + ±halfU * forwardRef + ±halfV * perp
            val polygonTemplate = listOf(
                PointF(
                    nailCenterRef.x + (uCenter - halfU) * forwardRef.x + (-halfV) * perp.x,
                    nailCenterRef.y + (uCenter - halfU) * forwardRef.y + (-halfV) * perp.y,
                ),
                PointF(
                    nailCenterRef.x + (uCenter + halfU) * forwardRef.x + (-halfV) * perp.x,
                    nailCenterRef.y + (uCenter + halfU) * forwardRef.y + (-halfV) * perp.y,
                ),
                PointF(
                    nailCenterRef.x + (uCenter + halfU) * forwardRef.x + (halfV) * perp.x,
                    nailCenterRef.y + (uCenter + halfU) * forwardRef.y + (halfV) * perp.y,
                ),
                PointF(
                    nailCenterRef.x + (uCenter - halfU) * forwardRef.x + (halfV) * perp.x,
                    nailCenterRef.y + (uCenter - halfU) * forwardRef.y + (halfV) * perp.y,
                ),
            )

            // Fix B: dùng matchedClsId làm key cho tracks map.
            tracks[matchedClsId] = NailTrack(
                nailCenterRef = nailCenterRef,        // = TIP pixel
                anchorJointRef = effectiveAnchor,     // = TIP pixel
                tipRef = effectiveAnchor,             // backward-compat alias
                forwardRef = forwardRef,
                lenRef = lenRef,
                nailOffsetFromJoint = PointF(0f, 0f), // legacy - không dùng nữa
                polygonTemplate = polygonTemplate,
                nailBedTemplate = polygonTemplate,    // dùng cùng polygon cho nail bed
                bboxRef = floatArrayOf(
                    effectiveAnchor.x, effectiveAnchor.x,
                    halfV * 2f, halfU * 2f,
                ),
                pcaDirection = det.pcaDirection?.let { PointF(it.x, it.y) },
                designPath = det.designAssetPath,
                clsId = matchedClsId,
                clsName = det.clsName,
                trackId = trackIdCounter++,
                missFrames = 0,
                fistFrames = 0,
            )
        }
    }

    /**
     * Fix #3 (Constraint box): ép nail center + polygon nằm trong hộp xoay
     * theo segment DIP→TIP (đốt ngón cuối). Margin và halfV đơn vị tỉ lệ
     * (0 = DIP, 1 = TIP, >1 = vượt TIP). Margin u cho phép nail "trồi" ra ngoài
     * TIP khi scale > 1.
     *
     * Hộp local frame: trục u chạy từ DIP → TIP, trục v vuông góc (cùng chiều
     * với hướng "trái" của ngón). Trong local frame, hộp là:
     *   u ∈ [-marginU, 1+marginU], v ∈ [-halfV, +halfV]
     * Nếu điểm nằm ngoài → clamp về cạnh gần nhất.
     */
    private fun clampToFingerSegment(
        point: PointF,
        dip: PointF,
        tip: PointF,
        marginU: Float,
        halfV: Float,
    ): PointF {
        val dx = tip.x - dip.x
        val dy = tip.y - dip.y
        val len = sqrt(dx * dx + dy * dy).coerceAtLeast(1e-6f)
        val ux = dx / len  // unit vector along finger
        val uy = dy / len
        val vx = -uy       // perpendicular
        val vy = ux
        // Local coords (chuẩn hóa: u ∈ [0, 1] dọc DIP→TIP, v đơn vị pixel).
        val px = point.x - dip.x
        val py = point.y - dip.y
        val uNorm = (px * ux + py * uy) / len  // tỉ lệ 0..1 dọc
        val vNorm = (px * vx + py * vy) / len  // tỉ lệ pixel / len
        val uClamped = uNorm.coerceIn(-marginU, 1f + marginU)
        val vClamped = vNorm.coerceIn(-halfV, halfV)
        // Back to world (resume pixel units):
        return PointF(
            dip.x + uClamped * len * ux + vClamped * len * vx,
            dip.y + uClamped * len * uy + vClamped * len * vy,
        )
    }

    /**
     * Affine transform đúng: translate + scale + rotate quanh nailCenterRef.
     *
     * KHÔNG có EMA, KHÔNG cập nhật hằng số anchor. Mỗi frame:
     *   1. Đọc DIP_new + TIP_new từ MediaPipe (jointPositions = DIP, tipPositions = TIP).
     *   2. Tính scaleNew = DIP→TIP_new length / DIP→TIP_ref length.
     *   3. Tính rotate theta giữa forwardRef (DIP→TIP ref) và forwardNew (DIP→TIP new).
     *   4. Với mỗi điểm polygonTemplate:
     *        local = P - nailCenterRef
     *        rotated = R(theta) * local
     *        P_new = nailCenterNew + rotated * scaleNew
     *   5. nailCenterNew = DIP_new + nailOffsetFromJoint (constant vector nailCenter - DIP khi anchor).
     */
    private fun synthesizeDetections(
        jointPositions: Map<Int, PointF>,  // DIP pixel (dùng tính scale + forward)
        tipPositions: Map<Int, PointF>,    // TIP pixel (anchor chính — Fix #2)
    ): List<NailDetection> {
        if (tracks.isEmpty()) return emptyList()
        val out = ArrayList<NailDetection>(tracks.size)
        for ((clsId, tr) in tracks) {
            // Fix #2: tip = anchor chính (TIP pixel), dip = để tính scale + rotate.
            val tip = tipPositions[clsId]
            val dip = jointPositions[clsId]
            if (tip == null || dip == null) {
                // Track này mất anchor frame này — KHÔNG vẽ (skip).
                tr.missFrames++
                continue
            }

            // ── 1. Translate: nailCenterNew = TIP_new ──
            // TIP-anchor: nail luôn neo tại TIP. Nail không thể "trôi" về gốc ngón
            // (Fix #2 đã giải quyết bug lệch khi tay di chuyển).
            val nailCenterNew = PointF(tip.x, tip.y)

            // ── 2. Scale từ độ dài DIP→TIP ───────────────────────────────
            // Đốt sát đầu ngón — scale ít bị tác động bởi gập ngón hơn so với PIP→TIP.
            val lenNew = hypot(
                (dip.x - tip.x).toDouble(),
                (dip.y - tip.y).toDouble(),
            ).toFloat().coerceAtLeast(1f)
            val scale = (lenNew / tr.lenRef).coerceIn(SCALE_MIN, SCALE_MAX)

            // ── 3. Rotate: theta giữa forwardRef(DIP→TIP gốc) và forwardNew ──
            val fxN = tip.x - dip.x
            val fyN = tip.y - dip.y
            val magN = sqrt(fxN * fxN + fyN * fyN).coerceAtLeast(1e-6f)
            val fnx = fxN / magN
            val fny = fyN / magN

            // cross & dot giữa forwardRef (fxR,fyR) và forwardNew (fnx,fny)
            val dot = tr.forwardRef.x * fnx + tr.forwardRef.y * fny
            val cross = tr.forwardRef.x * fny - tr.forwardRef.y * fnx
            // Kẹp dot để tránh NaN do sai số fp.
            val dotClamped = dot.coerceIn(-1f, 1f)
            val theta = atan2(cross, dotClamped)
            val cosT = kotlin.math.cos(theta)
            val sinT = kotlin.math.sin(theta)

            // Fix #3: Constraint box DIP→TIP — ép nail nằm trong vùng an toàn quanh TIP.
            // TIP-anchor: nail center = TIP (u = 1). Polygon template dùng
            // u ∈ [uCenter - halfU, uCenter + halfU] = [0.05 - 0.475, 0.05 + 0.475]
            //   = [-0.425, +0.525] khi scale = 1.
            // Khi scale = 0.6 (xa): range = [-0.135, +0.435] — vẫn trong [-0.15, 1.15] OK.
            // Khi scale = 1.8 (gần): range = [-0.645, +1.065] — sẽ clamp nếu marginU = 0.15.
            // → marginU = 1.0 cho rộng rãi, nail được phép "trồi" ra ngoài DIP một chút
            // khi tay gần camera, không bị clamp làm méo nail.
            val lenDipTip = lenNew
            val marginU = 1.0f
            val halfV = 0.5f  // tỉ lệ: halfV × len = rộng tối đa bằng 1/2 đốt ngón
            val nailCenterClamped = clampToFingerSegment(
                nailCenterNew, dip, tip, marginU, halfV,
            )
            val clampedX = nailCenterClamped.x - nailCenterNew.x
            val clampedY = nailCenterClamped.y - nailCenterNew.y
            if (kotlin.math.abs(clampedX) > 0.5f || kotlin.math.abs(clampedY) > 0.5f) {
                if (tr.missFrames == 0) {
                    Log.w(TAG, "synthesizeDetections: nail center shifted clsId=$clsId " +
                        "(delta=(${clampedX.toInt()}, ${clampedY.toInt()}), DIP=$dip TIP=$tip)")
                }
            }
            val nailCenterFinal = nailCenterClamped

            // ── 4. Áp dụng affine lên từng điểm polygon gốc ──────────────
            val polygonNew = ArrayList<PointF>(tr.polygonTemplate.size)
            for (p in tr.polygonTemplate) {
                val lx = p.x - tr.nailCenterRef.x
                val ly = p.y - tr.nailCenterRef.y
                // R(theta) * (lx, ly)
                val rx = lx * cosT - ly * sinT
                val ry = lx * sinT + ly * cosT
                val worldPt = PointF(
                    nailCenterFinal.x + rx * scale,
                    nailCenterFinal.y + ry * scale,
                )
                // Fix #3: clamp polygon vertex vào constraint box (ép buộc).
                polygonNew.add(clampToFingerSegment(worldPt, dip, tip, marginU, halfV))
            }
            val nailBedNew = ArrayList<PointF>(tr.nailBedTemplate.size)
            for (p in tr.nailBedTemplate) {
                val lx = p.x - tr.nailCenterRef.x
                val ly = p.y - tr.nailCenterRef.y
                val rx = lx * cosT - ly * sinT
                val ry = lx * sinT + ly * cosT
                val worldPt = PointF(
                    nailCenterFinal.x + rx * scale,
                    nailCenterFinal.y + ry * scale,
                )
                nailBedNew.add(clampToFingerSegment(worldPt, dip, tip, marginU, halfV))
            }

            // ── 5. Bbox mới (cx, cy, w, h) ──────────────────────────────
            val newBboxCx = nailCenterFinal.x
            val newBboxCy = nailCenterFinal.y
            val newBboxW = tr.bboxRef[2] * scale
            val newBboxH = tr.bboxRef[3] * scale

            out.add(
                NailDetection(
                    bboxCx = newBboxCx,
                    bboxCy = newBboxCy,
                    bboxW  = newBboxW,
                    bboxH  = newBboxH,
                    polygon = polygonNew,
                    confidence = 0.85f,
                    clsId = tr.clsId,
                    clsName = tr.clsName,
                    trackId = tr.trackId,
                    pcaDirection = tr.pcaDirection,
                    // forward vector hiện tại = (TIP − DIP) normalized để
                    // renderer xoay design bitmap theo hướng ngón.
                    forwardVector = PointF(fnx, fny),
                    nailBedPolygon = nailBedNew,
                    designAssetPath = tr.designPath,
                    // FIX #6: truyền polygon YOLO gốc (chưa affine) cho renderer
                    // vẽ overlay so sánh với polygon đã ghép.
                    polygonTemplate = tr.polygonTemplate,
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
     * Fix #1 (Periodic re-scan): ép State Machine về SEARCHING để YOLO refresh
     * anchor constants. Được gọi từ PipelineExecutor mỗi RE_SCAN_INTERVAL_MS.
     * Đặt tracks về null (sẽ được re-anchor bởi YOLO frame tiếp theo).
     */
    fun forceReScan() {
        if (currentPhase != Phase.SEARCHING) {
            Log.i(TAG, "forceReScan: ${currentPhase} → SEARCHING (tracks=${tracks.size})")
            currentPhase = Phase.SEARCHING
            // Không clear tracks ngay — render frame cuối vẫn dùng tracks cũ
            // cho đến khi YOLO xong. Nếu không có YOLO hit mới (tay ra khỏi
            // camera) → state sẽ chuyển LOST sau LOST_AFTER_MISS_FRAMES và
            // tracks sẽ được clear ở đó.
            framesTrackedSinceSearch = 0
        }
    }

    /** Force reset toàn bộ state. */
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