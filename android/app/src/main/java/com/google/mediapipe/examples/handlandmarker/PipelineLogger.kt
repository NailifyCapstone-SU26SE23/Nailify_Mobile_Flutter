package com.google.mediapipe.examples.handlandmarker

import android.util.Log

/**
 * Centralized pipeline logger cho toàn bộ Nailify AR pipeline.
 *
 * QUY TẮC ĐẶT TAG:
 *   [PHASE] = chữ viết tắt 2-4 ký tự cho từng bước pipeline.
 *   Log format: "  ".repeat(depth) + "[PHASE] message"
 *
 * PIPELINE PHASES:
 *   CAP     CameraX ImageAnalysis: nhận ImageProxy
 *   CONV    ImageProxy → Bitmap → MPImage conversion
 *   DETECT  handLandmarker.detectAsync() called
 *   MODEL   MediaPipe HandLandmarker internal inference
 *   RESULT  returnLivestreamResult / onResults callback
 *   META    OverlayView.setResults() + scaleFactor computation
 *   METRICS computeFingerMetrics() cho 1 ngón
 *   FILTER  OneEuroFilter.apply() cho 1 ngón
 *   RENDER  Canvas.drawNail() cho 1 ngón
 *   SNAP    Snapshot mode pipeline
 *
 * FILTERING trong logcat:
 *   adb logcat -s NailifyPipeline   → chỉ pipeline logs
 *   adb logcat -s NailifyPipeline:* → pipeline + all sub-tags
 */
object PipelineLogger {

    private const val TAG = "NailifyPipeline"

    /** Bật/tắt toàn bộ pipeline logging. Đặt = false trong release. */
    var ENABLED = true

    /** Bật chi tiết per-finger metrics. */
    var VERBOSE_METRICS = true

    /** Bật timing info. */
    var SHOW_TIMING = true

    // ─── Phase tags ─────────────────────────────────────────────────────────

    const val CAP     = "CAP"
    const val CONV    = "CONV"
    const val DETECT  = "DETECT"
    const val MODEL   = "MODEL"
    const val RESULT  = "RESULT"
    const val META    = "META"
    const val METRICS = "METRICS"
    const val FILTER  = "FILTER"
    const val RENDER  = "RENDER"
    const val SNAP    = "SNAP"

    // ─── Timing: frame-level ────────────────────────────────────────────────

    /** timestamp (SystemClock.uptimeMillis()) khi frame được capture. */
    private var frameCaptureNs: Long = 0L

    /** timestamp khi handLandmarker.detectAsync() được gọi. */
    private var frameDetectNs: Long = 0L

    /** timestamp khi onResults callback được gọi. */
    private var frameResultNs: Long = 0L

    /** Reset tất cả frame timestamps. Gọi khi bắt đầu frame mới ở CAP. */
    fun resetFrameTiming() {
        frameCaptureNs = System.nanoTime()
        frameDetectNs  = 0L
        frameResultNs  = 0L
    }

    fun markDetect()  { frameDetectNs  = System.nanoTime() }
    fun markResult()  { frameResultNs  = System.nanoTime() }

    // ─── Log methods ────────────────────────────────────────────────────────

    private fun log(phase: String, depth: Int, message: String) {
        if (!ENABLED) return
        val indent = "  ".repeat(depth)
        Log.v(TAG, "$indent[$phase] $message")
    }

    internal fun log(phase: String, depth: Int, lazy: () -> String) {
        if (!ENABLED) return
        val indent = "  ".repeat(depth)
        Log.v(TAG, "$indent[$phase] ${lazy()}")
    }

    private fun elapsed(prefix: String, startNs: Long, endNs: Long): String {
        val ms = (endNs - startNs) / 1_000_000.0
        return "$prefix${String.format("%.1f", ms)}ms"
    }

    // ─── CAP: Camera capture ────────────────────────────────────────────────

    /** Gọi ngay khi CameraX ImageAnalysis nhận được ImageProxy. */
    fun capReceived(imageWidth: Int, imageHeight: Int, rotation: Int) {
        log(CAP, 0) { "ImageProxy received: ${imageWidth}×${imageHeight} rotation=${rotation}°" }
    }

