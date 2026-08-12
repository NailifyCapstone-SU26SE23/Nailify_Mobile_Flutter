/*
 * PipelineExecutor.kt — Quản lý AI pipeline (YOLO + MediaPipe).
 *
 * ═══════════════════════════════════════════════════════════════
 * KIẾN TRÚC MỚI: Async Dual-Thread (Phase 1 FPS Optimization)
 * ═══════════════════════════════════════════════════════════════
 *
 * VẤN ĐỀ CŨ: Pipeline đồng bộ — Render PHẢI CHỜ YOLO ~1200ms mới
 * vẽ được frame → chỉ 0.2 FPS.
 *
 * GIẢI PHÁP: Tách render khỏi AI inference:
 *
 *   Camera Thread:  Frame1 → Frame2 → Frame3 → Frame4 → ...  (liên tục)
 *                     ↓ immediate render với detection cũ
 *   Render Thread:  Draw1 → Draw2 → Draw3 → Draw4  (15-25 FPS)
 *                     ↓ khi AI idle, submit frame mới
 *   AI Thread:    [YOLO+MP Frame1 ~400ms] → [YOLO+MP Frame3 ~400ms]
 *                         ↓ cập nhật cached detections
 *                   detection cache → overlay frame tiếp theo
 *
 * Cơ chế: AtomicBoolean `isAiRunning` đảm bảo không submit frame mới
 * khi AI thread đang bận, tránh queue build-up và memory leak.
 *
 * THREAD SAFETY:
 *   - OrtSession.run() chỉ được gọi trên aiExecutor (1 thread)
 *   - cachedDetections: AtomicReference — safe multi-thread access
 *   - Renderer gọi từ cameraExecutor với detection snapshot — safe
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
import com.nailify.nail_plugin.util.BitmapPool
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

class PipelineExecutor(
    private val context: Context,
    private val debugProvider: () -> DebugState = { DebugState() },
) {
    companion object {
        private const val TAG = "PipelineExecutor"
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

    var designPaths: Map<String, String?> = emptyMap()

    // ── Async Dual-Thread State ──────────────────────────────────────────────

    /** Flag: AI thread có đang chạy không — tránh queue overflow. */
    private val isAiRunning = AtomicBoolean(false)

    /** Cache kết quả AI mới nhất — Renderer đọc bất kỳ lúc nào. */
    private val cachedDetections: AtomicReference<List<NailDetection>> =
        AtomicReference(emptyList())

    /** Cache skeleton mới nhất từ MediaPipe. */
    private val cachedSkeleton: AtomicReference<Array<FloatArray>?> =
        AtomicReference(null)

    // Stats
    private var frameCounter = 0
    private var lastYoloMs = 0L
    private var lastMpMs = 0L
    private var lastTotalMs = 0L
    private var lastRawDetCount = 0
    private var lastHandDetected = false
    private var lastFingerCount = 0

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

    /**
     * Submit một frame từ Camera.
     *
     * Flow MỚI (Async):
     * 1. Render NGAY frame này + detection cache cũ (không chờ AI)
     * 2. Nếu AI thread đang rảnh (isAiRunning=false), submit frame cho AI
     * 3. AI xử lý xong → cập nhật cachedDetections → frame tiếp theo sẽ dùng
     *
     * Kết quả: Camera preview chạy ~15-25fps, AI overlay delay 1-2 giây.
     */
    fun submit(bitmap: Bitmap, rotation: Int, isFront: Boolean, pool: BitmapPool?) {
        // ── Bước 1: Render NGAY với detection cũ (15-25 FPS) ──
        val currentDetections = cachedDetections.get()
        val currentSkeleton = cachedSkeleton.get()
        skeletonProvider?.invoke(currentSkeleton)
        surfaceProvider?.invoke(bitmap, currentDetections)

        // Phát sự kiện stats
        frameCounter++
        if (frameCounter % 5 == 0) {
            val stats = mapOf(
                "yoloMs" to lastYoloMs,
                "mpMs" to lastMpMs,
                "totalMs" to lastTotalMs,
                "yoloDets" to lastRawDetCount,
                "tracks" to cachedDetections.get().size,
                "hand" to lastHandDetected,
                "fingers" to lastFingerCount,
                // KHÔNG gửi array nhiều chiều qua event channel
            )
            eventSink?.invoke(stats)
        }

        // ── Bước 2: AI (Background) ──
        if (isAiRunning.compareAndSet(false, true)) {
            val aiBitmap = bitmap.copy(bitmap.config ?: Bitmap.Config.ARGB_8888, true)
            pool?.recycle(bitmap)
            aiExecutor.execute {
                try {
                    runAiPipeline(aiBitmap, rotation, isFront)
                } catch (e: Exception) {
                    Log.w(TAG, "AI pipeline failed: ${e.message}", e)
                } finally {
                    aiBitmap.recycle()
                    isAiRunning.set(false)
                }
            }
        } else {
            pool?.recycle(bitmap)
        }
    }

    fun shutdown() {
        try { mediaPipeRunner?.close() } catch (_: Exception) {}
        try { yoloEngine.close() } catch (_: Exception) {}
        mediaPipeRunner = null
    }

    // -------------------------------------------------------------------------
    // AI Pipeline (chạy trên aiExecutor, 1 thread)
    // -------------------------------------------------------------------------

    private fun runAiPipeline(bitmap: Bitmap, rotation: Int, isFront: Boolean) {
        val t0 = System.currentTimeMillis()
        Log.d(TAG, "runPipeline enter: ${bitmap.width}x${bitmap.height} rot=$rotation")

        // 1. YOLO inference (320x320 — ~400ms trên emulator, ~80ms trên thiết bị)
        val yoloStart = System.currentTimeMillis()
        val rawDetections = try {
            yoloEngine.run(bitmap)
        } catch (e: Exception) {
            Log.w(TAG, "YOLO inference failed: ${e.message}", e)
            emptyList()
        }
        val yoloMs = System.currentTimeMillis() - yoloStart
        Log.d(TAG, "YOLO dets=${rawDetections.size} in ${yoloMs}ms")

        // 2. MediaPipe Hand Landmarker (async bên trong, lấy kết quả frame trước)
        val mpStart = System.currentTimeMillis()
        val mediaPipe = ensureMediaPipe()
        val fingerVectors = mediaPipe.lastFingerVectors
        val tipPositions = mediaPipe.lastTipPositions
        val handDetected = fingerVectors.isNotEmpty()
        mediaPipe.submitFrame(bitmap, System.currentTimeMillis())
        val mpMs = System.currentTimeMillis() - mpStart

        // 3. Geometry + PCA Cluster Regularization + tracker
        val processed = processDetections(rawDetections, fingerVectors, tipPositions)

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

        // 4. Cập nhật cache — Render thread sẽ dùng ở frame tiếp theo
        cachedDetections.set(confirmed)
        cachedSkeleton.set(mediaPipe.lastSkeletonPoints)

        // 5. Lưu stats
        val total = System.currentTimeMillis() - t0
        lastYoloMs = yoloMs
        lastMpMs = mpMs
        lastTotalMs = total
        lastRawDetCount = rawDetections.size
        lastHandDetected = handDetected
        lastFingerCount = fingerVectors.size
    }

    private fun processDetections(
        raw: List<NailDetection>,
        fingerVectors: Map<Int, PointF>,
        tipPositions: Map<Int, PointF>,
    ): List<NailDetection> {
        if (raw.isEmpty()) return emptyList()
        val frameW = tipPositions.values.maxOfOrNull { it.x }?.coerceAtLeast(1f) ?: 640f
        val frameH = tipPositions.values.maxOfOrNull { it.y }?.coerceAtLeast(1f) ?: 480f
        val diag = kotlin.math.sqrt(frameW * frameW + frameH * frameH).coerceAtLeast(1f)

        return raw.map { det ->
            val rawHint = fingerVectors[det.clsId]
            val scaledHint = rawHint?.let { PointF(it.x * diag, it.y * diag) }
            val direction = geometryEngine.getDirectionFromPolygonPca(det.polygon, scaledHint, det.clsId)
            val nailBed = geometryEngine.cutPolygonAtRatio(det.polygon, direction, 0.75f)
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

