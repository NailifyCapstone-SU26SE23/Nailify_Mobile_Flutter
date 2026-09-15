package com.google.mediapipe.examples.handlandmarker.nail

import android.graphics.Bitmap
import android.graphics.PointF
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

/**
 * Phase 5 + 6.1: Nail Detection Pipeline Orchestrator.
 *
 * Điều phối toàn bộ CV pipeline: ROI extraction → segmentation → boundary detection → auto-scaling.
 *
 * **Live mode**: Chạy CV ở throttled rate (mỗi N frame) để duy trì ≥25 FPS.
 *   Giữa các lần detection, tái sử dụng boundary cũ + cập nhật center từ landmark mới.
 *
 * **Snapshot mode**: Chạy full pipeline (không throttle) cho độ chính xác cao nhất.
 *
 * **Auto-scaling** (Phase 5):
 *   - Scale: dùng detected nail width/length thay vì mcpPipDist.
 *   - Position: dùng detected nail center thay vì TIP landmark.
 *   - Rotation: blend 70% fingerAxis + 30% boundary principal axis.
 *   - Confidence-weighted fallback: nếu detection thất bại, fallback sang geometric.
 *
 * @param throttleFrameInterval  Số frame giữa các lần chạy CV full pipeline (live mode).
 *                                Mặc định 3 → chạy CV ~10 FPS tại 30 FPS camera.
 */
