/*
 * NailSurfaceRenderer.kt — Render frame + bbox/skeleton lên SurfaceView.
 *
 * Render qua lockCanvas/unlockCanvasAndPost (zero copy). Mỗi frame:
 *   1. clear canvas
 *   2. drawBitmap(rawFrame, 0, 0)
 *   3. vẽ YOLO bbox (// DEBUG_BBOX: tạm, xoá sau)
 *   4. vẽ MediaPipe skeleton (// DEBUG_SKELETON: tạm, xoá sau)
 *   5. vẽ FPS overlay nếu bật
 *
 * SurfaceHolder được attach từ NailSurfaceView (Flutter side).
 */
package com.nailify.nail_plugin.render

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PointF
import android.graphics.PorterDuff
import android.os.SystemClock
import android.util.Log
import android.view.SurfaceHolder
import com.nailify.nail_plugin.ai.NailDetection
import java.util.concurrent.CompletableFuture
import java.util.concurrent.atomic.AtomicReference

class NailSurfaceRenderer {
    companion object {
        private const val TAG = "NailSurfaceRenderer"

        // MediaPipe hand skeleton connections (pairs of landmark indices).
        // 21-landmark model: https://google.github.io/mediapipe/solutions/hands.html
        private val HAND_CONNECTIONS: Array<IntArray> = arrayOf(
            // Thumb
            intArrayOf(0, 1), intArrayOf(1, 2), intArrayOf(2, 3), intArrayOf(3, 4),
            // Index
            intArrayOf(0, 5), intArrayOf(5, 6), intArrayOf(6, 7), intArrayOf(7, 8),
            // Middle
            intArrayOf(0, 9), intArrayOf(9, 10), intArrayOf(10, 11), intArrayOf(11, 12),
            // Ring
            intArrayOf(0, 13), intArrayOf(13, 14), intArrayOf(14, 15), intArrayOf(15, 16),
            // Pinky
            intArrayOf(0, 17), intArrayOf(17, 18), intArrayOf(18, 19), intArrayOf(19, 20),
        )
    }

    internal var surfaceHolder: SurfaceHolder? = null
        private set
    private var lastSnapshotRequest: AtomicReference<CompletableFuture<String?>?> = AtomicReference(null)

    // DEBUG: cờ bật/tắt vẽ
    private var debugShowSkeleton = true
    private var debugShowBbox = true
    private var debugShowFps = true

    // Manual offset (Flutter gửi qua MethodChannel).
    private var offsetX = 0f
    private var offsetY = 0f
    private var scaleMul = 1f
    private var rotationDeg = 0f

    // FPS counter
    private var fpsLastMs = SystemClock.uptimeMillis()
    private var fpsFrames = 0
    private var fpsValue = 0f

