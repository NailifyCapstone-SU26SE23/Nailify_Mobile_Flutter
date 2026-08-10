/*
 * PipelineExecutor.kt — Quản lý AI pipeline (YOLO + MediaPipe).
 *
 * QUAN TRỌNG: OrtSession.run() KHÔNG thread-safe với multi-thread executor.
 * Fix bug crash libonnxruntime.so: serialize tất cả AI work trên 1
 * single-thread executor duy nhất.
 *
 * Pipeline:
 *   submit(bitmap, rotation, isFront)
 *     -> cameraExecutor.execute { yoloRun(bitmap) + mediapipeRun(bitmap) }
 *     -> aiExecutor.execute { polygonTracker.update + emit stats }
 *     -> surfaceProvider(bitmap, detections)
 *
 * Vì YOLO và MediaPipe đều gọi native code có thể không thread-safe với nhau,
 * chúng phải chạy tuần tự trên cùng 1 thread (không parallel).
 */
package com.nailify.nail_plugin.pipeline

import android.content.Context
import android.graphics.Bitmap
import android.graphics.PointF
import android.util.Log
import com.nailify.nail_plugin.ai.NailAiEngine
import com.nailify.nail_plugin.ai.NailDetection
import com.nailify.nail_plugin.ai.NailGeometryEngine
import com.nailify.nail_plugin.ai.PolygonTracker
import com.nailify.nail_plugin.session.DebugState
import com.nailify.nail_plugin.mediapipe.MediaPipeRunner
import java.util.concurrent.Executor
import java.util.concurrent.Executors

