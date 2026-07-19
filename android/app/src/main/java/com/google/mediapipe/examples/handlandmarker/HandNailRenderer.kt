package com.google.mediapipe.examples.handlandmarker

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import com.google.mediapipe.examples.handlandmarker.model.NailDecoration
import com.google.mediapipe.examples.handlandmarker.model.NailSetConfig
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import kotlin.math.atan2
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Vẽ nail graphic theo POLYGON polygon-fit thay vì Rect.
 *
 * Anchor point = MCP (đốt gốc ngón) — KHÔNG phải TIP.
 * Lý do:
 *   - MediaPipe có thể "ảo" các landmark ở TIP khi ngón bị cụt / che.
 *   - MCP tại đốt gốc ngón là điểm nối giải phẫu cố định, nằm ở lòng bàn tay
 *     — ĐÚNG vị trí anchor ngay cả khi ngón bị cụt.
 *   - Polygon's cuticle line (đường viền gốc móng) được đặt tại MCP anchor.
 *
 * Luồng:
 *   1. Lấy MCP pixel coords làm anchor.
 *   2. Lấy direction vector MCP→TIP (nếu TIP hợp lệ) hoặc MCP→PIP (fallback).
 *   3. Load polygon JSON tương ứng với shape.
 *   4. Transform polygon vertices: scale (width × length), rotate (theo axis), translate (to anchor).
 *   5. Vẽ nail base (filled + masked theo shape), surface effects, decorations.
 */
class HandNailRenderer(private val context: android.content.Context) {

    private val polygonCache = mutableMapOf<String, NailPolygon>()
    private val path = Path()

    fun getOrLoadPolygon(shape: String): NailPolygon? {
        polygonCache[shape]?.let { return it }
        val loaded = NailPolygon.load(context, shape)
        if (loaded != null) polygonCache[shape] = loaded
        return loaded
    }

    /**
     * Draw nail graphic using polygon-fit.
     *
     * @param canvas        Target canvas
     * @param shapeBitmap   Optional shape mask bitmap (replaces polygon if non-null)
     * @param polygon       Nail polygon loaded from JSON. Vertices already in local space.
     * @param anchorPx      Anchor point in pixel coords (MCP pixel position on canvas)
     * @param axisRad       Angle of finger direction in canvas coords (rad, atan2-style)
     * @param widthPx       Nail width in pixels (matches finger width)
     * @param lengthPx      Nail length in pixels (free edge + nail bed)
     * @param config        User design config (color, decorations)
     */
    fun drawNailGraphic(
        canvas: Canvas,
        shapeBitmap: android.graphics.Bitmap?,
        polygon: NailPolygon?,
        anchorPx: PointF,
        axisRad: Float,
        widthPx: Float,
        lengthPx: Float,
        config: NailSetConfig,
        designIndex: Int,
        colorOverride: String? = null
    ) {
        val design = config.nails.getOrNull(designIndex) ?: config.nails.firstOrNull()
        val color = colorOverride ?: design?.color ?: "#FF0000"

        // Calculate nail bounds from polygon or fallback to Rect
        val destRect: RectF
        val polygonVerts: List<PointF>?

        if (polygon != null) {
            val transformer = PolygonTransformer()
            val verts = transformer.transform(
                polygon.localVertices,
                anchorPx.x, anchorPx.y,
                axisRad,
                widthPx, lengthPx
            )
            polygonVerts = verts
            destRect = computeBounds(verts)
        } else if (shapeBitmap != null) {
            polygonVerts = null
            destRect = RectF(
                anchorPx.x - widthPx / 2f,
                anchorPx.y - lengthPx,
                anchorPx.x + widthPx / 2f,
                anchorPx.y
            )
        } else {
            return
        }

        // Render filled nail
        if (polygonVerts != null) {
            drawFilledPolygonNail(canvas, polygonVerts, color, config)
        } else {
            drawNailBaseBitmap(canvas, shapeBitmap!!, destRect, color, config)
        }

        // Surface effects
        if (polygonVerts != null) {
            drawSurfaceEffectsPolygon(canvas, polygonVerts, config)
        } else {
            drawSurfaceEffectsBitmap(canvas, shapeBitmap!!, destRect, config)
        }

        // Decorations (kept as bitmap drawables — they don't depend on nail geometry)
        design?.decorations?.forEach { decoration ->
            drawDecoration(canvas, decoration, destRect)
        }
    }