class NailDetectionPipeline(
    private val nailDetector: NailDetector = NailDetector(),
    private val nailSegmenter: NailSegmenter = NailSegmenter(),
    private val boundaryDetector: BoundaryDetector = BoundaryDetector(),
    private val throttleFrameInterval: Int = DEFAULT_THROTTLE_FRAMES,
) {
    /**
     * Kết quả detection cho toàn bộ bàn tay (tất cả ngón).
     */
    data class HandDetectionResult(
        val results: List<NailDetectionResult>,
        val sourceBitmap: Bitmap?,
    )

    // ── Throttling state ──────────────────────────────────────────────────
    private var frameCounter = 0

    // ── Cached last detection results (per finger) ────────────────────────
    // Giữa các lần chạy CV, tái sử dụng boundary cũ + cập nhật center từ landmark.
    private val lastResults = arrayOfNulls<NailDetectionResult>(5)

    // Landmark indices cho từng ngón (TIP, PIP, MCP)
    private val fingerTips = intArrayOf(4, 8, 12, 16, 20)
    private val fingerPips = intArrayOf(3, 6, 10, 14, 18)
    private val fingerMcps = intArrayOf(2, 5, 9, 13, 17)

    /**
     * Phát hiện nail cho tất cả ngón tay.
     *
     * @param sourceBitmap    Ảnh gốc (camera frame hoặc snapshot).
     * @param handLandmarks   Landmarks của 1 bàn tay từ MediaPipe.
     * @param imageWidth       Chiều rộng ảnh gốc (pixel).
     * @param imageHeight      Chiều cao ảnh gốc (pixel).
     * @param isLiveMode       true = live mode (throttle), false = snapshot (full).
     * @return HandDetectionResult chứa kết quả cho 5 ngón.
     */
    fun detect(
        sourceBitmap: Bitmap?,
        handLandmarks: List<NormalizedLandmark>,
        imageWidth: Int,
        imageHeight: Int,
        isLiveMode: Boolean
    ): HandDetectionResult {
        if (sourceBitmap == null || handLandmarks.isEmpty()) {
            return HandDetectionResult(
                results = (0..4).map { NailDetectionResult.failed(it) },
                sourceBitmap = sourceBitmap
            )
        }

        // ── Throttling (live mode only) ──────────────────────────────────
        val shouldRunCv: Boolean
        if (isLiveMode) {
            frameCounter++
            shouldRunCv = frameCounter >= throttleFrameInterval
            if (shouldRunCv) frameCounter = 0
        } else {
            shouldRunCv = true  // Snapshot: luôn chạy full
        }

        val results = mutableListOf<NailDetectionResult>()

        for (fingerIndex in 0..4) {
            val tipIdx = fingerTips[fingerIndex]
            val pipIdx = fingerPips[fingerIndex]
            val mcpIdx = fingerMcps[fingerIndex]

            if (tipIdx >= handLandmarks.size || pipIdx >= handLandmarks.size || mcpIdx >= handLandmarks.size) {
                results.add(NailDetectionResult.failed(fingerIndex))
                continue
            }

            val tipLandmark = handLandmarks[tipIdx]
            val pipLandmark = handLandmarks[pipIdx]
            val mcpLandmark = handLandmarks[mcpIdx]

            if (shouldRunCv) {
                // ── Run full CV pipeline ─────────────────────────────────
                val result = runFullPipeline(
                    sourceBitmap, fingerIndex,
                    tipLandmark, pipLandmark, mcpLandmark,
                    imageWidth, imageHeight
                )
                lastResults[fingerIndex] = result
                results.add(result)
            } else {
                // ── Throttled: reuse last boundary, update center from landmark ──
                val cached = lastResults[fingerIndex]
                if (cached != null && cached.detected) {
                    // Update nail center based on new TIP landmark (cheap)
                    val updatedCenterX = tipLandmark.x() * imageWidth
                    val updatedCenterY = tipLandmark.y() * imageHeight
                    // Reuse width/length/rotation from cached result
                    results.add(cached.copy(
                        nailCenterX = updatedCenterX,
                        nailCenterY = updatedCenterY
                    ))
                } else {
                    // No cached result — fail
                    results.add(NailDetectionResult.failed(fingerIndex))
                }
            }
        }

        return HandDetectionResult(results = results, sourceBitmap = sourceBitmap)
    }

    /**
     * Chạy full CV pipeline cho 1 ngón: ROI → segment → boundary → auto-scale.
     */
    private fun runFullPipeline(
        sourceBitmap: Bitmap,
        fingerIndex: Int,
        tipLandmark: NormalizedLandmark,
        pipLandmark: NormalizedLandmark,
        mcpLandmark: NormalizedLandmark,
        imageWidth: Int,
        imageHeight: Int
    ): NailDetectionResult {
        // ── Phase 2: ROI Extraction ──────────────────────────────────────
        val roi = nailDetector.extractRoi(sourceBitmap, tipLandmark, mcpLandmark, pipLandmark)
            ?: return NailDetectionResult.failed(fingerIndex)

        // ── Phase 3: Segmentation ────────────────────────────────────────
        val segResult = nailSegmenter.segment(roi.bitmap)

        // ── Phase 4: Boundary Detection ──────────────────────────────────
        val boundaryResult = boundaryDetector.detect(segResult.mask, segResult.width, segResult.height)

        // Cleanup ROI bitmap
        roi.bitmap.recycle()

        if (!boundaryResult.detected) {
            return NailDetectionResult.failed(fingerIndex)
        }

        // ── Phase 5: Auto-Scaling — transform ROI-local to image-space ───
        return transformToImageSpace(
            fingerIndex,
            boundaryResult,
            roi,
            tipLandmark,
            pipLandmark,
            imageWidth,
            imageHeight
        )
    }

    /**
     * Phase 5: Transform boundary detection result từ ROI-local coords sang image-space.
     *
     * Auto-scaling logic:
     *   - Nail center: detected center trong ROI → image-space (qua roiX, roiY, rotation).
     *   - Nail width/length: detected bbox → image-space (chia scaleFactor).
     *   - Rotation: blend 70% fingerAxis + 30% boundary principal axis.
     *   - Confidence: từ boundary detection.
     */
    private fun transformToImageSpace(
        fingerIndex: Int,
        boundary: BoundaryDetector.BoundaryResult,
        roi: NailDetector.NailRoi,
        tipLandmark: NormalizedLandmark,
        pipLandmark: NormalizedLandmark,
        imageWidth: Int,
        imageHeight: Int
    ): NailDetectionResult {
        // TIP landmark pixel position (image-space)
        val tipX = tipLandmark.x() * imageWidth
        val tipY = tipLandmark.y() * imageHeight

        // PIP landmark pixel position (image-space)
        val pipX = pipLandmark.x() * imageWidth
        val pipY = pipLandmark.y() * imageHeight

        // Finger axis angle (rad) — atan2(tip - pip) in image space
        val fingerAngleRad = atan2(
            (tipY - pipY).toDouble(),
            (tipX - pipX).toDouble()
        ).toFloat()

        // ROI was rotated by -(fingerAngleRad + π/2) to align finger axis vertically.
        // To transform ROI-local center back to image-space, we need to reverse the rotation.
        // ROI center (local) is at (boundary.centerX, boundary.centerY) in ROI coords.
        // ROI was created with TIP at center, then rotated and scaled.

        // The ROI's coordinate transform:
        //   1. Translate TIP to origin: (px - tipX, py - tipY)
        //   2. Rotate by -(fingerAngleRad + π/2): angle = rotationDeg
        //   3. Translate to ROI center: + (roiSize/2, roiSize/2)
        //   4. Scale by downsampleFactor

        // To reverse: take ROI-local point → scale up → unrotate → translate back
        val sf = roi.scaleFactor

        // ROI-local center (unscaled)
        val roiCenterXUnscaled = boundary.centerX / sf
        val roiCenterYUnscaled = boundary.centerY / sf

        // The ROI was rotated by rotationDeg = -(fingerAngleRad + π/2) * 180/π
        // To unrotate, apply the inverse rotation.
        // The rotation was around TIP point, then translated.
        // After step 3 (translate to ROI center), the point is at (roiCenterXUnscaled, roiCenterYUnscaled)
        // relative to ROI origin (0,0).
        // Before step 3, the point was at (roiCenterXUnscaled - roiWidth/2, roiCenterYUnscaled - roiHeight/2)
        // relative to TIP.

        val relX = roiCenterXUnscaled - roi.roiWidth / 2f
        val relY = roiCenterYUnscaled - roi.roiHeight / 2f

        // Unrotate: rotation angle was rotationDeg = -(fingerAngleRad + π/2)
        // Inverse rotation = +(fingerAngleRad + π/2)
        val unrotateAngle = fingerAngleRad + Math.PI.toFloat() / 2f
        val cosA = cos(unrotateAngle)
        val sinA = sin(unrotateAngle)

        // Rotated point relative to TIP in image space
        val imgRelX = relX * cosA - relY * sinA
        val imgRelY = relX * sinA + relY * cosA

        // Final nail center in image space
        val nailCenterX = tipX + imgRelX
        val nailCenterY = tipY + imgRelY

        // Nail dimensions in image space (unscale from ROI)
        val nailWidthPx = boundary.width / sf * NAIL_WIDTH_OVERLAP_FACTOR
        val nailLengthPx = boundary.length / sf

        // Rotation: blend 70% finger axis + 30% boundary principal axis
        // Finger axis in degrees (0° = along +X axis in image space)
        val fingerAxisDeg = Math.toDegrees(fingerAngleRad.toDouble()).toFloat()
        // Boundary principal angle is in ROI-local space (where finger is vertical)
        // In ROI space, principal angle ~0° means horizontal (perpendicular to finger)
        // Convert to image-space rotation
        val boundaryDeg = Math.toDegrees(boundary.principalAngle.toDouble()).toFloat()
        // Blend: weighted average, accounting for angle wrapping
        val rotationDeg = blendAngles(fingerAxisDeg + 90f, boundaryDeg, 0.7f)

        return NailDetectionResult(
            fingerIndex = fingerIndex,
            detected = true,
            nailCenterX = nailCenterX,
            nailCenterY = nailCenterY,
            nailWidthPx = nailWidthPx,
            nailLengthPx = nailLengthPx,
            rotationDeg = rotationDeg,
            confidence = boundary.confidence,
            boundaryPoints = boundary.boundaryPoints,
            nailArea = boundary.area,
        )
    }

    /**
     * Blend hai góc (độ) với trọng số, xử lý wrapping quanh 360°.
     */
    private fun blendAngles(angle1: Float, angle2: Float, weight1: Float): Float {
        val weight2 = 1f - weight1
        var diff = ((angle2 - angle1 + 540f) % 360f) - 180f
        val blended = angle1 + diff * weight2
        return ((blended % 360f) + 360f) % 360f
    }

    /**
     * Reset cached state — gọi khi hand tracking bị mất hoặc mode thay đổi.
     */
    fun reset() {
        frameCounter = 0
        for (i in lastResults.indices) {
            lastResults[i] = null
        }
    }

    companion object {
        private const val TAG = "NailDetectionPipeline"

        /** Số frame giữa các lần chạy CV full pipeline (live mode). */
        private const val DEFAULT_THROTTLE_FRAMES = 3

        /** Hệ số overlap cho nail width (1.05 = 5% rộng hơn móng thật để tránh gap). */
        private const val NAIL_WIDTH_OVERLAP_FACTOR = 1.05f
    }
}
