package com.google.mediapipe.examples.handlandmarker

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import androidx.core.content.ContextCompat
import com.google.mediapipe.examples.handlandmarker.model.NailDecoration
import com.google.mediapipe.examples.handlandmarker.model.NailSetConfig
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import kotlin.math.max
import kotlin.math.min
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.LinearGradient
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import androidx.core.graphics.withTranslation
import java.net.URL
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.roundToInt

class OverlayView(context: Context?, attrs: AttributeSet?) :
    View(context, attrs) {

    private var results: HandLandmarkerResult? = null
    private var linePaint = Paint()
    private var pointPaint = Paint()
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
        results = null
        linePaint.reset()
        pointPaint.reset()
        invalidate()
        initPaints()
    }

    private fun initPaints() {
        linePaint.color =
            ContextCompat.getColor(context!!, R.color.mp_color_primary)
        linePaint.strokeWidth = LANDMARK_STROKE_WIDTH
        linePaint.style = Paint.Style.STROKE

        pointPaint.color = Color.YELLOW
        pointPaint.strokeWidth = LANDMARK_STROKE_WIDTH
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

                    val px = tip.x() * imageWidth * scaleFactor
                    val py = tip.y() * imageHeight * scaleFactor
                    
                    val jx = joint.x() * imageWidth * scaleFactor
                    val jy = joint.y() * imageHeight * scaleFactor

                    val angle = Math.toDegrees(atan2((py - jy).toDouble(), (px - jx).toDouble())).toFloat()

                    val fingerLength = hypot((px - jx).toDouble(), (py - jy).toDouble()).toFloat()

                    canvas.withTranslation(px, py) {
                        rotate(angle + 90f) // Rotate to match finger direction

                        val customShapeBitmap = loadBitmapFromUri(design.customShapeSrc)
                        val shapeImageBitmap = loadBitmapFromUri(nailSetConfig.shapeImageSrc)
                        val nailBitmap = customShapeBitmap
                            ?: shapeImageBitmap
                            ?: getShapeBitmap(nailSetConfig.shape)

                        nailBitmap?.let { bitmap ->
                            val nailWidth = fingerLength * 2f
                            val nailHeight = fingerLength * 1.2f * nailSetConfig.length

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
            }
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
        invalidate()
    }

    fun setFullDesign(config: NailSetConfig) {
        if (nailSetConfig == config) return
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
                createMaterialShader(baseColor, nailBounds)
            }
            if (shader == null) {
                color = when (nailSetConfig.material) {
                    NailSetConfig.MATERIAL_MATTE -> adjustColor(baseColor, saturation = 0.55f, brightness = 0.9f)
                    else -> baseColor
                }
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

    companion object {
        private const val LANDMARK_STROKE_WIDTH = 8F
        private const val FingerColorFallback = "#FF4081"
    }
}
