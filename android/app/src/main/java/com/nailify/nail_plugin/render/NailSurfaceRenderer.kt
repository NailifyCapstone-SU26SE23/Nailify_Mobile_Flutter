/*
 * NailSurfaceRenderer.kt — Render frame + AR nail overlay + debug skeleton.
 *
 * Pipeline render mỗi frame (gọi từ PipelineExecutor, background thread):
 *   1. drawBitmap(rawFrame) — vẽ full-screen camera frame.
 *   2. [AR Overlay] Với mỗi NailDetection đã confirm:
 *      a. Vẽ đường viền Polygon (nailBedPolygon) màu trắng bán trong suốt.
 *      b. Nếu có designBitmap: Ốp ảnh texture lên vùng nailBedPolygon,
 *         xoay theo pcaDirection (hoặc forwardVector nếu MP đang hoạt động).
 *         Dùng canvas.clipPath + Matrix để warpAffine như bản Desktop.
 *   3. [DEBUG_SKELETON] Vẽ 21-point hand skeleton của MediaPipe (nếu bật).
 *   4. [DEBUG_BBOX]     Vẽ bbox + label YOLO cho từng detection (nếu bật).
 *   5. [DEBUG_FPS]      FPS overlay.
 */
package com.nailify.nail_plugin.render

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.os.SystemClock
import android.util.Log
import android.view.SurfaceHolder
import com.nailify.nail_plugin.ai.NailDetection
import java.io.File
import java.util.concurrent.CompletableFuture
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

class NailSurfaceRenderer {
    companion object {
        private const val TAG = "NailSurfaceRenderer"

        // MediaPipe hand skeleton connections (pairs of landmark indices).
        private val HAND_CONNECTIONS: Array<IntArray> = arrayOf(
            intArrayOf(0, 1), intArrayOf(1, 2), intArrayOf(2, 3), intArrayOf(3, 4),
            intArrayOf(0, 5), intArrayOf(5, 6), intArrayOf(6, 7), intArrayOf(7, 8),
            intArrayOf(0, 9), intArrayOf(9, 10), intArrayOf(10, 11), intArrayOf(11, 12),
            intArrayOf(0, 13), intArrayOf(13, 14), intArrayOf(14, 15), intArrayOf(15, 16),
            intArrayOf(0, 17), intArrayOf(17, 18), intArrayOf(18, 19), intArrayOf(19, 20),
        )

        // Màu theo class (giống Desktop overlay.py)
        private val CLASS_COLORS: Map<String, Int> = mapOf(
            "index"  to Color.rgb(100, 220, 255),
            "middle" to Color.rgb(255, 180,  80),
            "ring"   to Color.rgb( 80, 255, 180),
            "pinky"  to Color.rgb(200, 100, 255),
            "thumb"  to Color.rgb(255, 255, 100),
        )
    }

    internal var surfaceHolder: SurfaceHolder? = null
        private set
    private var lastSnapshotRequest: AtomicReference<CompletableFuture<String?>?> = AtomicReference(null)

    // Debug flags
    private var debugShowSkeleton = true
    private var debugShowBbox     = true
    private var debugShowFps      = true

    // Manual offset (Flutter MethodChannel sliders)
    private var offsetX    = 0f
    private var offsetY    = 0f
    private var scaleMul   = 1f
    private var rotationDeg = 0f

    // FPS counter
    private var fpsLastMs  = SystemClock.uptimeMillis()
    private var fpsFrames  = 0
    private var fpsValue   = 0f

    // Design texture cache (key = absolute file path, value = loaded Bitmap)
    private val designCache = mutableMapOf<String, Bitmap?>()

    // Context ref (cần để load file từ disk)
    @Volatile private var appContext: Context? = null
    
    // Skeleton points (được MediaPipeRunner update từ background thread)
    @Volatile var currentSkeletonPoints: Array<FloatArray>? = null

    // ── Paint objects ──────────────────────────────────────────────────────────

