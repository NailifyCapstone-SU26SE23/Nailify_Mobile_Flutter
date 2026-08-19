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
 * HIDE-LOGIC v3 (ẩn móng bằng skeleton MediaPipe):
 * ═══════════════════════════════════════════════════════════════
 *
 *   Mục tiêu: ẩn triệt để móng khi người dùng KHÔNG muốn thấy (xoay tay
 *   ngửa lòng bàn tay, gập ngón, nắm đấm...) — không chớp chớp.
 *
 *   Hai tín hiệu ẩn:
 *
 *     A) PALM-FACE: dùng cross product của 2 vector trên mặt phẳng 2D
 *        (wrist→MCP_index × wrist→MCP_pinky). Dấu cross quyết định mặt
 *        bàn tay đang quay về phía camera:
 *          - Lưng bàn tay (móng hướng về camera) → cross dương → render nail
 *          - Lòng bàn tay (móng hướng xa camera)  → cross âm → ẩn nail
 *        Hysteresis 8 frame để tránh chớp khi xoay tay vừa đúng ranh giới.
 *
 *     B) FLEX-ANGLE: góc ∠PIP-DIP-TIP cho 4 ngón dài (index/middle/ring/pinky):
 *          - Ngón duỗi thẳng (>165°) → render nail
 *          - Ngón gập nhẹ (130°–165°) → soft-hide (chớp có thể xảy ra ở ranh giới)
 *          - Ngón gập sâu (<130°) → hide hoàn toàn (không chớp)
 *        Thumb KHÔNG áp dụng (cấu trúc khác, dễ sai).
 *
 *   Hai tín hiệu OR lại — chỉ cần 1 trong 2 báo hide thì skip render.
 *
 *   Đặc biệt: re-scan anchor YOLO luôn refresh lại `forceShowFrames = N`
 *   để KHI vừa anchor xong móng hiện ngay, không phải chờ flex/palm trở lại
 *   bình thường (UX mượt khi vừa đưa tay vào khung).
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

        /**
         * Fix Flex-detection: ngưỡng SOFT — ngón bắt đầu gập (DIP→TIP thu ngắn
         * còn ~10% frameW). Dưới ngưỡng này → track không render nhưng KHÔNG bị
         * xóa (giữ track để resume ngay khi duỗi lại, không cần YOLO re-anchor).
         * 10% frameW ≈ ~30-60px trên 320-640 frame, tương ứng góc gập ~30-40°.
         */
        private const val FLEX_SOFT_RATIO = 0.10f

        /**
         * Grace period cho SOFT flex — số frame liên tiếp có flex trước khi
         * skip render. Tránh flicker khi MP estimate thoáng qua (tay rung nhẹ).
         */
        private const val FLEX_SOFT_FRAMES = 2

        /**
         * Fix Flex-angle: ngưỡng góc gập ∠PIP-DIP-TIP. Khi ngón duỗi thẳng → góc ≈ 180°.
         * Ngón gập > 50° → góc < 130°. Dùng kết hợp (OR) với distance nhánh
         * SOFT — vì gập ngang (ngón xoay 90°) làm TIP-DIP distance không đổi
         * → nhánh distance miss. Góc bắt được nhờ cả 2 vector đều ở mặt phẳng 2D.
         */
        private const val FLEX_ANGLE_THRESHOLD_DEG = 130f

        // ═══════════════════════════════════════════════════════════
        // HIDE-LOGIC v4 constants — ẩn móng KHI GẬP, không chớp
        // ═══════════════════════════════════════════════════════════

        /**
         * HIDE Flex-angle: góc gập < ngưỡng này → ẨN TRIỆT ĐỂ.
         * Đặt RẤT GẦN 180° (gập > 15°) — chỉ cần ngón hơi cong là
         * móng đã biến mất. Kết hợp với dead-zone 165-175° → không
         * chớp khi tay run nhẹ quanh ranh giới.
         *
         * 165° = gập ~15° — threshold thực tế, ngón gần như duỗi thẳng.
         */
        private const val FLEX_HIDE_BELOW_DEG = 165f

        /**
         * SHOW Flex-angle: góc gập > ngưỡng này → HIỆN LẠI.
         * Đặt = 175° (gập < 5°) — gần như duỗi thẳng tuyệt đối.
         * Hiện móng CHỈ khi người dùng CỐ Ý duỗi ngón, không phải
         * "ngón hơi cong" sẵn.
         *
         * Dead-zone = 165°–175°: trong khoảng này giữ nguyên trạng
         * thái hiện tại → KHÔNG chớp chớp khi góc dao động nhẹ.
         */
        private const val FLEX_SHOW_ABOVE_DEG = 175f

        /**
         * DEEP-FLEX (gập sâu): góc gập < ngưỡng này HOẶC TIP-DIP
         * distance < ngưỡng phụ → XÓA TRACK TRIỆT ĐỂ (không phải ẩn,
         * mà xóa hẳn). Buộc YOLO phải re-anchor khi duỗi lại.
         *
         * 90° = gập vuông góc → không còn móng nào để nhìn.
         *
         * Lý do xóa hẳn: gập sâu → MediaPipe landmarks ở vị trí cũ
         * không còn tương ứng y học với móng (móng bị che). Khi duỗi
         * ra, anchor cũ lệch → cần YOLO refresh.
         *
         * Hysteresis: 1 lần xóa → 3 frame liên tiếp gập sâu mới xóa
         * (tránh MP estimate thoáng qua).
         */
        private const val DEEP_FLEX_ANGLE_DEG = 90f
        private const val DEEP_FLEX_DISTANCE_RATIO = 0.08f
        private const val DEEP_FLEX_FRAMES_TO_REMOVE = 3

        // (alias cũ giữ để tương thích nếu có nơi nào đang tham chiếu)
        @Suppress("unused")
        private const val FLEX_ANGLE_THRESHOLD_DEG_LEGACY = FLEX_ANGLE_THRESHOLD_DEG

        /**
         * Force-show sau khi vừa anchor YOLO xong: trong `N` frame đầu
         * tiên của track, LUÔN render bất kể flex/palm (UX mượt khi tay
         * mới xuất hiện). Sau đó áp dụng hide-logic bình thường.
         */
        private const val FORCE_SHOW_FRAMES_AFTER_ANCHOR = 8

        /**
         * YOLO re-anchor displacement threshold: nếu khoảng cách giữa
         * centroid YOLO mới và anchor cũ > tỉ lệ này × frameW → reset
         * polygonTemplate (không dùng EMA scale cũ). Fix bug "xoay tay
         * 20s vẫn thấy móng cũ": YOLO detect vị trí mới nhưng code
         * cũ giữ polygon template cũ (chỉ EMA scale lenRef).
         *
         * 0.20 = 20% frameW ≈ ~100-140px trên 640.
         */
        private const val REANCHOR_DISPLACEMENT_RATIO = 0.20f
    }

    // ── HIDE-LOGIC v3 helpers ──────────────────────────────────────────────

    /**
     * Tính palm-normal 2D: cross product của 2 vector trên mặt phẳng 2D.
     * Dùng wrist(0), MCP_index(5), MCP_pinky(17). Với MediaPipe HandLandmarker:
     *   - Lưng bàn tay hướng về camera: cross (wrist→MCP_index × wrist→MCP_pinky) > 0
     *   - Lòng bàn tay hướng về camera: cross < 0
     * Trả về null nếu không có landmarks (hand mất tracking).
     *
     * Lưu ý: chỉ hoạt động khi camera KHÔNG lật ngược (selfie camera OK).
     * Front camera mirror không ảnh hưởng vì MCP_index vẫn bên trái MCP_pinky
     * trong mirror view (mirror lật cả ảnh theo chiều ngang).
     */
    private fun computePalmSide(skel: Array<FloatArray>?): Boolean? {
        if (skel == null || skel.size < 18) return null
        val wrist = skel[0]
        val mcpIndex = skel[5]
        val mcpPinky = skel[17]
        // skel đã là normalized [0..1] (x, y). Cross product vẫn giữ dấu đúng
        // vì cả v1 và v2 cùng chia tỉ lệ với frameW/frameH → dấu cross không đổi.
        val v1x = mcpIndex[0] - wrist[0]
        val v1y = mcpIndex[1] - wrist[1]
        val v2x = mcpPinky[0] - wrist[0]
        val v2y = mcpPinky[1] - wrist[1]
        // Cross product z-component (trong 2D): v1.x*v2.y - v1.y*v2.x
        val cross = v1x * v2y - v1y * v2x
        // true = palm-up (lưng bàn tay về phía camera), false = palm-down (lòng bàn tay về phía camera).
        return cross >= 0f
    }

    /**
     * HIDE-LOGIC v4: ẩn track khi gập ngón (góc hoặc distance nhỏ).
     * Dead-zone (165°–175°) giữ nguyên trạng thái → KHÔNG chớp.
     *
     * @param angleDeg    góc ∠PIP-DIP-TIP (độ). null nếu thiếu PIP.
     * @param dist        TIP↔DIP distance (pixel).
     * @param deepFlexOut output: true nếu frame này đạt DEEP_FLEX (gập
     *                    sâu). Caller dùng để đếm và xóa track triệt để.
     */
    private fun updateHideState(
        tr: NailTrack,
        angleDeg: Float?,
        dist: Float?,
        isLongFinger: Boolean,
    ): Boolean {
        // ─── 1. FLEX hide (góc gập ngón) ─────────────────────────────────
        // Chỉ áp dụng cho 4 ngón dài; thumb thì bỏ qua (cấu trúc khác).
        if (isLongFinger && angleDeg != null) {
            // Dead-zone: 165°–175° → KHÔNG thay đổi hiddenByFlex.
            // Ngoài dead-zone:
            //   - angle < 165° → set hiddenByFlex = true (nếu chưa ẩn)
            //   - angle > 175° → set hiddenByFlex = false (nếu đang ẩn)
            if (angleDeg < FLEX_HIDE_BELOW_DEG) {
                if (!tr.hiddenByFlex) {
                    tr.hiddenByFlex = true
                    Log.d(TAG, "HIDE: flex angle=${angleDeg.toInt()}° < ${FLEX_HIDE_BELOW_DEG.toInt()}° → hide track clsId=${tr.clsId}")
                }
            } else if (angleDeg > FLEX_SHOW_ABOVE_DEG) {
                if (tr.hiddenByFlex) {
                    tr.hiddenByFlex = false
                    Log.d(TAG, "SHOW: flex angle=${angleDeg.toInt()}° > ${FLEX_SHOW_ABOVE_DEG.toInt()}° → show track clsId=${tr.clsId}")
                }
            }
            // else: dead-zone → giữ nguyên trạng thái
        }
        // ─── 2. DEEP-FLEX detection (gập sâu → xóa track) ───────────────
        // Điều kiện:
        //   - Góc < 90° (gập vuông góc) HOẶC
        //   - TIP-DIP distance < 8% frameW (gập sâu distance path)
        // Thumb cũng áp dụng (dù cấu trúc khác, gập sâu là không có móng).
        val isDeepFlex = (angleDeg != null && angleDeg < DEEP_FLEX_ANGLE_DEG) ||
                         (dist != null && dist < lastFrameWidth * DEEP_FLEX_DISTANCE_RATIO)
        if (isDeepFlex) {
            tr.deepFlexFrames++
        } else {
            tr.deepFlexFrames = 0
        }
        return tr.deepFlexFrames >= DEEP_FLEX_FRAMES_TO_REMOVE
    }

    // ────────────────────────────────────────────────────────────────────

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
        // Fix Flex: đếm frame flex nhẹ (TIP-DIP distance < FLEX_SOFT_RATIO).
        // Khi >= FLEX_SOFT_FRAMES → skip render (track vẫn tồn tại để resume
        // ngay khi duỗi lại, không cần YOLO re-anchor). Reset về 0 khi duỗi.
        var flexFrames: Int = 0,
        // ═══════════════════════════════════════════════════════════
        // HIDE-LOGIC v3: per-track hide state với hysteresis
        // ═══════════════════════════════════════════════════════════
        /**
         * `true` = track đang bị ẩn (flex hoặc palm). Một khi đã ẩn thì
         * KHÔNG hiện lại cho đến khi cả flex-angle lẫn palm đều ở trạng
         * thái "show". Tránh chớp khi ngón run ở ranh giới gập.
         */
        var hiddenByFlex: Boolean = false,
        var hiddenByPalm: Boolean = false,
        /**
         * DEEP-FLEX counter: số frame liên tiếp có góc < 90° hoặc
         * distance < 8% frameW. Khi >= DEEP_FLEX_FRAMES_TO_REMOVE →
         * XÓA TRACK (gập sâu, móng bị che, cần YOLO re-anchor khi
         * duỗi). Reset về 0 mỗi khi ngón trở lại trạng thái bình thường.
         */
        var deepFlexFrames: Int = 0,
        /**
         * Force-show sau khi vừa anchor: số frame còn lại của "luôn
         * render" window. Set = FORCE_SHOW_FRAMES_AFTER_ANCHOR khi anchor,
         * giảm dần mỗi frame TRACKING.
         */
        var forceShowFrames: Int = FORCE_SHOW_FRAMES_AFTER_ANCHOR,
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
        pipPositions: Map<Int, PointF>,  // Fix Flex-angle: tính góc PIP-DIP-TIP
        frameW: Int,
        frameH: Int,
        // HIDE-LOGIC v3: 21 landmarks MediaPipe NORMALIZED coords [0..1].
        // State machine sẽ tự nhân frameW/frameH để ra pixel coords (dùng cho
        // palm-normal cross product). Null nếu chưa có MediaPipe result.
        skeletonNormalized: Array<FloatArray>? = null,
    ): Pair<Phase, List<NailDetection>> {
        lastFrameWidth = frameW
        lastFrameHeight = frameH
        lastTipPositions = tipPositions

        val hasHand = jointPositions.isNotEmpty()
        val yoloDetections = yoloPack?.detections ?: emptyList()

        // ── STATE TRANSITION ─────────────────────────────────────────────
        when (currentPhase) {
            Phase.SEARCHING -> {
                if (yoloPack != null) {
                    // BUG #2 FIX: nếu YOLO có detections rỗng (tay vừa xoay, móng
                    // không còn hướng camera) → CLEAR tracks cũ để renderer không
                    // vẽ nail "ảo" ở vị trí cũ. Cũng chuyển sang trạng thái LOST
                    // để chờ MediaPipe re-detect bàn tay (lúc đó sẽ chuyển lại
                    // SEARCHING và YOLO chạy lại).
                    if (yoloDetections.isEmpty() && tracks.isNotEmpty()) {
                        Log.i(TAG, "SEARCHING: YOLO returned 0 detections → clearing ${tracks.size} stale tracks (palm flipped?)")
                        tracks.clear()
                        currentPhase = Phase.LOST
                        return currentPhase to emptyList()
                    }
                    if (yoloDetections.isNotEmpty()) {
                        // TIME-CAPSULE: dùng MP từ pack (đồng bộ với YOLO), fallback
                        // sang MP camera-frame hiện tại nếu pack rỗng (YOLO đã chạy
                        // lúc MP chưa có landmark → vẫn cố gắng anchor với best-effort).
                        // Fix #2: anchor = TIP (pack.tipPositions), jointPositions = DIP.
                        val anchorsAtSubmit = yoloPack.anchorPositions.ifEmpty { yoloPack.tipPositions }
                        val dipsAtSubmit = yoloPack.jointPositions
                        val anchorsNow = anchorsAtSubmit.ifEmpty { tipPositions }
                        val dipsNow = dipsAtSubmit.ifEmpty { jointPositions }
                        anchorFromYolo(yoloDetections, anchorsNow, dipsNow, skeletonNormalized, frameW)
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
                    // Fix Flex: thêm 3 nhánh — HARD flex (nắm đấm), SOFT flex (gập nhẹ),
                    // duỗi (reset cả 2 đếm).
                    // Fix Flex-angle: tính thêm góc ∠PIP-DIP-TIP để bắt gập ngang
                    // (ngón xoay 90° làm TIP-DIP distance không đổi). OR với distance.
                    // HIDE-LOGIC v3: gọi updateHideState() cho từng track để cập nhật
                    // hiddenByFlex + hiddenByPalm.
                    val fistThresholdPx = lastFrameWidth * FIST_THRESHOLD_RATIO
                    val flexThresholdPx = lastFrameWidth * FLEX_SOFT_RATIO
                    val tracksToRemove = ArrayList<Int>()
                    val palmIsBack = computePalmSide(skeletonNormalized)
                    for ((clsId, tr) in tracks) {
                        if (jointPositions.containsKey(clsId)) {
                            tr.missFrames = 0
                            val tip = tipPositions[clsId]
                            val dip = jointPositions[clsId]
                            val pip = pipPositions[clsId]
                            val isLongFinger = clsId != 4  // clsId 4 = thumb, bỏ qua flex-angle
                            var angleDeg: Float? = null
                            var dist: Float? = null
                            if (tip != null && dip != null) {
                                val dx = tip.x - dip.x
                                val dy = tip.y - dip.y
                                dist = sqrt(dx * dx + dy * dy)
                                // Fix Flex-angle: tính góc ∠PIP-DIP-TIP.
                                if (pip != null) {
                                    val v1x = tip.x - dip.x
                                    val v1y = tip.y - dip.y
                                    val v2x = pip.x - dip.x
                                    val v2y = pip.y - dip.y
                                    val dot = v1x * v2x + v1y * v2y
                                    val m1 = sqrt(v1x * v1x + v1y * v1y)
                                    val m2 = sqrt(v2x * v2x + v2y * v2y)
                                    if (m1 > 1e-3f && m2 > 1e-3f) {
                                        val cosA = (dot / (m1 * m2)).coerceIn(-1f, 1f)
                                        angleDeg = Math.toDegrees(kotlin.math.acos(cosA).toDouble()).toFloat()
                                    }
                                }
                                val isAngleFlex = angleDeg != null && angleDeg < FLEX_ANGLE_THRESHOLD_DEG
                                when {
                                    dist < fistThresholdPx -> {
                                        // HARD flex (nắm đấm) — tăng fistFrames, đủ ngưỡng thì remove.
                                        tr.fistFrames++
                                        if (tr.fistFrames >= FIST_FRAMES_TO_REMOVE) {
                                            tracksToRemove.add(clsId)
                                        }
                                        // HARD flex cũng đồng thời là flex (skip render).
                                        tr.flexFrames = tr.fistFrames
                                    }
                                    dist < flexThresholdPx || isAngleFlex -> {
                                        // SOFT flex (gập nhẹ) — tăng flexFrames, KHÔNG remove.
                                        // OR với góc để bắt gập ngang (distance miss).
                                        tr.fistFrames = 0
                                        tr.flexFrames++
                                    }
                                    else -> {
                                        // Ngón duỗi — reset cả 2 đếm để resume render ngay.
                                        tr.fistFrames = 0
                                        tr.flexFrames = 0
                                    }
                                }
                                // Log góc để debug (chỉ in mỗi ~30 frame để tránh spam).
                                if (angleDeg != null && tr.trackId % 30 == 0) {
                                    Log.d(TAG, "clsId=$clsId dist=${dist.toInt()} angle=${angleDeg.toInt()}°")
                                }
                            }
                            // HIDE-LOGIC v4: cập nhật flex/deep-flex state trước.
                            // updateHideState trả về true nếu frame này đạt DEEP_FLEX
                            // (gập sâu đủ 3 frame liên tiếp) → xóa track triệt để.
                            val isDeepFlex = updateHideState(tr, angleDeg, dist, isLongFinger)
                            if (isDeepFlex) {
                                tracksToRemove.add(clsId)
                                Log.i(TAG, "track removed: DEEP-FLEX detected for clsId=$clsId (${tr.clsName}) " +
                                    "deepFlexFrames=${tr.deepFlexFrames} → will re-anchor via YOLO")
                            }
                            // HIDE-LOGIC v4: palm hide với dead-zone (chỉ chuyển
                            // trạng thái khi đổi dấu cross product, không chớp).
                            if (palmIsBack != null) {
                                if (!palmIsBack && !tr.hiddenByPalm) {
                                    tr.hiddenByPalm = true
                                    Log.d(TAG, "HIDE: palm side changed to FRONT → hide track clsId=${tr.clsId}")
                                } else if (palmIsBack && tr.hiddenByPalm) {
                                    tr.hiddenByPalm = false
                                    Log.d(TAG, "SHOW: palm side changed to BACK → show track clsId=${tr.clsId}")
                                }
                            }
                            // Decrement force-show window.
                            if (tr.forceShowFrames > 0) tr.forceShowFrames--
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
                synthesizeDetections(jointPositions, tipPositions, frameW, frameH)
            currentPhase == Phase.SEARCHING && tracks.isNotEmpty() && hasHand ->
                // Vừa anchor xong ở frame này, dùng synthesis ngay.
                synthesizeDetections(jointPositions, tipPositions, frameW, frameH)
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

        anchorFromYolo(pack.detections, anchorsMp, dipsMp, frameW = frameW)

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
        skeletonNormalized: Array<FloatArray>? = null,  // HIDE-LOGIC v3 (unused here, kept for symmetry)
        frameW: Int = 0,  // HIDE-LOGIC v3
    ) {
        tracks.clear()
        lastSearchDetections = detections.size
        val palmIsBack = computePalmSide(skeletonNormalized)

        // Fix B: pre-compute spatial lookup trên TIP — pair of (clsId, TIP).
        // Dùng để match YOLO bbox nếu clsId-match fail.
        val spatialAnchors: List<Pair<Int, PointF>> = anchorPositions.entries.map { it.key to it.value }
        // HIDE-LOGIC v3: displacement threshold để detect "xoay tay, YOLO
        // thấy móng ở chỗ mới xa so với anchor cũ" → reset polygon thay vì
        // EMA scale (giữ polygon cũ).
        val reanchorThresholdPx = if (frameW > 0) frameW * REANCHOR_DISPLACEMENT_RATIO else 0f

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
            // Fix Anchor-update: nếu track đã tồn tại → chỉ update scale reference
            // (lenRef, nailCenterRef) + reset flex/miss đếm. Giữ polygonTemplate cũ
            // (đã được scale theo proportions thực của anchor YOLO trước). Tránh
            // re-anchor toàn bộ gây giật "flash" nail khi YOLO chạy lại.
            val existing = tracks[matchedClsId]
            if (existing != null) {
                // Update lenRef với EMA (0.5) để smooth thay đổi scale khi tay
                // di chuyển xa/gần. Giữ polygonTemplate + nailBedTemplate cũ.
                val updatedLenRef = (existing.lenRef * 0.5f) + (lenRef * 0.5f)
                val scaleRatio = updatedLenRef / existing.lenRef.coerceAtLeast(1e-3f)
                val scaledPoly = ArrayList<PointF>(existing.polygonTemplate.size)
                val cx = existing.nailCenterRef.x
                val cy = existing.nailCenterRef.y
                for (p in existing.polygonTemplate) {
                    scaledPoly.add(PointF(cx + (p.x - cx) * scaleRatio, cy + (p.y - cy) * scaleRatio))
                }
                tracks[matchedClsId] = existing.copy(
                    nailCenterRef = nailCenterRef,
                    anchorJointRef = effectiveAnchor,
                    tipRef = effectiveAnchor,
                    forwardRef = forwardRef,
                    lenRef = updatedLenRef,
                    polygonTemplate = scaledPoly,
                    nailBedTemplate = scaledPoly,
                    designPath = det.designAssetPath ?: existing.designPath,
                    pcaDirection = det.pcaDirection?.let { PointF(it.x, it.y) } ?: existing.pcaDirection,
                    missFrames = 0,
                    fistFrames = 0,
                    flexFrames = 0,
                )
                Log.d(TAG, "anchorFromYolo: updated existing clsId=$matchedClsId lenRef ${existing.lenRef.toInt()} → ${updatedLenRef.toInt()}")
                continue
            }
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
                flexFrames = 0,
                // HIDE-LOGIC v3: track mới luôn force-show vài frame đầu (UX mượt).
                hiddenByFlex = false,
                hiddenByPalm = palmIsBack == null || palmIsBack == false, // nếu lòng bàn tay → hide luôn
                forceShowFrames = FORCE_SHOW_FRAMES_AFTER_ANCHOR,
            )
            // Nếu YOLO thấy nail mà palm đang ở lòng bàn tay → log lạ
            // (YOLO rất ít khi nhầm, nhưng nếu xảy ra thì biết).
            if (palmIsBack == false) {
                Log.w(TAG, "anchorFromYolo: YOLO detected nail but palm is facing DOWN — hiding immediately clsId=$matchedClsId")
            }
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
        frameW: Int,                       // Fix Viewport-clamp
        frameH: Int,
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
            // Fix Flex: skip render nếu ngón đang gập (flexFrames >= ngưỡng).
            // Track vẫn tồn tại để khi duỗi lại → resume ngay (không cần YOLO).
            if (tr.flexFrames >= FLEX_SOFT_FRAMES) {
                Log.d(TAG, "synthesizeDetections: skip render clsId=$clsId (flexFrames=${tr.flexFrames})")
                continue
            }
            // HIDE-LOGIC v3: ẩn nếu gập sâu hoặc lòng bàn tay (hysteresis).
            // Force-show trong FORCE_SHOW_FRAMES_AFTER_ANCHOR frame đầu (UX mượt khi tay mới xuất hiện).
            val isHiddenByLogic = tr.hiddenByFlex || tr.hiddenByPalm
            if (isHiddenByLogic && tr.forceShowFrames <= 0) {
                Log.d(TAG, "synthesizeDetections: skip render clsId=$clsId " +
                    "(hiddenByFlex=${tr.hiddenByFlex} hiddenByPalm=${tr.hiddenByPalm})")
                continue
            }
            // Fix Viewport-clamp: ép nail polygon nằm trong viewport frame
            // [0, frameW] × [0, frameH]. Khi ngón quá gần camera, polygon có
            // thể vượt mép; clamp tránh render ngoài màn hình.
            val fW = frameW.toFloat()
            val fH = frameH.toFloat()
            for (i in polygonNew.indices) {
                val p = polygonNew[i]
                polygonNew[i] = PointF(p.x.coerceIn(0f, fW), p.y.coerceIn(0f, fH))
            }
            for (i in nailBedNew.indices) {
                val p = nailBedNew[i]
                nailBedNew[i] = PointF(p.x.coerceIn(0f, fW), p.y.coerceIn(0f, fH))
            }
            val newBboxCx = nailCenterFinal.x.coerceIn(0f, fW)
            val newBboxCy = nailCenterFinal.y.coerceIn(0f, fH)
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