    // Paint objects (khởi tạo 1 lần, tránh allocate mỗi frame).
    private val framePaint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
    private val bboxPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 3f
        color = Color.CYAN
    }
    private val labelBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.argb(180, 0, 0, 0)
    }
    private val labelTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 24f
    }
    private val skeletonLinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 3f
        color = Color.GREEN
    }
    private val skeletonPointPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.YELLOW
    }
    private val fpsPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 32f
        setShadowLayer(2f, 0f, 0f, Color.BLACK)
    }

    // -------------------------------------------------------------------------

    fun attachHolder(holder: SurfaceHolder) {
        Log.i(TAG, "attachHolder: surface.isValid=${holder.surface?.isValid}, ${holder.surfaceFrame}")
        surfaceHolder = holder
    }

    fun detachHolder() {
        Log.i(TAG, "detachHolder")
        surfaceHolder = null
    }

    fun setDebugFlags(showSkeleton: Boolean, showBbox: Boolean, showFps: Boolean) {
        debugShowSkeleton = showSkeleton
        debugShowBbox = showBbox
        debugShowFps = showFps
    }

    fun updateManualOffset(dx: Float, dy: Float, scale: Float, rotation: Float) {
        offsetX = dx
        offsetY = dy
        scaleMul = scale
        rotationDeg = rotation
    }

    fun captureNextFrame(future: CompletableFuture<String?>) {
        lastSnapshotRequest.set(future)
    }

    fun release() {
        detachHolder()
    }

    // -------------------------------------------------------------------------

    private var frameSkipLog = 0

    /**
     * Render 1 frame. Được gọi từ PipelineExecutor (background thread, không phải main).
     * @param bitmap    RGBA_8888 raw frame (chưa xoay theo orientation).
     * @param detections  List các NailDetection đã tracker xác nhận.
     */
    fun renderFrame(bitmap: Bitmap, detections: List<NailDetection>) {
        val holder = surfaceHolder
        if (holder == null) {
            // Log lần đầu và mỗi 60 frame để không spam
            frameSkipLog++
            if (frameSkipLog == 1 || frameSkipLog % 60 == 0) {
                Log.w(TAG, "renderFrame SKIP: surfaceHolder=null (frame=$frameSkipLog)")
            }
            return
        }
        val canvas: Canvas = try {
            holder.lockCanvas()
        } catch (e: Exception) {
            Log.w(TAG, "lockCanvas failed: ${e.message}")
            return
        } ?: run {
            Log.w(TAG, "lockCanvas returned null (surface.isValid=${holder.surface?.isValid})")
            return
        }

        try {
            // 1. Vẽ frame gốc full screen.
            val dstW = canvas.width
            val dstH = canvas.height
            canvas.drawColor(Color.BLACK, PorterDuff.Mode.SRC)
            canvas.drawBitmap(bitmap, null, android.graphics.RectF(0f, 0f, dstW.toFloat(), dstH.toFloat()), framePaint)

            // Scale ratio từ bitmap -> canvas (giữ aspect ratio đơn giản).
            val scaleX = dstW.toFloat() / bitmap.width
            val scaleY = dstH.toFloat() / bitmap.height

            // 2. DEBUG_BBOX: vẽ YOLO bbox.
            if (debugShowBbox) {
                for (d in detections) {
                    val cx = d.bboxCx * scaleX
                    val cy = d.bboxCy * scaleY
                    val w  = d.bboxW  * scaleX
                    val h  = d.bboxH  * scaleY
                    canvas.drawRect(cx - w / 2f, cy - h / 2f, cx + w / 2f, cy + h / 2f, bboxPaint)
                    val label = "${d.clsName} ${(d.confidence * 100).toInt()}%"
                    canvas.drawRect(cx - w / 2f, cy - h / 2f - 32f, cx - w / 2f + 200f, cy - h / 2f, labelBgPaint)
                    canvas.drawText(label, cx - w / 2f + 6f, cy - h / 2f - 8f, labelTextPaint)
                }
            }

            // 3. DEBUG_SKELETON: vẽ MediaPipe skeleton.
            if (debugShowSkeleton) {
                val skel = currentSkeletonPoints
                if (skel != null) {
                    val pts = ArrayList<PointF>(skel.size)
                    for (p in skel) {
                        pts.add(PointF(p[0] * scaleX, p[1] * scaleY))
                    }
                    for (c in HAND_CONNECTIONS) {
                        val a = pts.getOrNull(c[0]) ?: continue
                        val b = pts.getOrNull(c[1]) ?: continue
                        canvas.drawLine(a.x, a.y, b.x, b.y, skeletonLinePaint)
                    }
                    for (p in pts) {
                        canvas.drawCircle(p.x, p.y, 5f, skeletonPointPaint)
                    }
                }
            }

            // 4. DEBUG_FPS: vẽ FPS overlay.
            if (debugShowFps) {
                updateFps()
                val txt = "FPS ${"%.1f".format(fpsValue)} | det=${detections.size}"
                canvas.drawText(txt, 16f, 48f, fpsPaint)
            }

            // 5. Snapshot capture.
            val snap = lastSnapshotRequest.getAndSet(null)
            if (snap != null) {
                val w = canvas.width
                val h = canvas.height
                val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                val snapCanvas = Canvas(bmp)
                snapCanvas.drawColor(Color.BLACK, PorterDuff.Mode.SRC)
                snapCanvas.drawBitmap(bitmap, null, android.graphics.RectF(0f, 0f, w.toFloat(), h.toFloat()), framePaint)
                val path = saveSnapshot(bmp)
                snap.complete(path)
                bmp.recycle()
            }
        } finally {
            try { holder.unlockCanvasAndPost(canvas) } catch (e: Exception) { Log.w(TAG, "unlockCanvasAndPost failed", e) }
        }
    }

    private fun updateFps() {
        fpsFrames++
        val now = SystemClock.uptimeMillis()
        val dt = now - fpsLastMs
        if (dt >= 1000) {
            fpsValue = fpsFrames * 1000f / dt
            fpsFrames = 0
            fpsLastMs = now
        }
    }

    private fun saveSnapshot(bitmap: Bitmap): String? {
        return try {
            val dir = context().cacheDir
            val file = java.io.File(dir, "nail_snapshot_${System.currentTimeMillis()}.jpg")
            java.io.FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
            }
            file.absolutePath
        } catch (e: Exception) {
            Log.w(TAG, "saveSnapshot failed: ${e.message}", e)
            null
        }
    }

    private fun context(): android.content.Context {
        val app = surfaceHolder?.surface?.let { null }
        return surfaceHolder?.surface?.let { _ ->
            HolderRef.appContext ?: throw IllegalStateException("appContext not initialized")
        } ?: throw IllegalStateException("appContext not initialized")
    }

    // Skeleton points global (được MediaPipeRunner update mỗi frame).
    @Volatile var currentSkeletonPoints: Array<FloatArray>? = null

    internal object HolderRef {
        var appContext: android.content.Context? = null
    }
}