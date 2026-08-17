/*
 * MediaPipeRunner.kt — Wrapper cho MediaPipe Hand Landmarker LIVE_STREAM mode.
 *
 * Public API:
 *   submitFrame(bitmap)              : feed 1 frame vào landmarker.
 *   lastFingerVectors                : per-finger forward unit vector (normalized)
 *                                       — tính từ DIP → TIP (hướng của đốt ngón tay CUỐI,
 *                                         nơi móng mọc). Chính là vector xoay trục chính
 *                                         của móng.
 *   lastTipPositions                 : per-finger TIP landmark PIXEL coords (đầu ngón tay)
 *   lastJointPositions               : per-finger DIP landmark PIXEL coords (anchor)
 *                                       — Đổt sát đầu ngón tay, khoảng cách tới móng
 *                                         gần như cố định khi ngón tay gập. Anchor chính.
 *   lastSkeletonPoints               : 21 (x, y) normalized landmarks (debug)
 *   lastImageWidth / lastImageHeight : Kích thước frame bitmap gần nhất.
 *
 * QUAN TRỌNG — TIMESTAMP:
 *   MediaPipe yêu cầu timestamp STRICTLY INCREASING. Dùng System.currentTimeMillis()
 *   là không đủ vì camera có thể đẩy 2 frame trong cùng 1 ms, dẫn đến MediaPipe
 *   crash ngầm → callback ngừng gọi → fields kẹt giá trị cũ (móng đóng băng
 *   dù tay đã ra khỏi camera). Fix: dùng System.nanoTime() / 1000 (microseconds)
 *   — monotonic và luôn strictly increasing vì mỗi frame có ít nhất vài chục us.
 *
 * MediaPipe tự quản lý internal thread (background). Kết quả trả về qua
 * callback chạy trên MediaPipe thread; ta cập nhật @Volatile fields.
 *
 * ═══════════════════════════════════════════════════════════
 * LANDMARK MAPPING (21 điểm của MediaPipe Hand):
 * ═══════════════════════════════════════════════════════════
 *       WRIST(0)
 *          |
 *    THUMB(1..4)   INDEX(5..8)    MIDDLE(9..12)   RING(13..16)   PINKY(17..20)
 *      CMC  MCP    IP   TIP       MCP PIP DIP TIP  MCP PIP DIP TIP  MCP PIP DIP TIP
 *       1   2      3    4         5    6   7   8    9   10 11 12   13  14 15 16
 *                                              (note: thumb không có DIP đúng nghĩa —
 *                                               landmark 3 là IP, ta dùng IP làm "DIP"
 *                                               cho thumb để vector có địa chỉ rõ ràng)
 *
 * THAM KHẢO: Khi truyền anchor= PIP, móng trượt khi gập ngón — vì khoảng cách
 * PIP↔nail center co giãn theo góc gập. Anchor= DIP là giải pháp tối ưu: DIP
 * nằm rất gần móng, và vector DIP→TIP biểu thị chính xác hướng đốt ngón cuối.
 */
package com.nailify.nail_plugin.mediapipe

import android.content.Context
import android.graphics.Bitmap
import android.graphics.PointF
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import kotlin.math.hypot

class MediaPipeRunner(private val context: Context) {

    companion object {
        private const val TAG = "MediaPipeRunner"
        private const val MP_HAND_LANDMARKER_TASK = "hand_landmarker.task"

        // Landmark TIP — đầu ngón tay.
        private val FINGER_TIP_INDEX = mapOf(
            0 to 8,    // Index tip
            1 to 12,   // Middle tip
            2 to 20,   // Pinky tip
            3 to 16,   // Ring tip
            4 to 4,    // Thumb tip
        )

        // Landmark DIP — đốt sát đầu ngón tay (anchor chính).
        // Khớp này nằm gần móng, khoảng cách DIP↔nail gần như cố định khi gập ngón.
        private val FINGER_DIP_INDEX = mapOf(
            0 to 7,    // Index DIP
            1 to 11,   // Middle DIP
            2 to 19,   // Pinky DIP
            3 to 15,   // Ring DIP
            4 to 3,    // Thumb IP (coi như DIP vì thumb không có DIP đúng nghĩa)
        )

        // Landmark PIP — khớp giữa đốt ngón tay, dùng tính góc gập ngón.
        // Fix Flex-angle: khi ngón gập ngang (góc ~90°), TIP-DIP distance không
        // đổi → SOFT flex (distance) miss. Góc PIP-DIP-TIP < 130° mới bắt được.
        private val FINGER_PIP_INDEX = mapOf(
            0 to 6,    // Index PIP
            1 to 10,   // Middle PIP
            2 to 18,   // Pinky PIP
            3 to 14,   // Ring PIP
            4 to 2,    // Thumb MCP (thumb layout khác, dùng tạm landmark 2)
        )
    }

    private var handLandmarker: HandLandmarker? = null

    // Public, đọc từ background thread.
    @Volatile var lastFingerVectors: Map<Int, PointF> = emptyMap()
    @Volatile var lastTipPositions: Map<Int, PointF> = emptyMap()
    @Volatile var lastJointPositions: Map<Int, PointF> = emptyMap()
    /**
     * Fix #2 (TIP anchor): vị trí TIP (đầu ngón tay) PIXEL — dùng làm anchor
     * cho nail. TIP là điểm "móng nằm ở đó" nên anchor trực quan hơn DIP.
     * Backward-compatible: lastJointPositions (DIP) vẫn được giữ cho debug.
     */
    @Volatile var lastAnchorPositions: Map<Int, PointF> = emptyMap()
    @Volatile var lastSkeletonPoints: Array<FloatArray>? = null
    @Volatile var lastImageWidth: Int = 0
    @Volatile var lastImageHeight: Int = 0
    /**
     * Fix Flex-angle: per-finger PIP landmark PIXEL coords. Kết hợp với
     * lastTipPositions và lastJointPositions (DIP) để tính góc
     * ∠PIP-DIP-TIP — phát hiện gập ngang (ngón xoay 90°) mà distance không thấy.
     */
    @Volatile var lastPipPositions: Map<Int, PointF> = emptyMap()