    private fun drawFilledPolygonNail(
        canvas: Canvas,
        verts: List<PointF>,
        color: String,
        config: NailSetConfig
    ) {
        path.reset()
        if (verts.isEmpty()) return
        path.moveTo(verts[0].x, verts[0].y)
        for (i in 1 until verts.size) {
            path.lineTo(verts[i].x, verts[i].y)
        }
        path.close()

        val bounds = computeBounds(verts)
        val baseColor = parseColorOrDefault(color)
        val surfaceColor = applySurfaceOffsets(baseColor, config)

        canvas.save()
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = surfaceColor
            if (config.gradient.enabled) {
                shader = createGradientShader(config, bounds)
            } else {
                materialShader(this, surfaceColor, config, bounds)
            }
        }
        canvas.drawPath(path, fillPaint)
        canvas.restore()
    }

    private fun drawNailBaseBitmap(
        canvas: Canvas,
        shapeBitmap: android.graphics.Bitmap,
        destRect: RectF,
        color: String,
        config: NailSetConfig
    ) {
        val layer = canvas.saveLayer(destRect, null)
        val baseColor = parseColorOrDefault(color)
        val surfaceColor = applySurfaceOffsets(baseColor, config)

        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = surfaceColor
            if (config.gradient.enabled) {
                shader = createGradientShader(config, destRect)
            } else {
                materialShader(this, surfaceColor, config, destRect)
            }
        }
        canvas.drawRect(destRect, fillPaint)

        val maskPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN)
        }
        canvas.drawBitmap(shapeBitmap, null, destRect, maskPaint)
        maskPaint.xfermode = null
        canvas.restoreToCount(layer)
    }

    private fun drawSurfaceEffectsPolygon(canvas: Canvas, verts: List<PointF>, config: NailSetConfig) {
        // Lighter surface effects pass for polygon shapes - reuse as path-based masks
        if (config.surface == null) return
        path.reset()
        path.moveTo(verts[0].x, verts[0].y)
        for (i in 1 until verts.size) path.lineTo(verts[i].x, verts[i].y)
        path.close()

        canvas.save()
        // Mask future effects to polygon shape
        canvas.clipPath(path)
        val bounds = computeBounds(verts)
        drawSurfaceInsideBounds(canvas, bounds, config)
        canvas.restore()
    }

    private fun drawSurfaceEffectsBitmap(
        canvas: Canvas,
        shapeBitmap: android.graphics.Bitmap,
        destRect: RectF,
        config: NailSetConfig
    ) {
        val layer = canvas.saveLayer(destRect, null)
        drawSurfaceInsideBounds(canvas, destRect, config)
        val maskPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN)
        }
        canvas.drawBitmap(shapeBitmap, null, destRect, maskPaint)
        maskPaint.xfermode = null
        canvas.restoreToCount(layer)
    }

    private fun drawSurfaceInsideBounds(canvas: Canvas, bounds: RectF, config: NailSetConfig) {
        val surface = config.surface ?: return
        val params = parseSurfaceParams(surface.shaderParam)
        val name = surface.name.orEmpty().lowercase()

        val hasMatte = name.contains("matte") || params.optJSONObject("texture")?.optString("type") == "matte"
        if (hasMatte) {
            val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = android.graphics.Color.argb(24, 0, 0, 0)
            }
            canvas.drawRect(bounds, p)
        }

        val shine = params.optJSONObject("shine")
        if (shine?.optBoolean("enabled") == true) {
            val position = shine.optString("position", "top-right")
            val cx = when (position) {
                "top-left" -> bounds.left + bounds.width() * 0.28f
                "center" -> bounds.centerX()
                else -> bounds.right - bounds.width() * 0.28f
            }
            val cy = when (position) {
                "center" -> bounds.centerY()
                else -> bounds.top + bounds.height() * 0.26f
            }
            val opacity = (shine.optDouble("opacity", 0.55).toFloat().coerceIn(0f, 1f) * 255).toInt()
            val radius = bounds.width() * shine.optDouble("size", 0.42).toFloat().coerceIn(0.18f, 0.9f)
            val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = android.graphics.RadialGradient(
                    cx, cy, radius,
                    intArrayOf(android.graphics.Color.argb(opacity, 255, 255, 255), android.graphics.Color.TRANSPARENT),
                    null, android.graphics.Shader.TileMode.CLAMP
                )
            }
            canvas.drawRect(bounds, p)
        }
    }

    private fun drawDecoration(canvas: Canvas, decoration: NailDecoration, nailBounds: RectF) {
        // Same as before — bitmap decoration
        val bitmap = try {
            val input = java.net.URL(decoration.imageSrc).openStream()
            android.graphics.BitmapFactory.decodeStream(input)
        } catch (_: Exception) { null } ?: return
        val width = nailBounds.width() * decoration.scale
        val height = nailBounds.height() * decoration.scale
        val centerX = nailBounds.centerX() + decoration.x * nailBounds.width()
        val centerY = nailBounds.centerY() + decoration.y * nailBounds.height()
        val rect = RectF(centerX - width / 2f, centerY - height / 2f, centerX + width / 2f, centerY + height / 2f)
        canvas.save()
        canvas.rotate(decoration.rotation, centerX, centerY)
        canvas.drawBitmap(bitmap, null, rect, null)
        canvas.restore()
    }

    private fun materialShader(paint: Paint, color: Int, config: NailSetConfig, bounds: RectF) {
        if (config.material == NailSetConfig.MATERIAL_METALLIC) {
            paint.shader = android.graphics.LinearGradient(
                bounds.left, bounds.top, bounds.right, bounds.bottom,
                intArrayOf(
                    adjustColor(color, brightness = 0.55f),
                    adjustColor(color, brightness = 1.35f),
                    color,
                    adjustColor(color, brightness = 1.5f),
                    adjustColor(color, brightness = 0.45f)
                ),
                floatArrayOf(0f, 0.3f, 0.5f, 0.7f, 1f),
                android.graphics.Shader.TileMode.CLAMP
            )
        } else if (config.material == NailSetConfig.MATERIAL_IRIDESCENT) {
            paint.shader = android.graphics.LinearGradient(
                bounds.left, bounds.top, bounds.right, bounds.bottom,
                intArrayOf(
                    mixColor(color, android.graphics.Color.RED, 0.3f),
                    mixColor(color, android.graphics.Color.BLUE, 0.3f),
                    mixColor(color, android.graphics.Color.MAGENTA, 0.3f)
                ),
                null, android.graphics.Shader.TileMode.CLAMP
            )
        }
    }

    private fun createGradientShader(config: NailSetConfig, bounds: RectF): android.graphics.Shader? {
        val stops = config.gradient.stops.take(config.gradient.stopCount.coerceIn(2, 3))
            .map(::parseColorOrDefault)
            .map { applySurfaceOffsets(it, config) }
            .toIntArray()
        return when (config.gradient.type) {
            com.google.mediapipe.examples.handlandmarker.model.GradientConfig.TYPE_HORIZONTAL ->
                android.graphics.LinearGradient(bounds.left, bounds.centerY(), bounds.right, bounds.centerY(), stops, null, android.graphics.Shader.TileMode.CLAMP)
            com.google.mediapipe.examples.handlandmarker.model.GradientConfig.TYPE_RADIAL ->
                android.graphics.RadialGradient(bounds.centerX(), bounds.centerY(), bounds.width().coerceAtLeast(bounds.height()), stops, null, android.graphics.Shader.TileMode.CLAMP)
            else -> android.graphics.LinearGradient(bounds.centerX(), bounds.top, bounds.centerX(), bounds.bottom, stops, null, android.graphics.Shader.TileMode.CLAMP)
        }
    }

    private fun computeBounds(verts: List<PointF>): RectF {
        if (verts.isEmpty()) return RectF()
        var minX = Float.MAX_VALUE; var maxX = -Float.MAX_VALUE
        var minY = Float.MAX_VALUE; var maxY = -Float.MAX_VALUE
        for (v in verts) {
            if (v.x < minX) minX = v.x
            if (v.x > maxX) maxX = v.x
            if (v.y < minY) minY = v.y
            if (v.y > maxY) maxY = v.y
        }
        return RectF(minX, minY, maxX, maxY)
    }

    private fun parseSurfaceParams(shaderParam: String?): org.json.JSONObject {
        if (shaderParam.isNullOrBlank()) return org.json.JSONObject()
        return try { org.json.JSONObject(shaderParam) } catch (_: Exception) { org.json.JSONObject() }
    }

    private fun applySurfaceOffsets(color: Int, config: NailSetConfig): Int {
        val surface = config.surface ?: return color
        val hsv = FloatArray(3)
        android.graphics.Color.colorToHSV(color, hsv)
        hsv[0] = ((hsv[0] + surface.hueOffset) % 360f + 360f) % 360f
        hsv[1] = (hsv[1] + surface.saturationOffset).coerceIn(0f, 1f)
        hsv[2] = (hsv[2] + surface.lightnessOffset).coerceIn(0f, 1f)
        return android.graphics.Color.HSVToColor(android.graphics.Color.alpha(color), hsv)
    }

    private fun parseColorOrDefault(colorValue: String): Int =
        try { android.graphics.Color.parseColor(colorValue) }
        catch (_: IllegalArgumentException) { android.graphics.Color.parseColor("#FF4081") }

    private fun adjustColor(color: Int, saturation: Float = 1f, brightness: Float = 1f): Int {
        val hsv = FloatArray(3)
        android.graphics.Color.colorToHSV(color, hsv)
        hsv[1] = (hsv[1] * saturation).coerceIn(0f, 1f)
        hsv[2] = (hsv[2] * brightness).coerceIn(0f, 1f)
        return android.graphics.Color.HSVToColor(android.graphics.Color.alpha(color), hsv)
    }

    private fun mixColor(first: Int, second: Int, ratio: Float): Int {
        val inv = 1f - ratio
        return android.graphics.Color.argb(
            (android.graphics.Color.alpha(first) * inv + android.graphics.Color.alpha(second) * ratio).toInt(),
            (android.graphics.Color.red(first) * inv + android.graphics.Color.red(second) * ratio).toInt(),
            (android.graphics.Color.green(first) * inv + android.graphics.Color.green(second) * ratio).toInt(),
            (android.graphics.Color.blue(first) * inv + android.graphics.Color.blue(second) * ratio).toInt()
        )
    }
}
