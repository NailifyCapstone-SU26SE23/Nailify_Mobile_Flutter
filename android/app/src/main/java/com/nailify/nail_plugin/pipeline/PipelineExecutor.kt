/*
 * PipelineExecutor.kt — Quản lý AI pipeline (YOLO + MediaPipe State Machine).
 *
 * ═══════════════════════════════════════════════════════════════
 * KIẾN TRÚC: State Machine Tracking (Giải pháp B)
 * ═══════════════════════════════════════════════════════════════
 *
 * VẤN ĐỀ: Pipeline cũ vẫn phải gọi YOLO mỗi ~400ms → render frame chỉ đạt
 * vài FPS và khi tay di chuyển nhanh móng bị giật/lag.
 *
 * GIẢI PHÁP: Tách rõ 2 phase qua NailTrackerStateMachine:
 *
 *   Camera Thread (mỗi frame 30-60Hz):
 *     1. submit(bitmap)
 *     2. → State Machine.update(yoloDetections?, mpJoints, mpTips, frameW, frameH)
 *     3. Nếu phase = TRACKING → State Machine trả về synthetic detections
 *        dựa trên polygon YOLO lưu sẵn + MediaPipe joints hiện tại.
 *     4. Render NGAY với detections từ State Machine (25 FPS).
 *     5. Chỉ submit YOLO khi phase = SEARCHING (lúc mới bắt đầu/mất tay).
 *
 *   AI Thread:
 *     - YOLO chạy NGẦM, chỉ khi state machine yêu cầu (search hit).
 *     - Kết quả YOLO cập nhật anchor constants trong state machine.
 *
 * Tối ưu hiệu năng:
 *   - Mỗi camera frame KHÔNG cần YOLO (chỉ 1-3 frame lúc khởi đầu).
 *   - MediaPipe chạy liên tục (LIVE_STREAM) ~10ms/frame → không phải nút cổ chai.
 *   - Synthetic detections có polygon affine-transform giữ nguyên hình dạng
 *     YOLO gốc + scale theo độ dài ngón tay từ MediaPipe.
 *
 * THREAD SAFETY:
 *   - OrtSession.run() chỉ được gọi trên aiExecutor.
 *   - State Machine update: camera thread (nhẹ, chỉ affine).
 *   - State Machine anchor: aiExecutor (ghi tracks).
 *   - Renderer đọc với snapshot cuối cùng an toàn.
 */
package com.nailify.nail_plugin.pipeline

import android.content.Context
import android.graphics.Bitmap
import android.graphics.PointF
import android.util.Log
import com.nailify.nail_plugin.ai.NailAiEngine
import com.nailify.nail_plugin.ai.NailDetection
import com.nailify.nail_plugin.ai.NailGeometryEngine
import com.nailify.nail_plugin.ai.NailTrackerStateMachine
import com.nailify.nail_plugin.ai.PolygonTracker
import com.nailify.nail_plugin.session.DebugState
import com.nailify.nail_plugin.mediapipe.MediaPipeRunner
import com.nailify.nail_plugin.ai.YoloResultPack
import com.nailify.nail_plugin.util.BitmapPool
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