class PipelineExecutor(
    private val context: Context,
    private val debugProvider: () -> DebugState = { DebugState() },
) {
    companion object {
        private const val TAG = "PipelineExecutor"

        // Match NailTryOnSession.TARGET_*
        private const val INPUT_W = 640
        private const val INPUT_H = 480
    }

    /** CameraX ImageAnalysis executor — dùng cho frame submission. */
    val cameraExecutor: Executor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "Nail-Camera").apply { isDaemon = true }
    }

    /** AI executor — DUY NHẤT 1 thread, đảm bảo OrtSession.run() thread-safe. */
    private val aiExecutor: Executor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "Nail-AI").apply { isDaemon = true }
    }

    // Engines
    private val yoloEngine: NailAiEngine = NailAiEngine(context)
    private var mediaPipeRunner: MediaPipeRunner? = null
    private val geometryEngine: NailGeometryEngine = NailGeometryEngine
    private val polygonTracker: PolygonTracker = PolygonTracker(
        alpha = 0.5f,
        distThreshold = 150f,
        minConfirmFrames = 1,
        hysteresisFrames = 8,
        reattachDistMultiplier = 1.5f,
    )

    private var eventSink: ((Map<String, Any?>) -> Unit)? = null
    private var surfaceProvider: ((Bitmap, List<NailDetection>) -> Unit)? = null
    private var skeletonProvider: ((Array<FloatArray>?) -> Unit)? = null
    private var debugState: DebugState = debugProvider()

    // Design asset paths per finger class (key = clsName, value = absolute file path)
    var designPaths: Map<String, String?> = emptyMap()

    // Stats cho emit EventChannel (chỉ push mỗi 5 frame để tránh spam)
    private var frameCounter = 0

    // -------------------------------------------------------------------------
    // Setup
    // -------------------------------------------------------------------------

    fun setEventSink(sink: (Map<String, Any?>) -> Unit) {
        eventSink = sink
    }

    fun setSurfaceProvider(provider: (Bitmap, List<NailDetection>) -> Unit) {
        surfaceProvider = provider
    }

    fun setSkeletonProvider(provider: (Array<FloatArray>?) -> Unit) {
        skeletonProvider = provider
    }

    fun setDebugProvider(provider: () -> DebugState) {
        debugState = provider()
    }

    fun submit(bitmap: Bitmap, rotation: Int, isFront: Boolean) {
        // Nhận frame trên cameraExecutor -> chuyển sang aiExecutor để chạy AI tuần tự.
        cameraExecutor.execute {
            try {
                aiExecutor.execute {
                    try {
                        runPipeline(bitmap, rotation, isFront)
                    } catch (e: Exception) {
                        Log.w(TAG, "AI pipeline failed: ${e.message}", e)
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "submit dispatch failed: ${e.message}", e)
            }
        }
    }

    fun shutdown() {
        try { mediaPipeRunner?.close() } catch (_: Exception) {}
        try { yoloEngine.close() } catch (_: Exception) {}
        mediaPipeRunner = null
    }

    // -------------------------------------------------------------------------
    // Pipeline
    // -------------------------------------------------------------------------

    private fun runPipeline(bitmap: Bitmap, rotation: Int, isFront: Boolean) {
        val t0 = System.currentTimeMillis()
        Log.d(TAG, "runPipeline enter: ${bitmap.width}x${bitmap.height} rot=$rotation")

        // 1. YOLO inference.
        val yoloStart = System.currentTimeMillis()
        val rawDetections = try {
            yoloEngine.run(bitmap)
        } catch (e: Exception) {
            Log.w(TAG, "YOLO inference failed: ${e.message}", e)
            emptyList()
        }
        val yoloMs = System.currentTimeMillis() - yoloStart
        Log.d(TAG, "YOLO dets=${rawDetections.size} in ${yoloMs}ms")

        // 2. MediaPipe Hand Landmarker.
        val mpStart = System.currentTimeMillis()
        val mediaPipe = ensureMediaPipe()
        val fingerVectors = mediaPipe.lastFingerVectors
        val tipPositions = mediaPipe.lastTipPositions
        val handDetected = fingerVectors.isNotEmpty()
        mediaPipe.submitFrame(bitmap, System.currentTimeMillis())
        // Push skeleton lên renderer ngay sau frame để vẽ debug skeleton đồng bộ
        skeletonProvider?.invoke(mediaPipe.lastSkeletonPoints)
        val mpMs = System.currentTimeMillis() - mpStart

        // 3. Geometry + tracker.
        val geoStart = System.currentTimeMillis()
        val processed = processDetections(rawDetections, fingerVectors, tipPositions)

        // --- PCA Cluster Regularization (Chống xòe quạt) ---
        // Port từ Desktop test_models.py: kéo hướng từng móng về hướng trung bình của cả bàn tay.
        // Chỉ áp dụng cho những móng KHÔNG có MediaPipe vector (tức là đang dùng PCA Fallback).
        val pcaNails = processed.filter { it.forwardVector == null }
        if (pcaNails.size >= 2) {
            var sumDx = 0f; var sumDy = 0f
            for (d in pcaNails) { val dir = d.pcaDirection ?: continue; sumDx += dir.x; sumDy += dir.y }
            val avgMag = kotlin.math.sqrt(sumDx * sumDx + sumDy * sumDy)
            if (avgMag > 1e-9f) {
                val avgDx = sumDx / avgMag; val avgDy = sumDy / avgMag
                for (d in pcaNails) {
                    val cur = d.pcaDirection ?: continue
                    val bx = cur.x * 0.5f + avgDx * 0.5f
                    val by = cur.y * 0.5f + avgDy * 0.5f
                    val bm = kotlin.math.sqrt(bx * bx + by * by)
                    if (bm > 1e-9f) d.pcaDirection = PointF(bx / bm, by / bm)
                }
            }
        }

        val confirmed = polygonTracker.update(processed)
        val geoMs = System.currentTimeMillis() - geoStart

        // 4. Render qua surface (ngoài main thread, OK).
        surfaceProvider?.invoke(bitmap, confirmed)

        // 5. Emit stats mỗi 5 frame.
        frameCounter++
        if (frameCounter % 5 == 0) {
            val total = System.currentTimeMillis() - t0
            eventSink?.invoke(
                mapOf(
                    "yolo.detections"     to rawDetections.size,
                    "yolo.inferenceMs"    to yoloMs,
                    "mediapipe.hand"      to handDetected,
                    "mediapipe.fingers"   to fingerVectors.size,
                    "mediapipe.ms"        to mpMs,
                    "tracker.confirmed"   to confirmed.size,
                    "frame.size"          to "${bitmap.width}x${bitmap.height}",
                    "total.ms"            to total,
                    "debug.skeleton"      to mediaPipe.lastSkeletonPoints,
                )
            )
        }
    }

    private fun processDetections(
        raw: List<NailDetection>,
        fingerVectors: Map<Int, PointF>,
        tipPositions: Map<Int, PointF>,
    ): List<NailDetection> {
        if (raw.isEmpty()) return emptyList()
        // Lấy frame size để scale MediaPipe vectors (normalized) sang pixel space.
        val frameW = tipPositions.values.maxOfOrNull { it.x }?.coerceAtLeast(1f) ?: 640f
        val frameH = tipPositions.values.maxOfOrNull { it.y }?.coerceAtLeast(1f) ?: 480f
        val diag = kotlin.math.sqrt(frameW * frameW + frameH * frameH).coerceAtLeast(1f)

        return raw.map { det ->
            val rawHint = fingerVectors[det.clsId]
            val scaledHint = rawHint?.let { PointF(it.x * diag, it.y * diag) }
            val direction = geometryEngine.getDirectionFromPolygonPca(det.polygon, scaledHint, det.clsId)
            val nailBed = geometryEngine.cutPolygonAtRatio(det.polygon, direction, 0.75f)
            // Gắn đường dẫn texture móng nếu có trong config
            val designPath = designPaths[det.clsName]
            det.copy(
                forwardVector = scaledHint ?: det.forwardVector,
                pcaDirection = direction,
                nailBedPolygon = if (nailBed.size >= 3) nailBed else det.polygon,
                designAssetPath = designPath,
            )
        }
    }

    private fun ensureMediaPipe(): MediaPipeRunner {
        if (mediaPipeRunner == null) {
            mediaPipeRunner = MediaPipeRunner(context)
        }
        return mediaPipeRunner!!
    }
}