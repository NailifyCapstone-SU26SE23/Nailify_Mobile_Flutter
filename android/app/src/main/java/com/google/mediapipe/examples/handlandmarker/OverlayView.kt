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
import com.google.mediapipe.examples.handlandmarker.utils.OneEuroFilter
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
import org.json.JSONObject
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

    // ---------------------------------------------------------------------------
    // Manual offsets — giá trị bù trừ thủ công do người dùng điều chỉnh từ Flutter.
    // Được cộng vào sau khi bộ lọc 1€ đã làm mượt tọa độ Landmark.
    // ---------------------------------------------------------------------------
    @Volatile private var manualOffsetX: Float = 0f
    @Volatile private var manualOffsetY: Float = 0f
    @Volatile private var manualScale: Float = 1f
    @Volatile private var manualRotation: Float = 0f

    /**
     * Cập nhật các giá trị bù trừ thủ công gửi từ Flutter qua MethodChannel.
     * Hàm này an toàn khi được gọi từ bất kỳ thread nào nhờ @Volatile.
     */
    fun updateManualOffsets(
        offsetX: Float = 0f,
        offsetY: Float = 0f,
        scale: Float = 1f,
        rotation: Float = 0f
    ) {
        manualOffsetX = offsetX
        manualOffsetY = offsetY
        manualScale = scale
        manualRotation = rotation
        // Không cần invalidate() ở đây — onDraw() sẽ đọc giá trị mới ở frame tiếp theo.
    }

    // ---------------------------------------------------------------------------
    // One Euro Filters — mỗi ngón tay có 1 filter riêng cho X và Y.
    //
    // Tham số được chọn dựa trên đặc điểm chuyển động tay khi làm móng:
    //   minCutoff = 0.5  → đủ mượt khi tay đứng yên, loại bỏ jitter nhỏ (~2-4px).
    //   beta      = 0.05 → phản ứng đủ nhanh khi tay di chuyển, tránh "bóng ma".
    //   dCutoff   = 1.0  → cố định cho filter đạo hàm (không cần thay đổi).
    //   freq      = 30f  → ước tính 30FPS; filter tự điều chỉnh theo dt thực tế.
    //
    // Tham số chống lag:
    //   minCutoff = 1.5  → tăng lên để filter phản ứng nhanh hơn khi đứng yên.
    //   beta      = 0.8  → tăng mạnh để giảm lag khi ngón tay di chuyển nhanh.
    //                       Với beta cao, cutoff tăng tỉ lệ thuận với vận tốc → gần như
    //                       không lọc khi di chuyển nhanh, nhưng vẫn mượt khi đứng yên.
    // ---------------------------------------------------------------------------
    private val filtersX = Array(5) { OneEuroFilter(freq = 30f, minCutoff = 1.5f, beta = 0.8f) }
    private val filtersY = Array(5) { OneEuroFilter(freq = 30f, minCutoff = 1.5f, beta = 0.8f) }

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
        // Reset bộ lọc để tránh ghost value khi tracking bị mất và phục hồi
        filtersX.forEach { it.reset() }
        filtersY.forEach { it.reset() }
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
        // Live mode: scaleFactor đã được tính sẵn bởi setResults()
        drawNails(canvas, scaleFactor, applyFilters = true)
    }

    /**
     * Vẽ móng lên bất kỳ Canvas nào với scaleFactor tuỳ chỉnh.
     *
     * Được gọi bởi:
     *   - draw()          → Live mode  (scaleFactor từ View size, có 1€ Filter)
     *   - renderOnBitmap() → Snapshot mode (scaleFactor từ bitmap size, không filter)
     *
     * @param canvas        Canvas đích để vẽ
     * @param sf            scaleFactor tương ứng với không gian tọa độ của canvas
     * @param applyFilters  true = dùng 1€ Filter (Live), false = dùng raw coords (Snapshot)
     */
    private fun drawNails(canvas: Canvas, sf: Float, applyFilters: Boolean) {
        val result = results ?: return
        val now = System.currentTimeMillis()

        for (landmark in result.landmarks()) {
            val fingerTips = listOf(4, 8, 12, 16, 20)

            for ((fingerIndex, tipIndex) in fingerTips.withIndex()) {
                val tip   = landmark[tipIndex]
                val joint = landmark[tipIndex - 1]

                // Visibility guard — chỉ áp dụng cho Live mode để tránh ghost nail
                if (applyFilters) {
                    val tipVisibility = tip.visibility().orElse(1f)
                    if (tipVisibility < VISIBILITY_THRESHOLD) {
                        filtersX[fingerIndex].reset()
                        filtersY[fingerIndex].reset()
                        continue
                    }
                }

                val design = nailSetConfig.nails.getOrNull(fingerIndex)
                    ?: nailSetConfig.nails.firstOrNull()
                    ?: continue

                // Tọa độ pixel trên canvas
                val rawPx = tip.x()   * imageWidth  * sf
                val rawPy = tip.y()   * imageHeight * sf
                val rawJx = joint.x() * imageWidth  * sf
                val rawJy = joint.y() * imageHeight * sf

                // 1€ Filter — chỉ áp dụng cho Live mode
                val finalPx: Float
                val finalPy: Float
                if (applyFilters) {
                    finalPx = filtersX[fingerIndex].filter(rawPx, now) + manualOffsetX
                    finalPy = filtersY[fingerIndex].filter(rawPy, now) + manualOffsetY
                } else {
                    finalPx = rawPx
                    finalPy = rawPy
                }

                val angle = Math.toDegrees(
                    atan2((finalPy - rawJy).toDouble(), (finalPx - rawJx).toDouble())
                ).toFloat()

                val fingerLength = hypot(
                    (finalPx - rawJx).toDouble(),
                    (finalPy - rawJy).toDouble()
                ).toFloat()

                val finalAngle = angle + if (applyFilters) manualRotation else 0f

                canvas.withTranslation(finalPx, finalPy) {
                    rotate(finalAngle + 90f)

                    val customShapeBitmap = loadBitmapFromUri(design.customShapeSrc)
                    val shapeImageBitmap  = loadBitmapFromUri(nailSetConfig.shapeImageSrc)
                    val nailBitmap = customShapeBitmap
                        ?: shapeImageBitmap
                        ?: getShapeBitmap(nailSetConfig.shape)

                    nailBitmap?.let { bitmap ->
                        val scaleMultiplier = if (applyFilters) manualScale else 1f

                        val baseNailWidth  = fingerLength * 2f
                        val baseNailHeight = fingerLength * 1.2f * nailSetConfig.length
                        val nailBottom  = fingerLength * 0.75f
                        val totalHeight = baseNailHeight * 1.5f

                        val nailWidth  = baseNailWidth  * scaleMultiplier
                        val nailHeight = totalHeight    * scaleMultiplier

                        val destRect = RectF(
                            -nailWidth / 2,
                            nailBottom - nailHeight,
                            nailWidth / 2,
                            nailBottom
                        )

                        if (customShapeBitmap == null) {
                            drawNailBase(
                                this, bitmap, destRect,
                                createNailPaint(
                                    design.color,
                                    design.gradient ?: nailSetConfig.gradient,
                                    destRect
                                )
                            )
                        } else {
                            drawBitmap(bitmap, null, destRect, null)
                        }

                        drawNailSurface(this, bitmap, destRect)

                        design.decorations.forEach { decoration ->
                            drawDecoration(this, decoration, destRect)
                        }
                    }
                }
            }
        }
    }

    /**
     * Snapshot mode: vẽ toàn bộ móng AR lên bitmap tuỳ chỉnh.
     *
     * Dùng chung 100% thuật toán render với Live mode (qua drawNails()),
     * nhưng tính scaleFactor từ kích thước bitmap thay vì kích thước View.
     *
     * PHẢI được gọi trên main thread.
     *
     * @param targetBitmap  Bitmap mutable để vẽ lên (ảnh chụp từ camera)
     * @param result        Kết quả MediaPipe IMAGE mode
     * @param imgW          Chiều rộng ảnh gốc mà MediaPipe đã phân tích
     * @param imgH          Chiều cao ảnh gốc mà MediaPipe đã phân tích
     */
    /**
     * Snapshot mode: vẽ toàn bộ móng AR lên bitmap tuỳ chỉnh.
     *
     * PHẢI được gọi từ background thread vì preloadAllBitmapsSync() thực hiện
     * network call để tải decoration images một cách đồng bộ.
     *
     * @param targetBitmap  Bitmap mutable để vẽ lên (ảnh chụp từ camera)
     * @param result        Kết quả MediaPipe IMAGE mode
     * @param imgW          Chiều rộng ảnh gốc mà MediaPipe đã phân tích
     * @param imgH          Chiều cao ảnh gốc mà MediaPipe đã phân tích
     */
    fun renderOnBitmap(
        targetBitmap: Bitmap,
        result: com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult,
        imgW: Int,
        imgH: Int
    ) {
        // Caller (CameraFragment) is responsible for calling preloadAllBitmapsForSnapshot()
        // on a background thread BEFORE calling this method, so all bitmaps are
        // guaranteed to be in bitmapCache when drawNails() runs.
        val sf = min(
            targetBitmap.width.toFloat()  / imgW.toFloat(),
            targetBitmap.height.toFloat() / imgH.toFloat()
        )

        // Lưu trạng thái cũ để không ảnh hưởng Live mode
        val prevResults     = results
        val prevImageWidth  = imageWidth
        val prevImageHeight = imageHeight
        val prevScaleFactor = scaleFactor

        results     = result
        imageWidth  = imgW
        imageHeight = imgH
        scaleFactor = sf

        val canvas = android.graphics.Canvas(targetBitmap)
        drawNails(canvas, sf, applyFilters = false)

        // Restore để Live mode không bị ảnh hưởng
        results     = prevResults
        imageWidth  = prevImageWidth
        imageHeight = prevImageHeight
        scaleFactor = prevScaleFactor
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

    /**
     * Tải bitmap KHÔNG đồng bộ (async) — dùng cho Live mode.
     * Lần gọi đầu trả null và kích hoạt tải nền; các frame tiếp theo trả cache.
     */
    private fun loadBitmapFromUri(uriString: String?): Bitmap? {
        if (uriString == null) return null
        if (bitmapCache.containsKey(uriString)) return bitmapCache[uriString]
        if (!loadingBitmaps.add(uriString)) return null
        Thread {
            val bitmap = fetchBitmapBlocking(uriString)
            post {
                bitmapCache[uriString] = bitmap
                loadingBitmaps.remove(uriString)
                invalidate()
            }
        }.start()
        return null
    }

    /**
     * Tải bitmap ĐỒNG BỘ (blocking) — dùng cho Snapshot mode.
     * Trả về bitmap ngay lập tức; kết quả được lưu vào cache cho Live mode sau này.
     * PHẢI được gọi từ background thread (không phải main thread).
     */
    private fun loadBitmapSync(uriString: String?): Bitmap? {
        if (uriString == null) return null
        // Kiểm tra cache trước
        bitmapCache[uriString]?.let { return it }
        val bitmap = fetchBitmapBlocking(uriString)
        // Lưu vào cache để dùng lại
        bitmapCache[uriString] = bitmap
        loadingBitmaps.remove(uriString)
        return bitmap
    }

    /** Thực sự tải bitmap từ URL/URI — dùng chung cho cả async và sync. */
    private fun fetchBitmapBlocking(uriString: String): Bitmap? {
        return try {
            if (uriString.startsWith("http://") || uriString.startsWith("https://")) {
                URL(uriString).openStream().use { BitmapFactory.decodeStream(it) }
            } else {
                val uri = android.net.Uri.parse(uriString)
                context.contentResolver.openInputStream(uri)?.use { inputStream ->
                    BitmapFactory.decodeStream(inputStream)
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Preload tất cả bitmap cần thiết cho Snapshot mode một cách ĐỒNG BỘ.
     *
     * PHẢI được gọi từ background/worker thread (ví dụ: backgroundExecutor)
     * BEFORE gọi renderOnBitmap(). Không gọi trên main thread — sẽ bị StrictMode.
     */
    fun preloadAllBitmapsForSnapshot(config: NailSetConfig) {
        loadBitmapSync(config.shapeImageSrc)
        config.nails.forEach { design ->
            loadBitmapSync(design.customShapeSrc)
            design.decorations.forEach { decoration ->
                loadBitmapSync(decoration.imageSrc)
            }
        }
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
        val surfaceColor = applySurfaceOffsets(baseColor)
        return Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = if (gradient?.enabled == true) {
                createGradientShader(gradient, nailBounds)
            } else {
                createMaterialShader(surfaceColor, nailBounds)
            }
            if (shader == null) {
                color = when (nailSetConfig.material) {
                    NailSetConfig.MATERIAL_MATTE -> adjustColor(surfaceColor, saturation = 0.55f, brightness = 0.9f)
                    else -> surfaceColor
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
            .map(::applySurfaceOffsets)
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
        hsv[0] = ((hsv[0] + surface.hueOffset) % 360f + 360f) % 360f
        hsv[1] = (hsv[1] + surface.saturationOffset).coerceIn(0f, 1f)
        hsv[2] = (hsv[2] + surface.lightnessOffset).coerceIn(0f, 1f)
        return Color.HSVToColor(Color.alpha(color), hsv)
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

        /**
         * Ngưỡng visibility để quyết định có render móng hay không.
         * MediaPipe trả về visibility trong [0.0, 1.0]:
         *   > 0.5 → ngón tay nhìn thấy được → render móng.
         *   ≤ 0.5 → ngón gập hoặc khuất     → bỏ qua + reset filter.
         * Giảm giá trị nếu muốn móng ẩn sớm hơn, tăng nếu muốn móng ở lại lâu hơn.
         */
        private const val VISIBILITY_THRESHOLD = 0.5f
    }
}
