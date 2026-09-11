package com.google.mediapipe.examples.handlandmarker

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.util.AttributeSet
import android.util.Log
import android.view.View
import androidx.core.content.ContextCompat
import androidx.core.graphics.withTranslation
import com.google.mediapipe.examples.handlandmarker.model.NailDecoration
import com.google.mediapipe.examples.handlandmarker.model.NailSetConfig
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import org.json.JSONObject
import java.net.URL
import kotlin.math.acos
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt
/**
 * Metrics về hình học của một ngón tay, tính từ MediaPipe landmarks.
 * Dùng cho physical rule checks và render transforms.
 *
 * Finger skeleton (index/middle/ring/pinky):
 *   MCP (0) ── PIP (1) ── DIP (2) ── TIP (3)
 *
 * Thumb skeleton:
 *   CMC (0) ── MCP (1) ── IP  (2) ── TIP (3)
 *
 * @param fingerIndex  0=thumb, 1=index, 2=middle, 3=ring, 4=pinky
 * @param skipReason   null = render được, non-null = lý do skip (dùng cho debug log)
 */
private data class FingerMetrics(
    val fingerIndex: Int,
    // Geometric distances (normalized [0,1])
    val mcpTipDist: Float,      // dist(MCP → TIP)
    val pipTipDist: Float,      // dist(PIP → TIP)
    val dipTipDist: Float,      // dist(DIP → TIP)
    val mcpPipDist: Float,     // dist(MCP → PIP)
    // Ratios
    val bentRatio: Float,       // mcpTipDist / pipTipDist (bent detection)
    val dipDipRatio: Float,     // mcpTipDist / dipTipDist
    // Axis direction (PIP → TIP, stable hơn DIP → TIP)
    val axisDx: Float,          // normalized direction X
    val axisDy: Float,          // normalized direction Y
    val axisDz: Float,          // normalized direction Z (depth)
    // Fold angle: góc giữa MCP→WRIST (hướng lòng bàn tay) và MCP→PIP (hướng ngón).
    // Bent finger → góc nhỏ (< ~60°) vì ngón chỉ về phía lòng bàn tay.
    // Extended finger → góc lớn (> ~100°) vì ngón chỉ ra ngoài xa lòng bàn tay.
    val foldAngleDeg: Float,
    // Nail ROI (pixel-space, sau khi nhân scaleFactor)
    val nailCenterX: Float,     // pixel x của đầu ngón (trên canvas)
    val nailCenterY: Float,     // pixel y của đầu ngón (trên canvas)
    val nailWidthPx: Float,     // pixel width ước lượng từ finger width
    val nailHeightPx: Float,    // pixel height dựa trên shape + length config
    val rotationDeg: Float,     // góc xoay móng (0° = thẳng đứng)
    // Physical rule results
    val isBent: Boolean,        // ngón gập (fold angle + ratio)
    val isCurled: Boolean,      // ngón cuộn — TIP không vươn ra xa so với MCP (wrist-distance signal)
    val isNailTooWide: Boolean,  // nail width > finger width × threshold
    val isOccluded: Boolean,     // DIP/PIP bị che bởi ngón khác
    val isUnstable: Boolean,    // confidence/visibility quá thấp
    val skipReason: String?,     // null = OK, non-null = skip với lý do
) {
    companion object {
        /** Tên hiển thị của từng ngón. */
        val FINGER_NAMES = listOf("thumb", "index", "middle", "ring", "pinky")

        /** Landmark index của TIP cho từng ngón. */
        val FINGER_TIPS = listOf(4, 8, 12, 16, 20)

        /** Landmark index của PIP cho từng ngón. */
        val FINGER_PIPS = listOf(3, 6, 10, 14, 18)

        /** Landmark index của MCP cho từng ngón. */
        val FINGER_MCPS = listOf(2, 5, 9, 13, 17)

        /** Landmark index của DIP cho từng ngón (= TIP - 1). */
        fun dipIndex(tipIndex: Int) = tipIndex - 1

        /**
         * Ước lượng chiều rộng ngón tay (pixel) từ khoảng cách MCP-PIP.
         * Ngón tay trung bình rộng khoảng 0.5–0.7× khoảng cách MCP-PIP theo chiều ngang.
         *
         * @param mcpPipDist  Khoảng cách MCP→PIP (normalized)
         * @param imageSizePx  Kích thước ảnh (width hoặc height, tuỳ trục chính)
         * @param sf           Scale factor
         * @return Chiều rộng ngón tay ước lượng (pixel)
         */
        fun estimateFingerWidth(mcpPipDist: Float, imageSizePx: Float, sf: Float): Float {
            // Tỉ lệ finger width / MCP-PIP distance (~0.55 theo anthropometry trung bình)
            return mcpPipDist * imageSizePx * sf * FINGER_WIDTH_RATIO
        }

        private const val FINGER_WIDTH_RATIO = 0.55f
    }
}

/**
 * Skip reason mã hoá thành short string để log.
 * Giúp debug nhanh trong logcat.
 */
