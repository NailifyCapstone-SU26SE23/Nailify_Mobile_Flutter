/*
 * MediaPipeRunner.kt — Wrapper cho MediaPipe Hand Landmarker LIVE_STREAM mode.
 *
 * Public API:
 *   submitFrame(bitmap, timestampMs) : feed 1 frame vào landmarker.
 *   lastFingerVectors                : per-finger forward unit vector (normalized)
 *   lastTipPositions                 : per-finger TIP landmark pixel coords
 *   lastSkeletonPoints               : 21 (x, y) normalized landmarks, dùng để vẽ debug
 *
 * MediaPipe tự quản lý internal thread (background). Kết quả trả về qua
 * callback chạy trên MediaPipe thread; ta cập nhật @Volatile fields.
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

        // 21-landmark skeleton mapping (matches getFingerTipPositions in legacy code).
        private val FINGER_TIP_INDEX = mapOf(
            0 to 8,    // Index
            1 to 12,   // Middle
            2 to 20,   // Pinky
            3 to 16,   // Ring
            4 to 4,    // Thumb
        )
        private val FINGER_PIP_INDEX = mapOf(
            0 to 6,    // Index PIP
            1 to 10,   // Middle PIP
            2 to 18,   // Pinky PIP
            3 to 14,   // Ring PIP
            4 to 2,    // Thumb IP
        )
    }

    private var handLandmarker: HandLandmarker? = null

    // Public, đọc từ background thread.
    @Volatile var lastFingerVectors: Map<Int, PointF> = emptyMap()
    @Volatile var lastTipPositions: Map<Int, PointF> = emptyMap()
    @Volatile var lastSkeletonPoints: Array<FloatArray>? = null

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

    fun submitFrame(bitmap: Bitmap, timestampMs: Long) {
        val landmarker = handLandmarker ?: return
        val mpImage: MPImage = try {
            BitmapImageBuilder(bitmap).build()
        } catch (e: Exception) {
            Log.w(TAG, "BitmapImageBuilder failed: ${e.message}")
            return
        }
        try {
            landmarker.detectAsync(mpImage, timestampMs)
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
            lastSkeletonPoints = null
            return
        }
        val landmarks = hands[0]
        val n = landmarks.size

        val vectors = HashMap<Int, PointF>()
        for ((clsId, pipIdx) in FINGER_PIP_INDEX) {
            if (pipIdx >= n) continue
            val tipIdx = FINGER_TIP_INDEX[clsId] ?: continue
            if (tipIdx >= n) continue
            val pip = landmarks[pipIdx]
            val tip = landmarks[tipIdx]
            val dx = tip.x() - pip.x()
            val dy = tip.y() - pip.y()
            val mag = hypot(dx.toDouble(), dy.toDouble())
            if (mag > 1e-6) {
                vectors[clsId] = PointF((dx / mag).toFloat(), (dy / mag).toFloat())
            }
        }
        lastFingerVectors = vectors

        // Tip positions ở pixel coords. Để scale sang pixel, cần frame size.
        // Tạm thời lưu normalized, PipelineExecutor sẽ scale khi biết frame size.
        // Ở đây ta chỉ tính vector; tip pixel pos cần frame size.
        // Pipeline sẽ dùng normalized coords + frame size.
        lastTipPositions = emptyMap() // để Pipeline scale vectors dùng diag.

        // Skeleton points: 21 cặp (x, y) normalized.
        val skel = Array(n) { i ->
            floatArrayOf(landmarks[i].x(), landmarks[i].y())
        }
        lastSkeletonPoints = skel
    }
}