class PipelineExecutor(
    private val context: Context,
    private val debugProvider: () -> DebugState = { DebugState() },
) {
    companion object {
        private const val TAG = "PipelineExecutor"

        /**
         * FIX #2: Rate-limit YOLO re-anchor. YOLO chạy ~300ms/frame; trong khi đó
         * có thể có ~9 camera frame (30fps) đi qua submit(). Không cần anchor lại
         * mỗi frame; chỉ chạy mỗi 500ms là đủ (2 lần/giây). Giảm tải và tránh race.
         */
        private const val MIN_YOLO_INTERVAL_MS = 500L

        /**
         * Fix #1: Periodic re-scan interval. Mỗi 3s, ép State Machine về SEARCHING
         * để YOLO chạy lại → refresh anchor constants. Tránh móng lệch tích lũy
         * khi tay di chuyển xa so với anchor gốc.
         */
        private const val RE_SCAN_INTERVAL_MS = 3000L

        /**
         * Fix #1: Số frame YOLO chạy liên tục trong 1 burst khi re-scan. 5 frame
         * × ~100ms/frame = ~500ms — đủ để bắt nail ở nhiều góc (1 frame có thể miss
         * khi móng ở góc xấu). Áp dụng cả cho initial SEARCHING.
         */
        private const val YOLO_BURST_FRAMES = 5
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

    /**
     * State machine điều phối tracking:
     *  - SEARCHING: cần YOLO để anchor constants.
     *  - TRACKING: render bằng MediaPipe + polygon YOLO đã lưu.
     *  - LOST: tay vừa biến mất — chờ tay quay lại để SEARCHING.
     */
    private val trackerStateMachine: NailTrackerStateMachine = NailTrackerStateMachine()

    /**
     * PolygonTracker legacy — chỉ dùng cho SEARCHING phase (smoothing YOLO)
     * trước khi đẩy vào state machine. Tracking chính do state machine đảm nhận.
     */
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

    // ── Async State ──────────────────────────────────────────────────────────

    /** Flag: AI thread có đang chạy không. */
    private val isAiRunning = AtomicBoolean(false)

    /**
     * Yêu cầu State Machine SEARCHING — atomic counter để tránh race.
     * Mỗi camera frame có thể trigger increment; AI thread xử lý FIFO.
     * 0 = no pending search; >0 = camera thread muốn YOLO chạy.
     */
    private val searchRequested = AtomicInteger(0)

    /** Frame ID để match YOLO request với bitmap hiện đang submit. */
    private val frameSeq = AtomicInteger(0)

    /**
     * FIX #2 (Rate-limit YOLO): thời điểm submit YOLO gần nhất. Dùng để skip
     * submit nếu chưa đủ MIN_YOLO_INTERVAL_MS kể từ lần trước.
     */
    private var lastYoloSubmitMs: Long = 0L

    /**
     * Fix #1 (Periodic re-scan): thời điểm trigger re-scan gần nhất. Mỗi
     * RE_SCAN_INTERVAL_MS (3s) ép State Machine về SEARCHING để YOLO refresh
     * anchor constants — tránh móng lệch tích lũy.
     */
    private var lastReScanTriggerMs: Long = 0L

    /**
     * Fix #1 (Burst): số frame YOLO còn phải chạy trong burst hiện tại.
     * Khi > 0 → submit YOLO ngay khi YOLO trước xong (không chờ camera frame).
     * Reset về YOLO_BURST_FRAMES mỗi lần trigger re-scan hoặc vào SEARCHING.
     */
    @Volatile private var remainingBurstFrames: Int = YOLO_BURST_FRAMES

    /** Cache kết quả YOLO mới nhất — dùng bởi camera thread cho State Machine. */
    private val cachedYoloDetections: AtomicReference<YoloResultPack?> = AtomicReference(null)

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
    private var lastPhase = NailTrackerStateMachine.Phase.SEARCHING
    private var lastSyntheticCount = 0

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
     * Submit một frame từ Camera (chạy trên cameraExecutor).
     *
     * Flow MỚI (State Machine):
     *  1. Luôn luôn feed MediaPipe với frame hiện tại (LIVE_STREAM rất nhẹ ~10ms).
     *  2. Đọc MediaPipe result (PIP joints + tip positions) ở PIXEL coords.
     *  3. Đưa qua State Machine.update(yoloResults?, mpJoints, mpTips, frameW, frameH).
     *     - Nếu phase = TRACKING → State Machine sinh detections ngay tại đây.
     *     - Nếu phase = SEARCHING → State Machine muốn YOLO → tăng searchRequested.
     *  4. Render ngay với detections từ State Machine.
     *  5. Nếu AI thread rảnh VÀ state machine cần tìm kiếm → submit frame cho AI.
     */
    fun submit(bitmap: Bitmap, rotation: Int, isFront: Boolean, pool: BitmapPool?) {
        val currentSeq = frameSeq.incrementAndGet()
        val frameW = bitmap.width
        val frameH = bitmap.height

        val mediaPipe = ensureMediaPipe()
        // Cập nhật image size cho MediaPipe result callback để convert về pixel.
        if (mediaPipe.lastImageWidth != frameW || mediaPipe.lastImageHeight != frameH) {
            // (Volatile writes are good enough — value types only used by callback.)
            mediaPipe.lastImageWidth = frameW
            mediaPipe.lastImageHeight = frameH
        }
        // Feed MediaPipe ngay (rất nhẹ ~10ms/frame, không phải nút cổ chai).
        // MediaPipeRunner tự tính microseconds strictly-increasing để tránh crash.
        mediaPipe.submitFrame(bitmap)

        // Đợi MediaPipe detect xong (synchronous ~10ms) — đây là điểm then chốt.
        // Ở LIVE_STREAM mode MediaPipe đã có sẵn last result từ các frame trước,
        // ta dùng ngay để duy trì 25 FPS.
        val fingerVectors = mediaPipe.lastFingerVectors
        val tipPositions = mediaPipe.lastTipPositions
        val jointPositions = mediaPipe.lastJointPositions
        val skeleton = mediaPipe.lastSkeletonPoints

        // Đưa qua State Machine.
        val yoloPack = cachedYoloDetections.getAndSet(null) // Consume it so we don't anchor twice!
        val (phase, finalDetections) = trackerStateMachine.update(
            yoloPack = yoloPack,
            fingerVectors = fingerVectors,
            tipPositions = tipPositions,
            jointPositions = jointPositions,
            frameW = frameW,
            frameH = frameH,
        )
        lastPhase = phase
        lastSyntheticCount = finalDetections.size
        lastFingerCount = fingerVectors.size
        lastHandDetected = fingerVectors.isNotEmpty()

        // Render NGAY với detections từ State Machine.
        skeletonProvider?.invoke(skeleton)
        surfaceProvider?.invoke(bitmap, finalDetections)

        // Phát sự kiện stats.
        frameCounter++
        if (frameCounter % 5 == 0) {
            val stats = mapOf(
                "yoloMs" to lastYoloMs,
                "mpMs" to lastMpMs,
                "totalMs" to lastTotalMs,
                "yoloDets" to lastRawDetCount,
                "tracks" to finalDetections.size,
                "hand" to lastHandDetected,
                "fingers" to lastFingerCount,
                "phase" to phase.name,
            )
            eventSink?.invoke(stats)
        }

// Quyết định có cần YOLO không dựa trên phase.
        val needsYolo = phase == NailTrackerStateMachine.Phase.SEARCHING ||
                        phase == NailTrackerStateMachine.Phase.LOST

        // FIX #2 (Rate-limit YOLO): chỉ submit YOLO khi đủ interval. Tránh YOLO
        // chạy mỗi SEARCHING frame (~10 lần/giây), chỉ chạy ~2 lần/giây để giảm
        // tải và hạn chế race condition khi submit liên tục.
        val nowMs = System.currentTimeMillis()
        val yoloIntervalOk = nowMs - lastYoloSubmitMs >= MIN_YOLO_INTERVAL_MS

        // Fix #1 (Periodic re-scan): mỗi RE_SCAN_INTERVAL_MS, ép State Machine
        // về SEARCHING và reset burst counter. Burst chạy 5 frame YOLO liên tục
        // để bắt nail ở nhiều góc (1 frame có thể miss khi móng ở góc xấu).
        val reScanDue = nowMs - lastReScanTriggerMs >= RE_SCAN_INTERVAL_MS
        if (reScanDue) {
            lastReScanTriggerMs = nowMs
            trackerStateMachine.forceReScan()
            remainingBurstFrames = YOLO_BURST_FRAMES
            Log.i(TAG, "forceReScan triggered (interval=${RE_SCAN_INTERVAL_MS}ms, burst=${YOLO_BURST_FRAMES} frames)")
        }

        // Fix #1 (Burst): nếu còn burst frame VÀ đủ YOLO interval → submit
        // ngay (không chờ camera frame). Đảm bảo 5 frame YOLO chạy liên tục
        // mỗi lần trigger.
        val burstActive = remainingBurstFrames > 0
        val shouldRunYolo = (needsYolo || burstActive) && yoloIntervalOk

        if (shouldRunYolo) {
            if (burstActive) remainingBurstFrames--
            lastYoloSubmitMs = nowMs
            searchRequested.incrementAndGet()
        }

        if (shouldRunYolo && isAiRunning.compareAndSet(false, true)) {
            val aiBitmap = bitmap.copy(bitmap.config ?: Bitmap.Config.ARGB_8888, true)
            // Camera frame cũ đã dùng để render — recycle ngay khi an toàn.
            pool?.recycle(bitmap)
            // FIX #1 (Time-Capsule): snapshot MP landmarks tại frame hiện tại để
            // ~300ms sau khi YOLO xong, ta dùng ĐÚNG MP của frame này (không bị
            // ghi đè bởi các frame trung gian). Đây là entry point cho anchor đồng bộ.
            val jointsAtYoloStart = HashMap(mediaPipe.lastJointPositions)
            val tipsAtYoloStart = HashMap(mediaPipe.lastTipPositions)
            val anchorsAtYoloStart = HashMap(mediaPipe.lastAnchorPositions)
            val vectorsAtYoloStart = HashMap(mediaPipe.lastFingerVectors)
            aiExecutor.execute {
                try {
                    runAiPipeline(aiBitmap, rotation, isFront, currentSeq, jointsAtYoloStart, tipsAtYoloStart, anchorsAtYoloStart, vectorsAtYoloStart)
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
        trackerStateMachine.reset()
    }

    // -------------------------------------------------------------------------
    // AI Pipeline (chỉ chạy khi State Machine cần SEARCHING)
    // -------------------------------------------------------------------------

    private fun runAiPipeline(
        bitmap: Bitmap,
        rotation: Int,
        isFront: Boolean,
        frameSeqFor: Int,
        joints: Map<Int, PointF>,
        tips: Map<Int, PointF>,
        anchors: Map<Int, PointF>,
        vectors: Map<Int, PointF>
    ) {
        val t0 = System.currentTimeMillis()
        Log.d(TAG, "runPipeline enter: ${bitmap.width}x${bitmap.height} rot=$rotation frameSeq=$frameSeqFor")

        // 1. YOLO inference (chỉ chạy khi state machine yêu cầu)
        val yoloStart = System.currentTimeMillis()
        val rawDetections = try {
            yoloEngine.run(bitmap)
        } catch (e: Exception) {
            Log.w(TAG, "YOLO inference failed: ${e.message}", e)
            emptyList()
        }
        val yoloMs = System.currentTimeMillis() - yoloStart
        Log.d(TAG, "YOLO dets=${rawDetections.size} in ${yoloMs}ms")

        // FIX #1 (Time-Capsule): dùng joints/tips/vectors từ thời điểm SUBMIT YOLO
        // (parameter truyền vào), KHÔNG dùng mediaPipe.lastXxx (đã bị ghi đè bởi
        // ~3-10 frame trung gian). Đây là fix async-desync bug chính.
        val fingerVectors = vectors
        val tipPositions = tips
        val handDetected = fingerVectors.isNotEmpty()

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

        // FIX #1 (Time-Capsule): build pack với MP đồng bộ với YOLO bbox,
        // anchor TRỰC TIẾP vào StateMachine trên aiExecutor thread (không qua
        // cache + camera-thread anchor với MP sai).
        val pack = YoloResultPack(
            detections = confirmed,
            jointPositions = joints,
            tipPositions = tips,
            anchorPositions = anchors,
            fingerVectors = vectors,
        )
        // Anchor trực tiếp — pack mang MP cùng thời điểm với YOLO frame.
        trackerStateMachine.anchorWithPairedSnapshot(pack, bitmap.width, bitmap.height)

        // Vẫn cache để camera thread frame sau (TRACKING) có data để dùng nếu cần.
        cachedYoloDetections.set(pack)
        cachedSkeleton.set(ensureMediaPipe().lastSkeletonPoints)

        // 4. Lưu stats
        val total = System.currentTimeMillis() - t0
        lastYoloMs = yoloMs
        lastMpMs = 0L  // đã tính trên camera thread
        lastTotalMs = total
        lastRawDetCount = rawDetections.size
        lastHandDetected = handDetected
        lastFingerCount = fingerVectors.size

        // Reset search request (consumed by this run).
        searchRequested.set(0)

        Log.d(TAG, "runPipeline exit: confirmed=${confirmed.size} frameSeq=$frameSeqFor totalMs=$total")
    }

    private fun processDetections(
        raw: List<NailDetection>,
        fingerVectors: Map<Int, PointF>,
        tipPositions: Map<Int, PointF>,
    ): List<NailDetection> {
        if (raw.isEmpty()) return emptyList()

        return raw.map { det ->
            val rawHint = fingerVectors[det.clsId]
            // FIX #5: PCA disambig chỉ cần HƯỚNG (dấu dot), không cần độ lớn.
            // Trước đây scaledHint = rawHint × diag (~800-1500 lần unit vector) gây
            // giá trị khổng lồ không cần thiết; vẫn flip đúng (vì nhân hệ số > 0
            // không đổi dấu) nhưng thừa computation và rủi ro FP. Dùng rawHint thẳng.
            val direction = geometryEngine.getDirectionFromPolygonPca(det.polygon, rawHint, det.clsId)
            val nailBed = geometryEngine.cutPolygonAtRatio(det.polygon, direction, 0.75f)
            val designPath = designPaths[det.clsName]
            det.copy(
                forwardVector = rawHint ?: det.forwardVector,
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