    private val framePaint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)

    private val polygonPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 2.5f
        color = Color.WHITE
        alpha = 200
    }

    private val polygonFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.argb(40, 255, 255, 255)  // Nền bán trong suốt
    }

    private val overlayPaint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG).apply {
        alpha = 220  // 86% opacity cho nail overlay
    }

    private val bboxPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 2f
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
        strokeWidth = 6f
        color = Color.GREEN
        alpha = 255
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

    private var frameSkipLog = 0

    // ── Lifecycle ──────────────────────────────────────────────────────────────

    fun attachHolder(holder: SurfaceHolder) {
        Log.i(TAG, "attachHolder: surface.isValid=${holder.surface?.isValid}, ${holder.surfaceFrame}")
        surfaceHolder = holder
    }

    fun detachHolder() {
        Log.i(TAG, "detachHolder")
        surfaceHolder = null
    }

    fun setContext(ctx: Context) {
        appContext = ctx.applicationContext
    }

    fun setDebugFlags(showSkeleton: Boolean, showBbox: Boolean, showFps: Boolean) {
        debugShowSkeleton = showSkeleton
        debugShowBbox     = showBbox
        debugShowFps      = showFps
    }

    fun updateManualOffset(dx: Float, dy: Float, scale: Float, rotation: Float) {
        offsetX     = dx
        offsetY     = dy
        scaleMul    = scale
        rotationDeg = rotation
    }

    fun captureNextFrame(future: CompletableFuture<String?>) {
        lastSnapshotRequest.set(future)
    }

    fun release() {
        detachHolder()
        designCache.values.forEach { it?.recycle() }
        designCache.clear()
        appContext = null
    }

    // ── Main render ────────────────────────────────────────────────────────────

    /**
     * Render 1 frame (gọi từ PipelineExecutor, background thread).
     * @param bitmap     RGBA_8888 raw camera frame.
     * @param detections  List NailDetection đã tracker xác nhận.
     */
    fun renderFrame(bitmap: Bitmap, detections: List<NailDetection>) {
        val holder = surfaceHolder
        if (holder == null) {
            frameSkipLog++
            if (frameSkipLog == 1 || frameSkipLog % 60 == 0) {
                Log.w(TAG, "renderFrame SKIP: surfaceHolder=null (frame=$frameSkipLog)")
            }
            return
        }
        val canvas: Canvas = try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                holder.lockHardwareCanvas()
            } else {
                holder.lockCanvas()
            }
        } catch (e: Exception) {
            Log.w(TAG, "lockCanvas failed: ${e.message}")
            return
        } ?: run {
            Log.w(TAG, "lockCanvas returned null (surface.isValid=${holder.surface?.isValid})")
            return
        }

        try {
            val dstW = canvas.width.toFloat()
            val dstH = canvas.height.toFloat()
            val bmpW = bitmap.width.toFloat()
            val bmpH = bitmap.height.toFloat()

            // Letterbox scale: giữ aspect ratio giống Desktop (không stretch)
            val scaleToFit = min(dstW / bmpW, dstH / bmpH)
            val fitW = bmpW * scaleToFit
            val fitH = bmpH * scaleToFit
            val padLeft = (dstW - fitW) / 2f
            val padTop  = (dstH - fitH) / 2f
            val scaleX = scaleToFit
            val scaleY = scaleToFit

            // 1. Clear + vẽ frame gốc (letterbox)
            canvas.drawColor(Color.BLACK, PorterDuff.Mode.SRC)
            canvas.drawBitmap(bitmap,
                null,
                android.graphics.RectF(padLeft, padTop, padLeft + fitW, padTop + fitH),
                framePaint)

            // 2. AR Overlay: vẽ Polygon + ốp ảnh móng ảo
            for (det in detections) {
                drawNailOverlay(canvas, det, scaleX, scaleY, padLeft, padTop)
            }

            // 3. DEBUG: MediaPipe skeleton
            if (debugShowSkeleton) drawSkeleton(canvas, scaleX, scaleY, padLeft, padTop)

            // 4. DEBUG: YOLO BBox
            if (debugShowBbox) drawBboxes(canvas, detections, scaleX, scaleY, padLeft, padTop)

            // 5. FPS
            if (debugShowFps) {
                updateFps()
                canvas.drawText(
                    "FPS ${"%.1f".format(fpsValue)} | det=${detections.size}",
                    16f, 48f, fpsPaint)
            }

            // 6. Snapshot capture
            val snap = lastSnapshotRequest.getAndSet(null)
            if (snap != null) {
                val snapshotBmp = Bitmap.createBitmap(canvas.width, canvas.height, Bitmap.Config.ARGB_8888)
                val snpCanvas = Canvas(snapshotBmp)
                snpCanvas.drawColor(Color.BLACK, PorterDuff.Mode.SRC)
                snpCanvas.drawBitmap(bitmap,
                    null,
                    android.graphics.RectF(padLeft, padTop, padLeft + fitW, padTop + fitH),
                    framePaint)
                for (det in detections) drawNailOverlay(snpCanvas, det, scaleX, scaleY, padLeft, padTop)
                val path = saveSnapshot(snapshotBmp)
                snapshotBmp.recycle()
                snap.complete(path)
            }
        } finally {
            try { holder.unlockCanvasAndPost(canvas) } catch (e: Exception) {
                Log.w(TAG, "unlockCanvasAndPost failed", e)
            }
        }
    }

    // ── AR Nail Overlay ────────────────────────────────────────────────────────

    /**
     * Vẽ đường viền Polygon + ốp ảnh móng lên 1 ngón tay.
     *
     * Quy trình (giống overlay.py trên Desktop):
     *  1. Lấy nailBedPolygon (đã được slice ở 75% chiều dài móng).
     *  2. Tính tâm + góc xoay từ pcaDirection / forwardVector.
     *  3. Clip canvas bằng polygon path để ốp texture.
     *  4. Dùng Matrix scale+rotate để fit texture vào vùng móng.
     */
    private fun drawNailOverlay(
        canvas: Canvas,
        det: NailDetection,
        scaleX: Float, scaleY: Float,
        padLeft: Float, padTop: Float,
    ) {
        val polyRaw = det.polygon.takeIf { it.size >= 3 } ?: return
        val bedPolyRaw = det.nailBedPolygon.takeIf { it.size >= 3 } ?: polyRaw
        val classColor = CLASS_COLORS[det.clsName] ?: Color.WHITE

        // 1. Calculate v_long and v_short
        val dir = det.forwardVector ?: det.pcaDirection ?: PointF(0f, -1f)
        var vLongX = dir.x
        var vLongY = dir.y
        val vLongMag = Math.hypot(vLongX.toDouble(), vLongY.toDouble()).toFloat()
        if (vLongMag > 1e-9f) {
            vLongX /= vLongMag
            vLongY /= vLongMag
        } else {
            vLongX = 0f; vLongY = -1f
        }
        val vShortX = -vLongY
        val vShortY = vLongX

        // 2. Project bedPoly onto v_short to get w_bed
        var minShort = Float.POSITIVE_INFINITY
        var maxShort = Float.NEGATIVE_INFINITY
        for (p in bedPolyRaw) {
            val proj = p.x * vShortX + p.y * vShortY
            if (proj < minShort) minShort = proj
            if (proj > maxShort) maxShort = proj
        }
        val wBed = Math.max(1f, maxShort - minShort)

        // 3. Project full polygon onto v_long to get min_long and max_long_natural
        var minLong = Float.POSITIVE_INFINITY
        var maxLongNatural = Float.NEGATIVE_INFINITY
        for (p in polyRaw) {
            val proj = p.x * vLongX + p.y * vLongY
            if (proj < minLong) minLong = proj
            if (proj > maxLongNatural) maxLongNatural = proj
        }

        val design = loadDesignBitmap(det.designAssetPath)

        // Build the basic YOLO polygon path for fallback and for the hybrid mask
        val polyPath = Path()
        var first = true
        for (p in polyRaw) {
            val cx = p.x * scaleX + padLeft
            val cy = p.y * scaleY + padTop
            if (first) { polyPath.moveTo(cx, cy); first = false }
            else { polyPath.lineTo(cx, cy) }
        }
        polyPath.close()

        if (design == null) {
            // FALLBACK: Tô màu viền móng rực rỡ để dễ nhìn thấy móng
            polygonFillPaint.color = classColor
            polygonFillPaint.alpha = 180
            canvas.drawPath(polyPath, polygonFillPaint)
            
            polygonPaint.color = classColor
            canvas.drawPath(polyPath, polygonPaint)
            return
        }

        // 4. Calculate h_mapped preserving aspect ratio
        val designW = Math.max(1, design.width).toFloat()
        val designH = design.height.toFloat()
        val aspectRatio = designH / designW
        val hMapped = wBed * aspectRatio
        // Phóng to một chút xíu (khoảng 3%) để đảm bảo ôm khít phần chân móng
        val scaleFudge = 1.03f 
        val maxLong = minLong + (hMapped * scaleFudge)
        
        // Mở rộng minShort/maxShort một chút xíu để ôm sát hai cạnh bên móng
        val padW = (maxShort - minShort) * (scaleFudge - 1.0f) / 2f
        val renderMinShort = minShort - padW
        val renderMaxShort = maxShort + padW

        // 5. Build dstPts (4 corners) in raw coordinates, then scale to canvas
        val cuticleL_x = minLong * vLongX + renderMinShort * vShortX
        val cuticleL_y = minLong * vLongY + renderMinShort * vShortY
        
        val cuticleR_x = minLong * vLongX + renderMaxShort * vShortX
        val cuticleR_y = minLong * vLongY + renderMaxShort * vShortY
        
        val tipR_x = maxLong * vLongX + renderMaxShort * vShortX
        val tipR_y = maxLong * vLongY + renderMaxShort * vShortY
        
        val tipL_x = maxLong * vLongX + renderMinShort * vShortX
        val tipL_y = maxLong * vLongY + renderMinShort * vShortY

        val dstPts = floatArrayOf(
            cuticleL_x * scaleX + padLeft, cuticleL_y * scaleY + padTop,
            cuticleR_x * scaleX + padLeft, cuticleR_y * scaleY + padTop,
            tipR_x * scaleX + padLeft, tipR_y * scaleY + padTop,
            tipL_x * scaleX + padLeft, tipL_y * scaleY + padTop
        )

        // srcPts: BottomLeft, BottomRight, TopRight, TopLeft
        // Image coordinates: Top is y=0, Bottom is y=height (cuticle)
        val srcPts = floatArrayOf(
            0f, designH,       // Bottom Left (cuticle_L)
            designW, designH,  // Bottom Right (cuticle_R)
            designW, 0f,       // Top Right (tip_R)
            0f, 0f             // Top Left (tip_L)
        )

        val matrix = android.graphics.Matrix()
        matrix.setPolyToPoly(srcPts, 0, dstPts, 0, 4)

        // 6. Create Hybrid Mask (Clip at base, open at tip)
        val hybridPath = Path()
        
        // 6b. Infinite Tip Rectangle (starts at 50% of natural nail length)
        val startLong = minLong + (maxLongNatural - minLong) * 0.5f
        
        val rectBL_x = startLong * vLongX + renderMinShort * vShortX
        val rectBL_y = startLong * vLongY + renderMinShort * vShortY
        
        val rectBR_x = startLong * vLongX + renderMaxShort * vShortX
        val rectBR_y = startLong * vLongY + renderMaxShort * vShortY
        
        val rectTR_x = maxLong * vLongX + renderMaxShort * vShortX
        val rectTR_y = maxLong * vLongY + renderMaxShort * vShortY
        
        val rectTL_x = maxLong * vLongX + renderMinShort * vShortX
        val rectTL_y = maxLong * vLongY + renderMinShort * vShortY

        val tipRectPath = Path()
        tipRectPath.moveTo(rectBL_x * scaleX + padLeft, rectBL_y * scaleY + padTop)
        tipRectPath.lineTo(rectBR_x * scaleX + padLeft, rectBR_y * scaleY + padTop)
        tipRectPath.lineTo(rectTR_x * scaleX + padLeft, rectTR_y * scaleY + padTop)
        tipRectPath.lineTo(rectTL_x * scaleX + padLeft, rectTL_y * scaleY + padTop)
        tipRectPath.close()

        // Merge paths using UNION
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT) {
            hybridPath.op(polyPath, tipRectPath, Path.Op.UNION)
        } else {
            hybridPath.addPath(polyPath)
            hybridPath.addPath(tipRectPath)
        }

        // Tinh chỉnh độ sáng/blending tự nhiên nếu cần (bỏ qua, xài alpha blend cơ bản)
        // 7. Vẽ móng
        canvas.save()
        canvas.clipPath(hybridPath)
        
        val renderPaint = android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG or android.graphics.Paint.ANTI_ALIAS_FLAG)
        canvas.drawBitmap(design, matrix, renderPaint)
        
        canvas.restore()
        
        // Vẽ thêm một viền trắng mờ bao quanh viền da gốc để móng hòa hợp tự nhiên hơn
        polygonPaint.color = Color.argb(40, 255, 255, 255)
        canvas.drawPath(polyPath, polygonPaint)
    }

    // ── Skeleton ───────────────────────────────────────────────────────────────

    private fun drawSkeleton(
        canvas: Canvas,
        scaleX: Float, scaleY: Float,
        padLeft: Float, padTop: Float,
    ) {
        val skel = currentSkeletonPoints ?: return
        val pts = skel.map { p -> PointF(p[0] * scaleX + padLeft, p[1] * scaleY + padTop) }
        for (c in HAND_CONNECTIONS) {
            val a = pts.getOrNull(c[0]) ?: continue
            val b = pts.getOrNull(c[1]) ?: continue
            canvas.drawLine(a.x, a.y, b.x, b.y, skeletonLinePaint)
        }
        for (p in pts) canvas.drawCircle(p.x, p.y, 8f, skeletonPointPaint)
    }

    // ── BBox debug ────────────────────────────────────────────────────────────

    private fun drawBboxes(
        canvas: Canvas,
        detections: List<NailDetection>,
        scaleX: Float, scaleY: Float,
        padLeft: Float, padTop: Float,
    ) {
        for (d in detections) {
            val cx = d.bboxCx * scaleX + padLeft
            val cy = d.bboxCy * scaleY + padTop
            val w  = d.bboxW  * scaleX
            val h  = d.bboxH  * scaleY
            val color = CLASS_COLORS[d.clsName] ?: Color.CYAN
            bboxPaint.color = color
            canvas.drawRect(cx - w / 2f, cy - h / 2f, cx + w / 2f, cy + h / 2f, bboxPaint)
            val label = "${d.clsName} ${(d.confidence * 100).toInt()}%"
            canvas.drawRect(cx - w / 2f, cy - h / 2f - 32f, cx - w / 2f + label.length * 14f, cy - h / 2f, labelBgPaint)
            canvas.drawText(label, cx - w / 2f + 6f, cy - h / 2f - 8f, labelTextPaint)
        }
    }

    // ── Design Bitmap loader ──────────────────────────────────────────────────

    /**
     * Load bitmap từ designAssetPath (absolute file path được Flutter truyền vào).
     * Kết quả được cache để tránh IO mỗi frame.
     */
    private fun loadDesignBitmap(path: String?): Bitmap? {
        if (path == null) {
            Log.w(TAG, "loadDesignBitmap: path is null!")
            return null
        }
        designCache[path]?.let { return it }
        
        Log.d(TAG, "loadDesignBitmap: loading from '$path'")
        val file = java.io.File(path)
        if (!file.exists()) {
            Log.w(TAG, "loadDesignBitmap: file does not exist at '$path'")
            return null
        }
        
        return try {
            val bmp = BitmapFactory.decodeFile(path)
            if (bmp == null) {
                Log.w(TAG, "loadDesignBitmap: BitmapFactory.decodeFile returned null for '$path'")
            } else {
                Log.d(TAG, "loadDesignBitmap: loaded ${bmp.width}x${bmp.height} from '$path'")
            }
            designCache[path] = bmp
            bmp
        } catch (e: Exception) {
            Log.w(TAG, "loadDesignBitmap failed for '$path': ${e.message}")
            designCache[path] = null
            null
        }
    }

    // ── FPS ────────────────────────────────────────────────────────────────────

    private fun updateFps() {
        fpsFrames++
        val now = SystemClock.uptimeMillis()
        val dt = now - fpsLastMs
        if (dt >= 1000) {
            fpsValue  = fpsFrames * 1000f / dt
            fpsFrames = 0
            fpsLastMs = now
        }
    }

    // ── Snapshot ───────────────────────────────────────────────────────────────

    private fun saveSnapshot(bitmap: Bitmap): String? {
        return try {
            val ctx = appContext ?: return null
            val dir = ctx.cacheDir
            val file = File(dir, "nail_snapshot_${System.currentTimeMillis()}.jpg")
            java.io.FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
            }
            file.absolutePath
        } catch (e: Exception) {
            Log.w(TAG, "saveSnapshot failed: ${e.message}", e)
            null
        }
    }
}