private enum class SkipReason(val code: String) {
    BENT       ("BENT"),
    WIDE_NAIL  ("WIDE"),
    OCCLUDED   ("OCCL"),
    UNSTABLE   ("UNST"),
    NO_DESIGN  ("NDES"),
    NO_BITMAP  ("NBMP"),
    MISSING_LM ("MISS"),
    SHORT      ("SHORT"),
}

class OverlayView(context: Context?, attrs: AttributeSet?) :
    View(context, attrs) {

    private var results: HandLandmarkerResult? = null
    private var linePaint = Paint()
    private var pointPaint = Paint()
    private var promptPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private var ballerinaBitmap: Bitmap? = null
    private var squovalBitmap: Bitmap? = null
    private var stilettoBitmap: Bitmap? = null
    
    private var nailSetConfig: NailSetConfig = NailSetConfig.default()
    private val bitmapCache = mutableMapOf<String, Bitmap?>()
    private val loadingBitmaps = mutableSetOf<String>()

    private var scaleFactor: Float = 1f
    private var imageWidth: Int = 1
    private var imageHeight: Int = 1

    init {
        initPaints()
        ballerinaBitmap = BitmapFactory.decodeResource(resources, R.drawable.ballerina)
        squovalBitmap = BitmapFactory.decodeResource(resources, R.drawable.squoval)
        stilettoBitmap = BitmapFactory.decodeResource(resources, R.drawable.stiletto)
    }

    fun clear() {
        if (DEBUG_LOG) Log.v(TAG, "clear")
        results = null
        linePaint.reset()
        pointPaint.reset()
        invalidate()
        initPaints()
    }

    private fun initPaints() {
        val density = resources.displayMetrics.density
        
        linePaint.color =
            ContextCompat.getColor(context!!, R.color.mp_color_primary)
        linePaint.strokeWidth = LANDMARK_STROKE_WIDTH * density
        linePaint.style = Paint.Style.STROKE

        pointPaint.color = Color.YELLOW
        pointPaint.strokeWidth = LANDMARK_STROKE_WIDTH * density
        pointPaint.style = Paint.Style.FILL
    }

        override fun draw(canvas: Canvas) {
        super.draw(canvas)
        results?.let { handLandmarkerResult ->
            for (landmark in handLandmarkerResult.landmarks()) {
                val fingerTips = listOf(4, 8, 12, 16, 20) 

                for ((fingerIndex, tipIndex) in fingerTips.withIndex()) {
                    val tip = landmark[tipIndex]
                    val joint =
                        landmark[tipIndex - 1] // The joint right below the tip (7, 11, 15, 19, 3)
                    val design = nailSetConfig.nails.getOrNull(fingerIndex)
                        ?: nailSetConfig.nails.firstOrNull()
                        ?: continue

                    val jx = joint.x() * imageWidth * scaleFactor
                    val jy = joint.y() * imageHeight * scaleFactor
                    val tx = tip.x() * imageWidth * scaleFactor
                    val ty = tip.y() * imageHeight * scaleFactor
                    val px = tx
                    val py = ty

                    val angle = Math.toDegrees(atan2((ty - jy).toDouble(), (tx - jx).toDouble())).toFloat()

                    val fingerLength = hypot((tx - jx).toDouble(), (ty - jy).toDouble()).toFloat()

                    canvas.withTranslation(px, py) {
                        rotate(angle + 90f) // Rotate to match finger direction

                        val customShapeBitmap = loadBitmapFromUri(design.customShapeSrc)
                        val shapeImageBitmap = loadBitmapFromUri(nailSetConfig.shapeImageSrc)
                        val nailBitmap = customShapeBitmap
                            ?: shapeImageBitmap
                            ?: getShapeBitmap(nailSetConfig.shape)

                        nailBitmap?.let { bitmap ->
                            val nailWidth = fingerLength * NAIL_LANDMARK_WIDTH_SCALE
                            val nailHeight = fingerLength * NAIL_LANDMARK_HEIGHT_SCALE * nailSetConfig.length

                            val nailBottom = fingerLength * 0.75f // Fixed base position relative to tip
                            val totalHeight = nailHeight * 1.5f    // Total height expands with multiplier

                            val destRect = RectF(
                                -nailWidth / 2, 
                                nailBottom - totalHeight, // Tip grows upwards
                                nailWidth / 2, 
                                nailBottom                // Base stays fixed
                            )

                            // Layer 1: Base + Color (Skip color filter only for per-finger custom shapes)
                            if (customShapeBitmap == null) {
                                drawNailBase(
                                    this,
                                    bitmap,
                                    destRect,
                                    createNailPaint(
                                        design.color,
                                        design.gradient ?: nailSetConfig.gradient,
                                        destRect
                                    )
                                )
                            } else {
                                drawBitmap(bitmap, null, destRect, null)
                            }
                            design.decorations.forEach { decoration ->
                                drawDecoration(this, decoration, destRect)
                            }
                        }

                    }
                }

                stats["OK"] = (stats["OK"] ?: 0) + 1
                if (DEBUG_LOG) {
                    Log.i(TAG, "  RENDER hand=$handIdx ${FingerMetrics.FINGER_NAMES[fingerIndex]}: " +
                        "center=(${String.format("%.1f", finalPx)},${String.format("%.1f", finalPy)}) " +
                        "rotation=${String.format("%.1f", rotation)}° " +
                        "size=${String.format("%.1f", nailWidth)}x${String.format("%.1f", nailHeight)} " +
                        "color=${design.color} shape=${nailSetConfig.shape} " +
                        "decorationCount=${design.decorations.size} " +
                        "bentRatio=${String.format("%.3f", metrics.bentRatio)} " +
                        "foldAngle=${String.format("%.1f", metrics.foldAngleDeg)}° " +
                        "nailWidthPx=${String.format("%.1f", metrics.nailWidthPx)}" +
                        (if (cvDetected) " cvConf=${String.format("%.2f", cvConf)}" else ""))
                }
            }
        }

        if (DEBUG_LOG && stats.isNotEmpty()) {
            val summary = stats.entries.joinToString(" ") { "${it.key}=${it.value}" }
            Log.v(TAG, "drawNails done: $summary")
        }
    }

    fun setResults(
        handLandmarkerResults: HandLandmarkerResult,
        imageHeight: Int,
        imageWidth: Int,
        runningMode: RunningMode = RunningMode.IMAGE
    ) {
        results = handLandmarkerResults

        this.imageHeight = imageHeight
        this.imageWidth = imageWidth

        scaleFactor = when (runningMode) {
            RunningMode.IMAGE,
            RunningMode.VIDEO -> {
                min(width * 1f / imageWidth, height * 1f / imageHeight)
            }
            RunningMode.LIVE_STREAM -> {

                max(width * 1f / imageWidth, height * 1f / imageHeight)
            }
        }
        if (DEBUG_LOG) {
            Log.v(TAG, "setResults: runningMode=$runningMode imageSize=${imageWidth}x${imageHeight} " +
                "viewSize=${width}x${height} scaleFactor=$scaleFactor hands=${handLandmarkerResults.landmarks().size}")
        }

        // Phase 6: Trigger async CV detection for live mode (throttled by pipeline)
        if (runningMode == RunningMode.LIVE_STREAM && sourceBitmap != null) {
            val bmp = sourceBitmap!!
            val imgW = this.imageWidth
            val imgH = this.imageHeight
            val firstHand = handLandmarkerResults.landmarks().firstOrNull()
            if (firstHand != null) {
                cvExecutor.execute {
                    try {
                        val handResult = nailDetectionPipeline.detect(
                            bmp, firstHand, imgW, imgH, isLiveMode = true
                        )
                        cvResults = handResult.results
                        post { invalidate() }
                    } catch (e: Exception) {
                        if (DEBUG_LOG) Log.e(TAG, "CV detection error", e)
                    }
                }
            }
        }

        invalidate()
    }

    fun setFullDesign(config: NailSetConfig) {
        if (nailSetConfig == config) return
        if (DEBUG_LOG) {
            Log.i(TAG, "setFullDesign: shape=${config.shape} material=${config.material} " +
                "length=${config.length} nails=${config.nails.size}")
        }
        nailSetConfig = config
        preloadDesignBitmaps(config)
        invalidate()
    }

    private fun loadBitmapFromUri(uriString: String?): Bitmap? {
        if (uriString == null) return null
        if (bitmapCache.containsKey(uriString)) return bitmapCache[uriString]
        if (!loadingBitmaps.add(uriString)) return null
        Thread {
            val bitmap = try {
                if (uriString.startsWith("http://") || uriString.startsWith("https://")) {
                    URL(uriString).openStream().use { BitmapFactory.decodeStream(it) }
                } else {
                    val uri = android.net.Uri.parse(uriString)
                    context.contentResolver.openInputStream(uri).use { inputStream ->
                        BitmapFactory.decodeStream(inputStream)
                    }
                }
            } catch (_: Exception) {
                null
            }
            post {
                bitmapCache[uriString] = bitmap
                loadingBitmaps.remove(uriString)
                invalidate()
            }
        }.start()
        return null
    }

    private fun preloadDesignBitmaps(config: NailSetConfig) {
        loadBitmapFromUri(config.shapeImageSrc)
        config.nails.forEach { design ->
            loadBitmapFromUri(design.customShapeSrc)
            design.decorations.forEach { decoration ->
                loadBitmapFromUri(decoration.imageSrc)
            }
        }
    }

    private fun getShapeBitmap(shape: String): Bitmap? {
        return when (shape) {
            NailSetConfig.SHAPE_BALLERINA -> ballerinaBitmap
            NailSetConfig.SHAPE_SQUOVAL -> squovalBitmap
            NailSetConfig.SHAPE_STILETTO -> stilettoBitmap
            else -> ballerinaBitmap
        }
    }

    private fun createNailPaint(
        colorValue: String,
        gradient: com.google.mediapipe.examples.handlandmarker.model.GradientConfig?,
        nailBounds: RectF
    ): Paint {
        val baseColor = parseColorOrDefault(colorValue)
        return Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = if (gradient?.enabled == true) {
                createGradientShader(gradient, nailBounds)
            } else {
                null
            }
            if (shader == null) {
                color = baseColor
            }
        }
    }

    private fun createGradientShader(
        gradient: com.google.mediapipe.examples.handlandmarker.model.GradientConfig,
        nailBounds: RectF
    ): Shader {
        val colors = gradient.stops
            .take(gradient.stopCount.coerceIn(2, 3))
            .map(::parseColorOrDefault)
            .toIntArray()

        return when (gradient.type) {
            com.google.mediapipe.examples.handlandmarker.model.GradientConfig.TYPE_HORIZONTAL -> LinearGradient(
                nailBounds.left,
                nailBounds.centerY(),
                nailBounds.right,
                nailBounds.centerY(),
                colors,
                null,
                Shader.TileMode.CLAMP
            )
            com.google.mediapipe.examples.handlandmarker.model.GradientConfig.TYPE_RADIAL -> RadialGradient(
                nailBounds.centerX(),
                nailBounds.centerY(),
                nailBounds.width().coerceAtLeast(nailBounds.height()),
                colors,
                null,
                Shader.TileMode.CLAMP
            )
            else -> LinearGradient(
                nailBounds.centerX(),
                nailBounds.top,
                nailBounds.centerX(),
                nailBounds.bottom,
                colors,
                null,
                Shader.TileMode.CLAMP
            )
        }
    }

    private fun createMaterialShader(baseColor: Int, nailBounds: RectF): Shader? {
        return when (nailSetConfig.material) {
            NailSetConfig.MATERIAL_METALLIC -> LinearGradient(
                nailBounds.left,
                nailBounds.top,
                nailBounds.right,
                nailBounds.bottom,
                intArrayOf(
                    adjustColor(baseColor, brightness = 0.55f),
                    adjustColor(baseColor, brightness = 1.35f),
                    baseColor,
                    adjustColor(baseColor, brightness = 1.5f),
                    adjustColor(baseColor, brightness = 0.45f)
                ),
                floatArrayOf(0f, 0.3f, 0.5f, 0.7f, 1f),
                Shader.TileMode.CLAMP
            )
            NailSetConfig.MATERIAL_IRIDESCENT -> LinearGradient(
                nailBounds.left,
                nailBounds.top,
                nailBounds.right,
                nailBounds.bottom,
                intArrayOf(
                    mixColor(baseColor, Color.RED, 0.3f),
                    mixColor(baseColor, Color.BLUE, 0.3f),
                    mixColor(baseColor, Color.MAGENTA, 0.3f)
                ),
                null,
                Shader.TileMode.CLAMP
            )
            else -> null
        }
    }

    private fun drawNailBase(canvas: Canvas, shapeBitmap: Bitmap, nailBounds: RectF, fillPaint: Paint) {
        val layer = canvas.saveLayer(nailBounds, null)
        canvas.drawRect(nailBounds, fillPaint)
        val maskPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN)
        }
        canvas.drawBitmap(shapeBitmap, null, nailBounds, maskPaint)
        maskPaint.xfermode = null
        canvas.restoreToCount(layer)
    }

    private fun drawNailSurface(canvas: Canvas, shapeBitmap: Bitmap, nailBounds: RectF) {
        val surface = nailSetConfig.surface ?: return
        val params = parseSurfaceParams(surface.shaderParam)
        val name = surface.name.orEmpty().lowercase()

        val hasMatte = name.contains("matte") || params.optJSONObject("texture")?.optString("type") == "matte"
        val shine = params.optJSONObject("shine")
        val stripe = params.optJSONObject("stripe")
        val gradient = params.optJSONObject("gradient")
        val metalness = params.optJSONObject("metalness")
        val prism = params.optJSONObject("prism")
        val rainbow = params.optJSONObject("rainbow")
        val iridescence = params.optJSONObject("iridescence")

        if (hasMatte) {
            drawMaskedSurfaceLayer(
                canvas,
                shapeBitmap,
                nailBounds,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(24, 0, 0, 0) }
            )
        }

        if (gradient?.optBoolean("enabled") == true) {
            drawMaskedSurfaceLayer(
                canvas,
                shapeBitmap,
                nailBounds,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    shader = LinearGradient(
                        nailBounds.left,
                        nailBounds.centerY(),
                        nailBounds.right,
                        nailBounds.centerY(),
                        intArrayOf(Color.argb(46, 0, 0, 0), Color.TRANSPARENT, Color.argb(56, 255, 255, 255)),
                        null,
                        Shader.TileMode.CLAMP
                    )
                }
            )
        }

        if (stripe?.optBoolean("enabled") == true || name.contains("cat")) {
            drawMaskedSurfaceLayer(
                canvas,
                shapeBitmap,
                nailBounds,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    shader = LinearGradient(
                        nailBounds.left,
                        nailBounds.centerY(),
                        nailBounds.right,
                        nailBounds.centerY(),
                        intArrayOf(Color.TRANSPARENT, Color.argb(112, 255, 255, 255), Color.TRANSPARENT),
                        floatArrayOf(0.38f, 0.5f, 0.62f),
                        Shader.TileMode.CLAMP
                    )
                }
            )
        }

        if (metalness?.optBoolean("enabled") == true || name.contains("chrome")) {
            drawMaskedSurfaceLayer(
                canvas,
                shapeBitmap,
                nailBounds,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    shader = LinearGradient(
                        nailBounds.left,
                        nailBounds.top,
                        nailBounds.right,
                        nailBounds.bottom,
                        intArrayOf(
                            Color.argb(132, 255, 255, 255),
                            Color.TRANSPARENT,
                            Color.argb(42, 0, 0, 0),
                            Color.argb(92, 255, 255, 255)
                        ),
                        floatArrayOf(0f, 0.32f, 0.62f, 1f),
                        Shader.TileMode.CLAMP
                    )
                }
            )
        }

        if (
            name.contains("holographic") ||
            prism?.optBoolean("enabled") == true ||
            rainbow?.optBoolean("enabled") == true ||
            iridescence?.optBoolean("enabled") == true
        ) {
            drawMaskedSurfaceLayer(
                canvas,
                shapeBitmap,
                nailBounds,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    shader = LinearGradient(
                        nailBounds.left,
                        nailBounds.top,
                        nailBounds.right,
                        nailBounds.bottom,
                        intArrayOf(
                            Color.argb(70, 255, 0, 0),
                            Color.argb(62, 255, 255, 0),
                            Color.argb(56, 0, 255, 0),
                            Color.argb(62, 0, 0, 255),
                            Color.argb(70, 180, 0, 255)
                        ),
                        null,
                        Shader.TileMode.CLAMP
                    )
                }
            )
        }

        if (shine?.optBoolean("enabled") == true) {
            val position = shine.optString("position", "top-right")
            val centerX = when (position) {
                "top-left" -> nailBounds.left + nailBounds.width() * 0.28f
                "center" -> nailBounds.centerX()
                else -> nailBounds.right - nailBounds.width() * 0.28f
            }
            val centerY = when (position) {
                "center" -> nailBounds.centerY()
                else -> nailBounds.top + nailBounds.height() * 0.26f
            }
            val opacity = (shine.optDouble("opacity", 0.55).toFloat().coerceIn(0f, 1f) * 255).roundToInt()
            val radius = nailBounds.width() * shine.optDouble("size", 0.42).toFloat().coerceIn(0.18f, 0.9f)
            drawMaskedSurfaceLayer(
                canvas,
                shapeBitmap,
                nailBounds,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    shader = RadialGradient(
                        centerX,
                        centerY,
                        radius,
                        intArrayOf(Color.argb(opacity, 255, 255, 255), Color.TRANSPARENT),
                        null,
                        Shader.TileMode.CLAMP
                    )
                }
            )
        }
    }

    private fun drawMaskedSurfaceLayer(canvas: Canvas, shapeBitmap: Bitmap, nailBounds: RectF, paint: Paint) {
        val layer = canvas.saveLayer(nailBounds, null)
        canvas.drawRect(nailBounds, paint)
        val maskPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN)
        }
        canvas.drawBitmap(shapeBitmap, null, nailBounds, maskPaint)
        maskPaint.xfermode = null
        canvas.restoreToCount(layer)
    }

    private fun parseSurfaceParams(shaderParam: String?): JSONObject {
        if (shaderParam.isNullOrBlank()) return JSONObject()
        return try {
            JSONObject(shaderParam)
        } catch (_: Exception) {
            JSONObject()
        }
    }

    private fun applySurfaceOffsets(color: Int): Int {
        val surface = nailSetConfig.surface ?: return color
        val hsv = FloatArray(3)
        Color.colorToHSV(color, hsv)
        hsv[1] = (hsv[1] + normalizeUnitOffset(surface.saturationOffset)).coerceIn(0f, 1f)
        hsv[2] = (hsv[2] + normalizeUnitOffset(surface.lightnessOffset)).coerceIn(0f, 1f)
        return Color.HSVToColor(Color.alpha(color), hsv)
    }

    private fun normalizeUnitOffset(value: Float): Float {
        return if (kotlin.math.abs(value) > 1f) value / 100f else value
    }

    private fun drawDecoration(canvas: Canvas, decoration: NailDecoration, nailBounds: RectF) {
        val bitmap = loadBitmapFromUri(decoration.imageSrc) ?: return
        val width = nailBounds.width() * decoration.scale
        val height = nailBounds.height() * decoration.scale
        val centerX = nailBounds.centerX() + decoration.x * nailBounds.width()
        val centerY = nailBounds.centerY() + decoration.y * nailBounds.height()
        val rect = RectF(
            centerX - width / 2f,
            centerY - height / 2f,
            centerX + width / 2f,
            centerY + height / 2f
        )

        canvas.save()
        canvas.rotate(decoration.rotation, centerX, centerY)
        canvas.drawBitmap(bitmap, null, rect, null)
        canvas.restore()
    }

    private fun parseColorOrDefault(colorValue: String): Int {
        return try {
            Color.parseColor(colorValue)
        } catch (_: IllegalArgumentException) {
            Color.parseColor(FingerColorFallback)
        }
    }

    private fun adjustColor(color: Int, saturation: Float = 1f, brightness: Float = 1f): Int {
        val hsv = FloatArray(3)
        Color.colorToHSV(color, hsv)
        hsv[1] = (hsv[1] * saturation).coerceIn(0f, 1f)
        hsv[2] = (hsv[2] * brightness).coerceIn(0f, 1f)
        return Color.HSVToColor(Color.alpha(color), hsv)
    }

    private fun mixColor(first: Int, second: Int, ratio: Float): Int {
        val inverse = 1f - ratio
        return Color.argb(
            (Color.alpha(first) * inverse + Color.alpha(second) * ratio).roundToInt(),
            (Color.red(first) * inverse + Color.red(second) * ratio).roundToInt(),
            (Color.green(first) * inverse + Color.green(second) * ratio).roundToInt(),
            (Color.blue(first) * inverse + Color.blue(second) * ratio).roundToInt()
        )
    }

    /**
     * Tính khoảng cách Euclidean 3D giữa 2 NormalizedLandmark.
     * Dùng trong geometry guard để phát hiện ngón gập.
     */
    private fun euclidean3d(a: com.google.mediapipe.tasks.components.containers.NormalizedLandmark, b: com.google.mediapipe.tasks.components.containers.NormalizedLandmark): Float {
        val dx = b.x() - a.x()
        val dy = b.y() - a.y()
        val dz = (b.z() - a.z()).coerceIn(-1f, 1f)
        return sqrt(dx * dx + dy * dy + dz * dz)
    }

    /**
     * Tính toàn bộ metrics hình học + physical rule checks cho một ngón tay.
     *
     * Quy trình:
     *  1. Tính distances giữa các landmark
     *  2. Tính ratios (bentRatio, dipDipRatio)
     *  3. Tính axis direction (từ PIP → TIP, ổn định hơn DIP → TIP)
     *  4. Tính nail ROI (center, width, height, rotation)
     *  5. Chạy physical rule checks (bent, wide, occluded, unstable)
     *
     * @param fingerIndex  Chỉ số ngón (0=thumb … 4=pinky)
     * @param landmark     Landmark array của một hand
     * @param sf           Scale factor (để convert normalized → pixel)
     * @param imageW       Chiều rộng ảnh gốc (normalized coords)
     * @param imageH       Chiều cao ảnh gốc (normalized coords)
     * @return             FingerMetrics với skipReason null = render được
     */
    private fun computeFingerMetrics(
        fingerIndex: Int,
        landmark: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>,
        sf: Float,
        imageW: Int,
        imageH: Int,
        isSnapshot: Boolean
    ): FingerMetrics {
        val tipIndex = FingerMetrics.FINGER_TIPS[fingerIndex]
        val pipIndex = FingerMetrics.FINGER_PIPS[fingerIndex]
        val mcpIndex = FingerMetrics.FINGER_MCPS[fingerIndex]
        val dipIndex = FingerMetrics.dipIndex(tipIndex)

        val tip   = landmark[tipIndex]
        val pip   = landmark[pipIndex]
        val mcp   = landmark[mcpIndex]
        val dip   = landmark[dipIndex]

        // ── 1. Geometric distances ──────────────────────────────────────────
        val mcpTipDist = euclidean3d(mcp, tip)
        val pipTipDist = euclidean3d(pip, tip)
        val dipTipDist = euclidean3d(dip, tip)
        val mcpPipDist = euclidean3d(mcp, pip)

        // ── 2. Ratios ──────────────────────────────────────────────────────
        // bentRatio = mcpTipDist / pipTipDist
        //   Ngón thẳng → ~2.0  (vì có đủ 2 đốt MCP→PIP + PIP→DIP + DIP→TIP ≈ 3 đơn vị)
        //   Ngón gập  → < bentThreshold (tip co lại gần mcp, giảm mcpTipDist)
        // dipDipRatio = mcpTipDist / dipTipDist (bổ sung khi DIP bị che khi gập)
        //   Ngón thẳng → ~1.5  (3 đốt so 2 đốt)
        //   Ngón gập  → < 1.2  (tip co vào, giảm mcpTipDist)
        val bentRatio = if (pipTipDist > 1e-6f) mcpTipDist / pipTipDist else Float.MAX_VALUE
        val dipDipRatio = if (dipTipDist > 1e-6f) mcpTipDist / dipTipDist else Float.MAX_VALUE

        // ── 3. Axis direction: PIP → TIP (stable hơn DIP → TIP) ───────────
        // Dùng PIP→TIP vì DIP có thể bị che khi ngón gập, PIP ổn định hơn.
        val axisDx = tip.x() - pip.x()
        val axisDy = tip.y() - pip.y()
        val axisDz = (tip.z() - pip.z()).coerceIn(-1f, 1f)
        val axisLen = sqrt(axisDx * axisDx + axisDy * axisDy + axisDz * axisDz)
        val normAxisDx = if (axisLen > 1e-6f) axisDx / axisLen else 0f
        val normAxisDy = if (axisLen > 1e-6f) axisDy / axisLen else 0f
        val normAxisDz = if (axisLen > 1e-6f) axisDz / axisLen else 0f

        // ── 3b. Fold angle: MCP→WRIST vs MCP→PIP ───────────────────────────
        val wrist = landmark[0]
        val wristToMcpX = mcp.x() - wrist.x()
        val wristToMcpY = mcp.y() - wrist.y()
        val wristToMcpZ = (mcp.z() - wrist.z()).coerceIn(-1f, 1f)
        val wristToMcpLen = sqrt(wristToMcpX * wristToMcpX + wristToMcpY * wristToMcpY + wristToMcpZ * wristToMcpZ)
        val normWristToMcpDx = if (wristToMcpLen > 1e-6f) wristToMcpX / wristToMcpLen else 0f
        val normWristToMcpDy = if (wristToMcpLen > 1e-6f) wristToMcpY / wristToMcpLen else 0f
        val normWristToMcpDz = if (wristToMcpLen > 1e-6f) wristToMcpZ / wristToMcpLen else 0f

        val mcpToPipX = pip.x() - mcp.x()
        val mcpToPipY = pip.y() - mcp.y()
        val mcpToPipZ = (pip.z() - mcp.z()).coerceIn(-1f, 1f)
        val mcpToPipLen = sqrt(mcpToPipX * mcpToPipX + mcpToPipY * mcpToPipY + mcpToPipZ * mcpToPipZ)
        val normMcpToPipDx = if (mcpToPipLen > 1e-6f) mcpToPipX / mcpToPipLen else 0f
        val normMcpToPipDy = if (mcpToPipLen > 1e-6f) mcpToPipY / mcpToPipLen else 0f
        val normMcpToPipDz = if (mcpToPipLen > 1e-6f) mcpToPipZ / mcpToPipLen else 0f

        val dot = normMcpToPipDx * normWristToMcpDx +
                  normMcpToPipDy * normWristToMcpDy +
                  normMcpToPipDz * normWristToMcpDz
        val foldAngleDeg = Math.toDegrees(acos(dot.coerceIn(-1f, 1f).toDouble())).toFloat()

        // ── 4. Nail ROI (pixel-space) ──────────────────────────────────────
        // TIP landmark = vị trí đầu ngón → làm center của móng
        val nailCenterX = tip.x() * imageW * sf
        val nailCenterY = tip.y() * imageH * sf

        // Rotation: atan2 của axis direction → góc ngón tay
        // +90° để align với hướng "đầu ngón chỉ lên" sau khi canvas.rotate
        val rotationDeg = Math.toDegrees(atan2(normAxisDy.toDouble(), normAxisDx.toDouble())).toFloat() + 90f

        // Nail height dựa trên shape ratio + length config
        val fingerLenPx = pipTipDist * min(imageW, imageH) * sf
        val nailHeightPx = fingerLenPx * 1.2f * nailSetConfig.length * 1.5f

        // Nail width: dùng trực tiếp mcpPipDist làm nail width (thay vì fingerWidthPx×2)
        // vì nail có chiều rộng tương đương khoảng cách MCP→PIP.
        // WIDE check sẽ so sánh nailWidthPx / mcpPipDist — nếu nail vẽ rộng hơn
        // khoảng cách MCP→PIP quá nhiều → skip.
        val nailWidthPx = mcpPipDist * min(imageW.toFloat(), imageH.toFloat()) * sf

        // ── 5. Physical rule checks (mode-aware thresholds) ───────────────────
        // Bent detection: PRIMARY = foldAngleDeg (geometric direction).
        // SECONDARY = bentRatio && dipDipRatio (distance-based, backup when foldAngle ambiguous).
        //
        // foldAngleDeg = angle between MCP→WRIST and MCP→PIP:
        //   Bent finger: points toward palm → MCP→PIP ≈ MCP→WRIST direction → angle ~30–60°
        //   Extended finger: points away from palm → opposite directions → angle ~90–150°
        // Distance ratios serve as secondary confirmation: bent fingers have
        // smaller mcpTipDist (tip close to MCP) → ratio drops below threshold.
        val foldBentThresh = if (isSnapshot) SNAP_FOLD_BENT_ANGLE else FOLD_BENT_ANGLE
        val distBentThresh  = if (isSnapshot) SNAP_BENT_RATIO_THRESHOLD  else BENT_RATIO_THRESHOLD
        val distDipThresh   = if (isSnapshot) SNAP_DIP_RATIO_THRESHOLD   else DIP_RATIO_THRESHOLD

        val isBent = if (isSnapshot) {
            // Snapshot: fold angle là primary signal, ratio là backup.
            // Ngón gập sẽ có foldAngle lớn (> 90°).
            foldAngleDeg > foldBentThresh ||
            (bentRatio < distBentThresh && dipDipRatio < distDipThresh)
        } else {
            // Live mode: yêu cầu cả 3 — tránh false-positive do jitter frame.
            foldAngleDeg > foldBentThresh &&
            bentRatio < distBentThresh &&
            dipDipRatio < distDipThresh
        }

        // ── CURL DETECTION (Snapshot only) ──────────────────────────────────────────────
        // Khi ngón gập, TIP cuộn về phía lòng bàn tay — khoảng cách WRIST→TIP
        // không vượt WRIST→MCP × SNAP_CURL_RATIO.
        // Bỏ qua thumb (fingerIndex == 0) vì cấu trúc thumb khác, ratio tự nhiên nhỏ.
        //
        // wristTipDist / wristMcpDist:
        //   Ngón thẳng:   ~1.5–2.5
        //   Gập vừa:    ~1.1–1.3
        //   Gập hẳn:    ~0.7–1.0
        val wristTipDist  = euclidean3d(wrist, tip)
        val wristMcpDist  = euclidean3d(wrist, mcp)
        val isCurled = isSnapshot &&
                       fingerIndex != 0 &&
                       wristMcpDist > 1e-6f &&
                       (wristTipDist / wristMcpDist) < SNAP_CURL_RATIO

        // Nail width check: nail không được rộng hơn MCP→PIP quá nhiều.
        // Trong thực tế nail luôn rộng hơn MCP→PIP một chút (nail bao quanh ngón).
        // Dùng ratio = nailWidthPx / nailWidthRef, với nailWidthRef = mcpPipDist * imageSize * sf.
        // Threshold 1.8: nail rộng tối đa ~1.8× khoảng cách MCP→PIP.
        // Snapshot mode: bỏ check này vì ảnh chụp có thể bị perspective distortion.
        val nailWidthRefPx = mcpPipDist * min(imageW.toFloat(), imageH.toFloat()) * sf
        val nailToNailRefRatio = if (nailWidthRefPx > 1e-3f) nailWidthPx / nailWidthRefPx else Float.MAX_VALUE
        val isNailTooWide = !isSnapshot && nailToNailRefRatio > MAX_NAIL_TO_FINGER_WIDTH_RATIO

        // Occlusion check: nếu DIP z-depth khác PIP z-depth nhiều → DIP bị che
        // Snapshot mode: dùng ngưỡng chặt hơn (SNAP_DEPTH_GAP) nhưng vẫn check
        val depthThreshold = if (isSnapshot) SNAP_DEPTH_GAP else MAX_DEPTH_GAP
        val depthGap = kotlin.math.abs(dip.z() - pip.z())
        val isOccluded = depthGap > depthThreshold

        // Stability check: chỉ dùng trong Live mode.
        // Trong Snapshot (isSnapshot=true), MediaPipe IMAGE mode trả visibility gần 0
        // cho tất cả landmark kể cả ngón nhìn thấy rõ — nên check này sẽ false-positive.
        // Visibility filtering trong Snapshot đã được thực hiện bởng SNAP_VISIBILITY
        // ở bước visibility guard bên ngoài (trong drawNails), không cần check lại ở đây.
        val visThreshold = if (isSnapshot) SNAP_VISIBILITY else MIN_LANDMARK_VISIBILITY
        val tipVis   = tip.visibility().orElse(1f)
        val pipVis   = pip.visibility().orElse(1f)
        val dipVis   = dip.visibility().orElse(1f)
        val isUnstable = if (isSnapshot) {
            tipVis < visThreshold && pipVis < visThreshold && dipVis < visThreshold
        } else {
            tipVis < visThreshold || pipVis < visThreshold || dipVis < visThreshold
        }

        // Minimum length check cho Snapshot: loại ngón quá ngắn (gập gần như biến mất)
        val isTooShort = isSnapshot && pipTipDist < SNAP_MIN_PIPTIP_LENGTH

        // Tổng hợp skip reason
        val skipReason: String? = when {
            isBent       -> SkipReason.BENT.code
            isNailTooWide-> SkipReason.WIDE_NAIL.code
            isOccluded   -> SkipReason.OCCLUDED.code
            isUnstable   -> SkipReason.UNSTABLE.code
            isTooShort   -> SkipReason.SHORT.code
            else         -> null
        }

        if (DEBUG_LOG && skipReason != null) {
            Log.v(TAG, "  SKIP [${skipReason}] ${FingerMetrics.FINGER_NAMES[fingerIndex]}: " +
                "bentRatio=${String.format("%.3f", bentRatio)} " +
                "dipDipRatio=${String.format("%.3f", dipDipRatio)} " +
                "foldAngle=${String.format("%.1f", foldAngleDeg)}° " +
                "depthGap=${String.format("%.3f", depthGap)} " +
                "tipVis=${String.format("%.2f", tipVis)}")
        }

        return FingerMetrics(
            fingerIndex      = fingerIndex,
            mcpTipDist       = mcpTipDist,
            pipTipDist       = pipTipDist,
            dipTipDist       = dipTipDist,
            mcpPipDist       = mcpPipDist,
            bentRatio        = bentRatio,
            dipDipRatio      = dipDipRatio,
            axisDx           = normAxisDx,
            axisDy           = normAxisDy,
            axisDz           = normAxisDz,
            foldAngleDeg    = foldAngleDeg,
            nailCenterX      = nailCenterX,
            nailCenterY      = nailCenterY,
            nailWidthPx      = nailWidthPx,
            nailHeightPx     = nailHeightPx,
            rotationDeg      = rotationDeg,
            isBent           = isBent,
            isCurled         = isCurled,
            isNailTooWide    = isNailTooWide,
            isOccluded       = isOccluded,
            isUnstable       = isUnstable,
            skipReason       = skipReason,
        )
    }

    companion object {
        private const val LANDMARK_STROKE_WIDTH = 3F // Now treated as DP
        private const val FingerColorFallback = "#FF4081"
        private const val NAIL_LANDMARK_WIDTH_SCALE = 2.5F
        private const val NAIL_LANDMARK_HEIGHT_SCALE = 1.5F
    }
}
