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
import com.google.mediapipe.examples.handlandmarker.utils.OneEuroFilter
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
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
    private var ballerinaBitmap: Bitmap? = null
    private var squovalBitmap: Bitmap? = null
    private var stilettoBitmap: Bitmap? = null

    private var nailSetConfig: NailSetConfig = NailSetConfig.default()
    private val bitmapCache = mutableMapOf<String, Bitmap?>()
    private val loadingBitmaps = mutableSetOf<String>()

    private var scaleFactor: Float = 1f
    fun getScaleFactor(): Float = scaleFactor
    fun getImageWidth(): Int  = imageWidth
    fun getImageHeight(): Int = imageHeight
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

    // Anchor filters: dùng riêng cho MCP anchor (polygon-based rendering).
    // Tách khỏi TIP filter để tránh filter state bị "nhiễm" giữa 2 vị trí khác nhau
    // trên cùng 1 finger — vì TIP và MCP là 2 điểm khác nhau, dùng chung filter sẽ
    // làm filter nghĩ tay "nhảy" từ TIP sang MCP giữa frame, gây giật + sai vị trí.
    private val anchorFiltersX = Array(5) { OneEuroFilter(freq = 30f, minCutoff = 1.5f, beta = 0.8f) }
    private val anchorFiltersY = Array(5) { OneEuroFilter(freq = 30f, minCutoff = 1.5f, beta = 0.8f) }

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
        filtersX.forEach { it.reset() }
        filtersY.forEach { it.reset() }
        anchorFiltersX.forEach { it.reset() }
        anchorFiltersY.forEach { it.reset() }
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
        val result = results
        if (result == null) {
            PipelineLogger.metaNoResults()
            return
        }

        val now = System.currentTimeMillis()

        val filterStr = if (applyFilters) "LIVE" else "SNAP"
        PipelineLogger.metaDrawNails(applyFilters, sf, result.landmarks().size)
        if (DEBUG_LOG) Log.v(TAG, "drawNails: applyFilters=$applyFilters scaleFactor=$sf imageSize=${imageWidth}x${imageHeight}")

        val stats = mutableMapOf<String, Int>()

        for ((handIdx, landmark) in result.landmarks().withIndex()) {
            // ── FIST DETECTION (Snapshot only) ───────────────────────────────────
            // Nếu ≥ 3 ngón bị bent → có thể là nắm đấm → skip toàn bộ hand
            if (!applyFilters) {
                val bentCount = (0..4).count { fi ->
                    val tipIdx = FingerMetrics.FINGER_TIPS[fi]
                    val pipIdx = FingerMetrics.FINGER_PIPS[fi]
                    val mcpIdx = FingerMetrics.FINGER_MCPS[fi]
                    val pipTip = euclidean3d(landmark[pipIdx], landmark[tipIdx])
                    val mcpTip = euclidean3d(landmark[mcpIdx], landmark[tipIdx])
                    if (pipTip > 1e-6f) mcpTip / pipTip < SNAP_BENT_RATIO_THRESHOLD else false
                }
                if (bentCount >= 3) {
                    stats["FIST"] = (stats["FIST"] ?: 0) + 1
                    if (DEBUG_LOG) Log.w(TAG, "  FIST DETECTED hand=$handIdx bentCount=$bentCount — skipping entire hand")
                    PipelineLogger.log(PipelineLogger.METRICS, 1) { "FIST hand=$handIdx bentCount=$bentCount → SKIP entire hand" }
                    filtersX.forEach { it.reset() }
                    filtersY.forEach { it.reset() }
                    anchorFiltersX.forEach { it.reset() }
                    anchorFiltersY.forEach { it.reset() }
                    continue  // Skip toàn bộ hand
                }
            }


            for (fingerIndex in 0..4) {
                val tipIdx = FingerMetrics.FINGER_TIPS[fingerIndex]


                // ── VISIBILITY GUARD ───────────────────────────────────────────────
                // Live mode: visibility dùng như primary signal để phát hiện ngón đang khứa.
                // Snapshot mode: visibility KHÔNG đáng tin cậy trong IMAGE mode
                // (MediaPipe luôn return 1 cho tất cả landmark, kể cả ngón bị gập).
                // Bent detection đã xử lý ngón gập bằng geometry — bỏ visibility guard ở đây.
                if (applyFilters) {
                    val tipVis = landmark[tipIdx].visibility().orElse(1f)
                    val visThreshold = MIN_LANDMARK_VISIBILITY
                    if (tipVis < visThreshold) {
                        PipelineLogger.log(PipelineLogger.METRICS, 2) {
                            "SKIP [LOW_VIS] hand=$handIdx ${FingerMetrics.FINGER_NAMES[fingerIndex]}: vis=${String.format("%.2f", tipVis)} < $visThreshold"
                        }
                        filtersX[fingerIndex].reset()
                        filtersY[fingerIndex].reset()
                        continue  // Ngón không visible — skip
                    }
                }

                // ── COMPUTE METRICS (mode-aware thresholds) ──────────────────────
                val metrics: FingerMetrics
                try {
                    val tipVis = landmark[tipIdx].visibility().orElse(1f)
                    PipelineLogger.metricsEntry(
                        FingerMetrics.FINGER_NAMES[fingerIndex],
                        fingerIndex,
                        landmark[tipIdx].x(),
                        landmark[tipIdx].y(),
                        landmark[tipIdx].z(),
                        tipVis
                    )
                    metrics = computeFingerMetrics(fingerIndex, landmark, sf, imageWidth, imageHeight, !applyFilters)
                    PipelineLogger.metricsComputed(
                        FingerMetrics.FINGER_NAMES[fingerIndex],
                        fingerIndex,
                        metrics.mcpTipDist,
                        metrics.pipTipDist,
                        metrics.bentRatio,
                        metrics.dipDipRatio,
                        metrics.foldAngleDeg,
                        metrics.isBent,
                        metrics.skipReason
                    )
                } catch (e: IndexOutOfBoundsException) {
                    if (DEBUG_LOG) Log.w(TAG, "  SKIP [MISS] hand=$handIdx finger=$fingerIndex: landmark index out of bounds")
                    PipelineLogger.log(PipelineLogger.METRICS, 2) { "SKIP [MISS] hand=$handIdx finger=$fingerIndex: IndexOutOfBoundsException" }
                    stats["MISS"] = (stats["MISS"] ?: 0) + 1
                    filtersX[fingerIndex].reset()
                    filtersY[fingerIndex].reset()
                    anchorFiltersX[fingerIndex].reset()
                    anchorFiltersY[fingerIndex].reset()
                    continue
                }

                // ── PHYSICAL RULE CHECKS ─────────────────────────────────────────
                // Live mode (applyFilters=true): chạy tất cả physical checks.
                // Snapshot mode (applyFilters=false): bỏ qua — computeFingerMetrics
                // đã dùng threshold phù hợp cho từng mode (SNAP_* vs live thresholds).
                // Cần giữ guard này, nếu không physical checks sẽ chạy cả trong Snapshot
                // và tạo ra false-positive UNSTABLE/OCCLUDED làm mất hết móng.
                val skipReason = metrics.skipReason
                if (applyFilters && skipReason != null) {
                    stats[skipReason] = (stats[skipReason] ?: 0) + 1
                    PipelineLogger.bentSkipDetailed(
                        FingerMetrics.FINGER_NAMES[fingerIndex],
                        metrics.foldAngleDeg,
                        metrics.bentRatio,
                        metrics.dipDipRatio,
                        FOLD_BENT_ANGLE,
                        BENT_RATIO_THRESHOLD,
                        DIP_RATIO_THRESHOLD
                    )
                    filtersX[fingerIndex].reset()
                    filtersY[fingerIndex].reset()
                    anchorFiltersX[fingerIndex].reset()
                    anchorFiltersY[fingerIndex].reset()
                    continue
                }

                // ── SNAPSHOT STRICT FILTER ─────────────────────────────────────────
                // Snapshot mode: áp dụng TẤT CẢ skip signals từ computeFingerMetrics
                // (isBent, isOccluded, isTooShort) cộng thêm isCurled.
                // Nếu BẤT KỲ signal nào trigger → ẩn móng ngón đó.
                if (!applyFilters) {
                    val snapSkipReason: String? = when {
                        skipReason != null    -> skipReason   // isBent, isOccluded, isTooShort, isUnstable
                        metrics.isCurled      -> "CURL"       // wristTipDist signal (riêng, không trong skipReason)
                        else                  -> null
                    }
                    if (snapSkipReason != null) {
                        stats[snapSkipReason] = (stats[snapSkipReason] ?: 0) + 1
                        if (DEBUG_LOG) Log.v(TAG, "  SKIP [$snapSkipReason] hand=$handIdx " +
                            "${FingerMetrics.FINGER_NAMES[fingerIndex]}: " +
                            "bent=${metrics.isBent} curled=${metrics.isCurled} " +
                            "occluded=${metrics.isOccluded} " +
                            "bentRatio=${String.format("%.3f", metrics.bentRatio)} " +
                            "foldAngle=${String.format("%.1f", metrics.foldAngleDeg)}°")
                        continue
                    }
                }

                // ── DESIGN LOOKUP ─────────────────────────────────────────────────
                val design = nailSetConfig.nails.getOrNull(fingerIndex)
                    ?: nailSetConfig.nails.firstOrNull()
                if (design == null) {
                    stats[SkipReason.NO_DESIGN.code] = (stats[SkipReason.NO_DESIGN.code] ?: 0) + 1
                    if (DEBUG_LOG) Log.w(TAG, "  SKIP [NDES] hand=$handIdx ${FingerMetrics.FINGER_NAMES[fingerIndex]}: no nail design")
                    continue
                }

                // ── FILTERED COORDINATES ──────────────────────────────────────────
                val rawPx = metrics.nailCenterX
                val rawPy = metrics.nailCenterY

                val finalPx: Float
                val finalPy: Float
                if (applyFilters) {
                    val filteredX = filtersX[fingerIndex].filter(rawPx, now)
                    val filteredY = filtersY[fingerIndex].filter(rawPy, now)
                    finalPx = filteredX + manualOffsetX
                    finalPy = filteredY + manualOffsetY
                    PipelineLogger.filterApplied(
                        FingerMetrics.FINGER_NAMES[fingerIndex],
                        rawPx, rawPy,
                        filteredX, filteredY,
                        filteredX - rawPx,
                        filteredY - rawPy
                    )
                } else {
                    finalPx = rawPx
                    finalPy = rawPy
                }

                val rotation = if (applyFilters) {
                    metrics.rotationDeg + manualRotation
                } else {
                    metrics.rotationDeg
                }

                // ── NAIL BITMAP ──────────────────────────────────────────────────
                val customShapeBitmap = loadBitmapFromUri(design.customShapeSrc)
                val shapeImageBitmap  = loadBitmapFromUri(nailSetConfig.shapeImageSrc)
                val nailBitmap = customShapeBitmap ?: shapeImageBitmap ?: getShapeBitmap(nailSetConfig.shape)

                if (nailBitmap == null) {
                    stats[SkipReason.NO_BITMAP.code] = (stats[SkipReason.NO_BITMAP.code] ?: 0) + 1
                    if (DEBUG_LOG) Log.w(TAG, "  SKIP [NBMP] hand=$handIdx ${FingerMetrics.FINGER_NAMES[fingerIndex]}: nail bitmap not loaded")
                    continue
                }

                // ── NAIL DIMENSIONS ───────────────────────────────────────────────
                // Kích thước base từ finger geometry, scale multiplier từ user adjustment
                val scaleMultiplier = if (applyFilters) manualScale else 1f
                val fingerLenPx = metrics.pipTipDist * min(imageWidth, imageHeight) * sf

                // nailWidth: base trên finger width ước lượng, nhân 2 vì móng bao quanh ngón
                val baseNailWidth  = metrics.nailWidthPx
                val nailBottom  = fingerLenPx * 0.75f
                val totalHeight = fingerLenPx * 1.2f * nailSetConfig.length * 1.5f

                val nailWidth  = baseNailWidth  * scaleMultiplier
                val nailHeight = totalHeight    * scaleMultiplier

                val destRect = RectF(
                    -nailWidth / 2,
                    nailBottom - nailHeight,
                     nailWidth / 2,
                     nailBottom
                )

                // ── RENDER (TIP-based bitmap drawing) ─────────────────────────────
                canvas.withTranslation(finalPx, finalPy) {
                    canvas.save()
                    canvas.rotate(rotation, 0f, 0f)

                    drawNailBase(canvas, nailBitmap, destRect, createNailPaint(design.color, nailSetConfig.gradient, destRect))
                    drawNailSurface(canvas, nailBitmap, destRect)

                    for (decoration in design.decorations) {
                        drawDecoration(canvas, decoration, destRect)
                    }

                    canvas.restore()
                }

                stats["OK"] = (stats["OK"] ?: 0) + 1
                PipelineLogger.nailRendered(
                    FingerMetrics.FINGER_NAMES[fingerIndex],
                    finalPx, finalPy,
                    rotation,
                    nailWidth, nailHeight,
                    design.color,
                    design.decorations.size
                )
            }
        }

        if (DEBUG_LOG && stats.isNotEmpty()) {
            val summary = stats.entries.joinToString(" ") { "${it.key}=${it.value}" }
            Log.v(TAG, "drawNails done: $summary")
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
    fun renderOnBitmap(
        targetBitmap: Bitmap,
        result: com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult,
        imgW: Int,
        imgH: Int
    ) {
        PipelineLogger.metaSetResults(imgW, imgH, targetBitmap.width, targetBitmap.height, 1f)
        if (DEBUG_LOG) {
            Log.d(TAG, "renderOnBitmap START: bitmap=${targetBitmap.width}x${targetBitmap.height} " +
                "mpResultImageSize=${imgW}x${imgH} hands=${result.landmarks().size}")
        }

        // Reset filters — đảm bảo mỗi snapshot bắt đầu sạch
        filtersX.forEach { it.reset() }
        filtersY.forEach { it.reset() }
        anchorFiltersX.forEach { it.reset() }
        anchorFiltersY.forEach { it.reset() }

        val sf = min(
            targetBitmap.width.toFloat()  / imgW.toFloat(),
            targetBitmap.height.toFloat() / imgH.toFloat()
        )

        if (DEBUG_LOG) Log.v(TAG, "renderOnBitmap: scaleFactor=$sf")

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

        // Restore
        results     = prevResults
        imageWidth  = prevImageWidth
        imageHeight = prevImageHeight
        scaleFactor = prevScaleFactor

        if (DEBUG_LOG) Log.d(TAG, "renderOnBitmap END")
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
        // Formula: atan2(dy, dx) + 90° — giữ nguyên từ implementation gốc đã hoạt động đúng.
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
        private const val TAG = "NailifyOverlay"

        /** Log verbose khi debug pipeline. Đặt = false trong release để tránh spam logcat. */
        private const val DEBUG_LOG = true

        private const val LANDMARK_STROKE_WIDTH = 8F
        private const val FingerColorFallback = "#FF4081"

        // ─── GEOMETRY THRESHOLDS ───────────────────────────────────────────────

        /**
         * Ngưỡng geometry để phát hiện ngón gập.
         * Tính: ratio = dist(MCP, TIP) / dist(PIP, TIP)
         *   - Ngón thẳng: ratio ≈ 2.0 (vì 2 đốt xương MCP→PIP + PIP→TIP)
         *   - Ngón gập:   ratio < 1.2  (đầu ngón co gần MCP)
         */
        private const val BENT_RATIO_THRESHOLD = 1.2f

        /**
         * Ngưỡng tối đa cho phép nail width so với finger width.
         * Nếu nail width > finger width × MAX_NAIL_TO_FINGER_WIDTH_RATIO → skip.
         *
         * Ví dụ: nail width 80px, finger width 60px → ratio = 1.33 > 1.3 → skip.
         * Giá trị 1.3–1.5 là hợp lý; < 1.3 = strict, > 1.5 = loose.
         */
        private const val MAX_NAIL_TO_FINGER_WIDTH_RATIO = 1.3f

        /**
         * Ngưỡng visibility tối thiểu cho landmark để xem là "stable".
         * Landmark visibility < MIN_LANDMARK_VISIBILITY → coi là unstable.
         */
        private const val MIN_LANDMARK_VISIBILITY = 0.4f

        /**
         * Ngưỡng z-depth tối đa giữa DIP và PIP.
         * Nếu |z_DIP - z_PIP| > MAX_DEPTH_GAP → có thể DIP bị che bởi ngón khác.
         *
         * Giá trị z trong MediaPipe là depth tương đối: ngón phía trước camera
         * có z lớn hơn ngón phía sau. Khi ngón gập, DIP bị che bởi ngón khác
         * thì z của nó sẽ khác biệt rõ rệt với PIP.
         */
        private const val MAX_DEPTH_GAP = 0.10f

        /**
         * Ngưỡng fold angle (góc giữa MCP→WRIST và MCP→PIP) cho bent detection.
         * Extended finger: ngón thẳng, 2 vector cùng hướng → góc nhỏ (~0–30°).
         * Bent finger: ngón gập lại chỉ vào lòng bàn tay → góc lớn (> 90°).
         */
        private const val FOLD_BENT_ANGLE = 90f

        // ─── SNAPSHOT-ONLY THRESHOLDS ───────────────────────────────────────────
        // Stricter thresholds cho Snapshot mode vì không có temporal context.
        // Ngưỡng này chỉ dùng khi applyFilters=false.

        /** Bent ratio threshold stricter cho Snapshot. Ngón gập nhẹ cũng bị loại. */
        private const val SNAP_BENT_RATIO_THRESHOLD = 1.4f

        /**
         * DIP ratio threshold cho bent detection (snapshot mode).
         * Chỉ dùng KẾT HỢP với bentRatio — cả 2 phải trigger thì mới bent.
         * dipDipRatio = dist(MCP,TIP) / dist(MCP,DIP):
         *   Ngón thẳng → ~1.5 (3 đốt so 2 đốt)
         *   Ngón gập  → < 1.2 (DIP co vào gần MCP)
         */
        private const val SNAP_DIP_RATIO_THRESHOLD = 1.2f

        /** DIP ratio threshold cho bent detection (live mode). */
        private const val DIP_RATIO_THRESHOLD = 1.1f

        /**
         * Fold angle threshold stricter cho Snapshot mode.
         * Do góc chụp, ngón có thể trông hơi gập hơn, dùng ngưỡng 80° để dễ bắt ngón gập hơn.
         */
        private const val SNAP_FOLD_BENT_ANGLE = 80f

        /** Depth gap stricter cho Snapshot — phát hiện khuất tốt hơn. */
        private const val SNAP_DEPTH_GAP = 0.08f

        /** Visibility stricter cho Snapshot — bắt buộc landmark phải thực sự visible. */
        private const val SNAP_VISIBILITY = 0.3f

        /** PIP→TIP minimum length để loại ngón quá ngắn (gập gần như biến mất). */
        private const val SNAP_MIN_PIPTIP_LENGTH = 0.05f

        /**
         * Ngưỡng curl detection cho Snapshot mode.
         *
         * wristTipDist / wristMcpDist:
         *   Ngón thẳng:   ~1.5–2.5 (TIP vươn ra xa hơn MCP rất nhiều so với WRIST)
         *   Gập vừa:    ~1.1–1.4 (TIP chỉ vươn hơn MCP một chút)
         *   Gập hẳn:    ~0.7–1.0 (TIP gần WRIST như MCP hoặc kém hơn)
         *
         * Threshold 1.3: bắt cả ngón gập vừa (tỹ lệ < 1.3) mà không false-positive
         * ngón thẳng (thường > 1.5). Điều chỉnh thấp xuống nếu có false-positive,
         * tăng lên nếu ngón gập vừa mức vẫn bị bỏ sót.
         */
        private const val SNAP_CURL_RATIO = 1.3f
    }
}