    /**
     * Timestamp microseconds đã gửi lần trước — bảo đảm strictly increasing
     * để MediaPipe không crash ngầm. MediaPipe Tasks yêu cầu Long.
     */
    @Volatile private var lastTimestampUs: Long = 0L

    init {
        try {
            val baseOptions = BaseOptions.builder()
                .setDelegate(Delegate.CPU)
                .setModelAssetPath(MP_HAND_LANDMARKER_TASK)
                .build()
            val options = HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setMinHandDetectionConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setMinHandPresenceConfidence(0.5f)
                .setNumHands(1)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setResultListener { result, _ -> onResult(result) }
                .setErrorListener { err -> Log.w(TAG, "MediaPipe error: ${err.message}") }
                .build()
            handLandmarker = HandLandmarker.createFromOptions(context, options)
            Log.i(TAG, "MediaPipe HandLandmarker initialized (LIVE_STREAM)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to init MediaPipe: ${e.message}", e)
            handLandmarker = null
        }
    }

    fun close() {
        try { handLandmarker?.close() } catch (_: Exception) {}
        handLandmarker = null
    }

    fun submitFrame(bitmap: Bitmap) {
        val landmarker = handLandmarker ?: return
        val mpImage: MPImage = try {
            BitmapImageBuilder(bitmap).build()
        } catch (e: Exception) {
            Log.w(TAG, "BitmapImageBuilder failed: ${e.message}")
            return
        }
        // Strictly increasing microseconds. nanoTime() là monotonic clock (không
        // bị lùi khi user chỉnh giờ). MediaPipe Tasks yêu cầu timestamp là Long
        // microseconds và strictly increasing. Long.MAX_VALUE ≈ 292 năm nên
        // không lo overflow trong 1 session camera.
        val nowUs = System.nanoTime() / 1000L
        val timestampUs = if (lastTimestampUs >= nowUs) lastTimestampUs + 1L else nowUs
        lastTimestampUs = timestampUs
        try {
            landmarker.detectAsync(mpImage, timestampUs)
        } catch (e: Exception) {
            Log.w(TAG, "detectAsync failed: ${e.message}")
        }
    }

    // -------------------------------------------------------------------------
    // Result callback (chạy trên MediaPipe internal thread).
    // -------------------------------------------------------------------------

    private fun onResult(result: HandLandmarkerResult) {
        val hands = result.landmarks()
        if (hands.isEmpty()) {
            lastFingerVectors = emptyMap()
            lastTipPositions = emptyMap()
            lastJointPositions = emptyMap()
            lastPipPositions = emptyMap()
            lastSkeletonPoints = null
            return
        }
        val landmarks = hands[0]
        val n = landmarks.size

        val w = lastImageWidth.toFloat().coerceAtLeast(1f)
        val h = lastImageHeight.toFloat().coerceAtLeast(1f)

        // Forward vector = (TIP − DIP) normalized.
        // Đây là vector chỉ hướng của đốt ngón tay CUỐI CÙNG (đốt có gắn móng).
        // Ổn định hơn vector (PIP → TIP) cũ vì đốt ngoài cùng ít bị xoắn hơn khi gập.
        val vectors = HashMap<Int, PointF>()
        val tips = HashMap<Int, PointF>()
        val anchors = HashMap<Int, PointF>()
        val pips = HashMap<Int, PointF>()
        for ((clsId, dipIdx) in FINGER_DIP_INDEX) {
            if (dipIdx >= n) continue
            val tipIdx = FINGER_TIP_INDEX[clsId] ?: continue
            if (tipIdx >= n) continue
            val dip = landmarks[dipIdx]
            val tip = landmarks[tipIdx]

            // Forward direction (DIP → TIP).
            val dxN = tip.x() - dip.x()
            val dyN = tip.y() - dip.y()
            val magN = hypot(dxN.toDouble(), dyN.toDouble())
            if (magN > 1e-6) {
                vectors[clsId] = PointF((dxN / magN).toFloat(), (dyN / magN).toFloat())
            }

            // Pixel coords:
            //  - TIP pixel: dùng để truyền cho renderer (đầu ngón).
            //  - DIP pixel: dùng làm ANCHOR chính (neo nail khi gập ngón không trượt).
            tips[clsId] = PointF(tip.x() * w, tip.y() * h)
            anchors[clsId] = PointF(dip.x() * w, dip.y() * h)

            // Fix Flex-angle: PIP pixel để tính góc gập ngón.
            val pipIdx = FINGER_PIP_INDEX[clsId]
            if (pipIdx != null && pipIdx < n) {
                val pip = landmarks[pipIdx]
                pips[clsId] = PointF(pip.x() * w, pip.y() * h)
            }
        }
        lastFingerVectors = vectors
        lastTipPositions = tips
        lastJointPositions = anchors
        lastPipPositions = pips
        // Fix #2: anchor chính cho nail = TIP (đầu ngón tay). Nail nằm ở TIP,
        // anchor = TIP cho khoảng cách nail→TIP gần như không đổi khi gập.
        lastAnchorPositions = HashMap(tips)

        // Skeleton points: 21 cặp (x, y) normalized — dùng cho debug.
        val skel = Array(n) { i ->
            floatArrayOf(landmarks[i].x(), landmarks[i].y())
        }
        lastSkeletonPoints = skel
    }
}