    /** Gọi khi ImageProxy được close — kết thúc bước CAP. */
    fun capClosed() {
        log(CAP, 0) { "ImageProxy closed" }
    }

    // ─── CONV: Conversion ───────────────────────────────────────────────────

    /** Gọi sau khi Bitmap được tạo thành công. */
    fun convBitmap(bitmapW: Int, bitmapH: Int, frontCamera: Boolean, rotation: Int) {
        log(CONV, 1) {
            val flip = if (frontCamera) " FLIP-H" else ""
            "Bitmap created: ${bitmapW}×${bitmapH}${flip} rotation=${rotation}°"
        }
    }

    /** Gọi khi convert thất bại. */
    fun convFailed(reason: String) {
        log(CONV, 1) { "CONVERSION FAILED: $reason" }
    }

    // ─── DETECT: detectAsync ────────────────────────────────────────────────

    /** Gọi ngay trước handLandmarker.detectAsync(). */
    fun detectCalled(frameTimeMs: Long) {
        markDetect()
        log(DETECT, 1) { "detectAsync called frameTime=$frameTimeMs" }
        if (SHOW_TIMING && frameCaptureNs > 0) {
            log(DETECT, 1) { elapsed("CAP→DETECT: ", frameCaptureNs, frameDetectNs) }
        }
    }

    // ─── MODEL: Inference ───────────────────────────────────────────────────

    /** Gọi bên trong returnLivestreamResult — thời điểm model trả kết quả. */
    fun modelDone(inferenceTimeMs: Long, handsFound: Int) {
        log(MODEL, 1) { "Inference done: ${inferenceTimeMs}ms  hands=$handsFound" }
        if (SHOW_TIMING && frameDetectNs > 0) {
            log(MODEL, 1) { elapsed("DETECT→MODEL: ", frameDetectNs, System.nanoTime()) }
        }
    }

    // ─── RESULT: Callback ───────────────────────────────────────────────────

    /** Gọi đầu tiên trong onResults / returnLivestreamResult. */
    fun resultReceived(
        inputW: Int,
        inputH: Int,
        numHands: Int,
        landmarksPerHand: Int
    ) {
        markResult()
        log(RESULT, 0) {
            val timing = if (SHOW_TIMING && frameResultNs > 0 && frameCaptureNs > 0) {
                "  (${elapsed("CAP→RESULT: ", frameCaptureNs, frameResultNs)})"
            } else ""
            "onResults: ${inputW}×${inputH}  hands=$numHands  landmarks/hand=$landmarksPerHand$timing"
        }
    }

    // ─── META: setResults / draw ────────────────────────────────────────────

    fun metaSetResults(imageW: Int, imageH: Int, viewW: Int, viewH: Int, sf: Float) {
        log(META, 1) { "setResults: img=${imageW}×${imageH}  view=${viewW}×${viewH}  scaleFactor=$sf" }
    }

    fun metaDrawNails(applyFilters: Boolean, sf: Float, handCount: Int) {
        val filterStr = if (applyFilters) "LIVE" else "SNAP"
        log(META, 1) { "drawNails [$filterStr]: sf=$sf  hands=$handCount" }
    }

    fun metaNoResults() {
        log(META, 1) { "drawNails: no results → skip entire draw" }
    }

    // ─── METRICS: computeFingerMetrics ──────────────────────────────────────

    fun metricsEntry(
        fingerName: String,
        fingerIndex: Int,
        tipX: Float,
        tipY: Float,
        tipZ: Float,
        visibility: Float
    ) {
        if (!VERBOSE_METRICS) return
        log(METRICS, 2) {
            "finger=$fingerName[$fingerIndex]  TIP=(${String.format("%.3f", tipX)}, ${String.format("%.3f", tipY)}, ${String.format("%.3f", tipZ)})  vis=${String.format("%.2f", visibility)}"
        }
    }

