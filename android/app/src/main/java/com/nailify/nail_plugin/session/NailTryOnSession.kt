package com.nailify.nail_plugin.session

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.SurfaceHolder
import androidx.lifecycle.LifecycleOwner
import com.nailify.nail_plugin.camera.CameraController
import com.nailify.nail_plugin.pipeline.PipelineExecutor
import com.nailify.nail_plugin.render.NailSurfaceRenderer
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.CompletableFuture

/**
 * Quản lý 1 phiên AR Try-On.
 *
 * Sở hữu:
 *  - CameraController: chỉ 1 CameraX ImageAnalysis, xuất bitmap RGBA_8888.
 *  - PipelineExecutor: 1 single-thread executor (để giữ OrtSession.run() thread-safe).
 *  - NailSurfaceRenderer: render lên SurfaceView do Flutter tạo ra.
 *
 * Luồng chính:
 *   CameraController.onImage(bitmap)
 *     -> PipelineExecutor.process(bitmap)
 *          - yoloRun(bitmap) -> List<NailDetection>
 *          - mediapipeRun(bitmap) -> FingerVectors + TipPositions
 *          - polygonTracker.update(detections)
 *          - emitEvent(stats) [post về main thread]
 *     -> NailSurfaceRenderer.render(bitmap, detections) [an toàn trên bg thread]
 */
class NailTryOnSession(
    private val context: Context,
    private val activity: LifecycleOwner,
    val mode: String,
    val config: Map<*, *>,
    private var eventSink: EventChannel.EventSink?,
) {

    companion object {
        private const val TAG = "NailTryOnSession"

        // Frame dimensions
        const val TARGET_WIDTH = 640
        const val TARGET_HEIGHT = 480
    }

    private var camera: CameraController? = null
    private var pipeline: PipelineExecutor? = null
    private var renderer: NailSurfaceRenderer? = null

    private var debugShowSkeleton = true
    private var debugShowBbox = true
    private var debugShowFps = true

    // Main thread Handler để forward EventChannel events (Flutter yêu cầu UiThread).
    private val mainHandler = Handler(Looper.getMainLooper())

    // Lifecycle ----------------------------------------------------------------

    fun start() {
        val designPathsMap = config["designPaths"] as? Map<*, *>
        Log.d(TAG, "designPathsMap received: $designPathsMap")

        val designPaths: Map<String, String?> = if (designPathsMap != null) {
            mapOf(
                "index" to designPathsMap["index"] as? String,
                "middle" to designPathsMap["middle"] as? String,
                "ring" to designPathsMap["ring"] as? String,
                "pinky" to designPathsMap["pinky"] as? String,
                "thumb" to designPathsMap["thumb"] as? String
            )
        } else emptyMap()
        Log.d(TAG, "Parsed designPaths: $designPaths")

        try {
            pipeline = PipelineExecutor(context, debugProvider = { DebugState(debugShowSkeleton, debugShowBbox, debugShowFps) }).also {
                it.designPaths = designPaths
                it.setEventSink { stats -> emitEvent(stats) }
                it.setSurfaceProvider { bitmap, detections -> renderer?.renderFrame(bitmap, detections) }
                it.setSkeletonProvider { skel -> renderer?.currentSkeletonPoints = skel }
            }
            camera = CameraController(context, activity).also {
                it.setAnalyzerExecutor(pipeline!!.cameraExecutor)
                it.onFrame = { bitmap, rotation, isFront, pool -> pipeline!!.submit(bitmap, rotation, isFront, pool) }
                it.onError = { msg -> Log.w(TAG, "Camera error: $msg") }
                it.start()
            }
            Log.i(TAG, "NailTryOnSession started: mode=$mode")
        } catch (t: Throwable) {
            // Phòng trường hợp ONNX init throw (ABI mismatch / emulator thiếu lib),
            // MediaPipe lỗi, hoặc Camera khởi tạo thất bại. Nếu để throw lên
            // NailTryOnPlugin → Main thread → crash app. Thay vào đó emit error
            // event về Dart để UI hiển thị "AR không khả dụng".
            Log.e(TAG, "start() failed: ${t.message}", t)
            cleanup()
            emitError("AR init failed: ${t.message}")
        }
    }

    private fun cleanup() {
        try { camera?.stop() } catch (_: Exception) {}
        try { pipeline?.shutdown() } catch (_: Exception) {}
        try { renderer?.release() } catch (_: Exception) {}
        camera = null
        pipeline = null
        renderer = null
    }

    private fun emitError(message: String) {
        val sink = eventSink ?: return
        mainHandler.post {
            try {
                sink.error("AR_INIT_FAILED", message, null)
            } catch (e: Exception) {
                Log.w(TAG, "emitError sink.error failed: ${e.message}")
            }
        }
    }

    fun stop() {
        try { camera?.stop() } catch (e: Exception) { Log.w(TAG, "camera.stop failed", e) }
        try { pipeline?.shutdown() } catch (e: Exception) { Log.w(TAG, "pipeline.shutdown failed", e) }
        try { renderer?.release() } catch (e: Exception) { Log.w(TAG, "renderer.release failed", e) }
        camera = null
        pipeline = null
        renderer = null
        Log.i(TAG, "NailTryOnSession stopped")
    }

    fun rebindActivity(newActivity: Activity?) {
        // SurfaceView + camera đã được kết nối qua surfaceHolder bên ngoài.
        // Camera provider cần activity để lifecycle bind, nhưng ở skeleton này tạm thời
        // không cần re-bind vì session stop khi activity detach.
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        pipeline?.setEventSink { stats -> emitEvent(stats) }
    }

    fun updateManualOffset(dx: Float, dy: Float, scale: Float, rotation: Float) {
        renderer?.updateManualOffset(dx, dy, scale, rotation)
    }

    fun setDebugFlags(
        showSkeleton: Boolean,
        showBbox: Boolean,
        showFps: Boolean,
        showAnchorCompare: Boolean = false,
        showUBoundary: Boolean = false,
    ) {
        debugShowSkeleton = showSkeleton
        debugShowBbox = showBbox
        debugShowFps = showFps
        pipeline?.setDebugProvider { DebugState(showSkeleton, showBbox, showFps) }
        renderer?.setDebugFlags(showSkeleton, showBbox, showFps, showAnchorCompare, showUBoundary)
    }

    fun captureSnapshot(): CompletableFuture<String?> {
        val future = CompletableFuture<String?>()
        renderer?.captureNextFrame(future)
        return future
    }

    // -------------------------------------------------------------------------

    /** Attach 1 SurfaceView do Flutter dựng ra (gọi từ native side). */
    fun attachSurface(surface: SurfaceHolder) {
        Log.i(TAG, "attachSurface: surface.isValid=${surface.surface?.isValid}, ${surface.surfaceFrame}")
        if (renderer == null) {
            renderer = NailSurfaceRenderer()
            renderer?.setContext(context)
        }
        renderer?.attachHolder(surface)
    }

    fun detachSurface() {
        Log.i(TAG, "detachSurface")
        renderer?.detachHolder()
    }

    /**
     * Emit EventChannel event từ background thread.
     * EventChannel.EventSink.success() yêu cầu @UiThread, nên ta phải
     * post về main thread trước khi gọi — nếu không Flutter sẽ throw
     * "Methods marked with @UiThread must be executed on the main thread".
     */
    private fun emitEvent(stats: Map<String, Any?>) {
        val sink = eventSink ?: return
        mainHandler.post {
            try {
                sink.success(stats)
            } catch (e: Exception) {
                // Event sink có thể đã disposed; nuốt để tránh crash vòng lặp.
                Log.w(TAG, "emitEvent sink.success failed: ${e.message}")
            }
        }
    }
}

/** Cờ debug được query mỗi frame để renderer có thể bật/tắt vẽ tạm. */
data class DebugState(
    val showSkeleton: Boolean = true,
    val showBbox: Boolean = true,
    val showFps: Boolean = true,
)