    fun metricsComputed(
        fingerName: String,
        fingerIndex: Int,
        mcpTipDist: Float,
        pipTipDist: Float,
        bentRatio: Float,
        dipDipRatio: Float,
        foldAngle: Float,
        isBent: Boolean,
        skipReason: String?
    ) {
        if (!VERBOSE_METRICS) return
        val bentStr = if (isBent) "BENT" else "OK"
        val skipStr = skipReason?.let { " → SKIP[$it]" } ?: ""
        log(METRICS, 2) {
            "finger=$fingerName[$fingerIndex]  ${bentStr}  mcpTip=${String.format("%.3f", mcpTipDist)}  pipTip=${String.format("%.3f", pipTipDist)}  " +
            "bentRatio=${String.format("%.3f", bentRatio)}  dipDipRatio=${String.format("%.3f", dipDipRatio)}  foldAngle=${String.format("%.1f", foldAngle)}°$skipStr"
        }
    }

    // ─── FILTER: OneEuroFilter ──────────────────────────────────────────────

    fun filterApplied(
        fingerName: String,
        rawX: Float,
        rawY: Float,
        filteredX: Float,
        filteredY: Float,
        dx: Float,
        dy: Float
    ) {
        if (!VERBOSE_METRICS) return
        log(FILTER, 2) {
            "finger=$fingerName  raw=(${String.format("%.1f", rawX)}, ${String.format("%.1f", rawY)})  filtered=(${String.format("%.1f", filteredX)}, ${String.format("%.1f", filteredY)})  delta=(${String.format("%.2f", dx)}, ${String.format("%.2f", dy)})"
        }
    }

    // ─── RENDER: Nail drawn ─────────────────────────────────────────────────

    fun nailRendered(
        fingerName: String,
        centerX: Float,
        centerY: Float,
        rotation: Float,
        nailW: Float,
        nailH: Float,
        color: String,
        decorations: Int
    ) {
        log(RENDER, 2) {
            "finger=$fingerName  center=(${String.format("%.1f", centerX)}, ${String.format("%.1f", centerY)})  " +
            "rot=${String.format("%.1f", rotation)}°  size=${String.format("%.1f", nailW)}×${String.format("%.1f", nailH)}  " +
            "color=$color  decorations=$decorations"
        }
    }

    // ─── SNAP: Snapshot mode ────────────────────────────────────────────────

    fun snapStart(bitmapW: Int, bitmapH: Int) {
        log(SNAP, 0) { "=== SNAPSHOT START: bitmap=${bitmapW}×${bitmapH} ===" }
    }

    fun snapStep(step: Int, total: Int, name: String, vararg details: String) {
        val detailStr = if (details.isNotEmpty()) "  ${details.joinToString(" ")}" else ""
        log(SNAP, 0) { "[$step/$total] $name$detailStr" }
    }

    fun snapEnd(imagePath: String, success: Boolean) {
        val status = if (success) "OK" else "FAIL"
        log(SNAP, 0) { "=== SNAPSHOT $status: $imagePath ===" }
    }

    fun snapNoHand() {
        log(SNAP, 1) { "No hand detected — bitmap unchanged" }
    }

    fun snapAttempt(attemptIdx: Int, contrast: Float, brightness: Float, found: Boolean) {
        val result = if (found) "✓ HAND FOUND" else "✗ no hand"
        log(SNAP, 1) { "Attempt[$attemptIdx]: contrast=$contrast bright=$brightness → $result" }
    }

    // ─── Bent finger skip (summary) ─────────────────────────────────────────

    fun bentSkipDetailed(
        fingerName: String,
        foldAngle: Float,
        bentRatio: Float,
        dipDipRatio: Float,
        foldThresh: Float,
        distThresh: Float,
        dipThresh: Float
    ) {
        log(METRICS, 2) {
            "BENT SKIP  finger=$fingerName  " +
            "foldAngle=${String.format("%.1f", foldAngle)}° < ${String.format("%.1f", foldThresh)}°? ${foldAngle < foldThresh}  " +
            "bentRatio=${String.format("%.3f", bentRatio)} < ${String.format("%.3f", distThresh)}? ${bentRatio < distThresh}  " +
            "dipDipRatio=${String.format("%.3f", dipDipRatio)} < ${String.format("%.3f", dipThresh)}? ${dipDipRatio < dipThresh}"
        }
    }
}
