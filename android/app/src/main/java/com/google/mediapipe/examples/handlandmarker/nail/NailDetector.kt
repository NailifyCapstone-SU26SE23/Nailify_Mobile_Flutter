package com.google.mediapipe.examples.handlandmarker.nail

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.min

/**
 * Phase 2: Nail ROI Extraction.
 *
 * Trích xuất Region of Interest (ROI) quanh đầu ngón tay từ ảnh gốc,
 * dựa trên tọa độ MediaPipe landmarks. ROI được xoay để căn dọc theo trục ngón tay
 * và được downsample nếu quá lớn để giới hạn chi phí CV (~5-10ms).
 *
 * Pipeline: ảnh gốc → xoay/cắt ROI → downsample (nếu cần) → trả về NailRoi.
 *
 * @param maxRoiSize  Kích thước tối đa của ROI (pixel). ROI lớn hơn sẽ bị downsample.
 *                    Mặc định 128 — đủ phân giải cho segmentation, đủ nhỏ để nhanh.
 */
class NailDetector(
    private val maxRoiSize: Int = DEFAULT_MAX_ROI_SIZE
) {

    /**
     * ROI đã được trích xuất và (có thể) downsample.
     *
     * @param bitmap       Ảnh ROI (ARGB_8888), đã xoay để finger axis theo chiều dọc.
     * @param roiX         Tọa độ X góc trên-trái của ROI trên ảnh gốc (trước downsample).
     * @param roiY         Tọa độ Y góc trên-trái của ROI trên ảnh gốc (trước downsample).
     * @param roiWidth     Chiều rộng ROI trên ảnh gốc (trước downsample).
     * @param roiHeight    Chiều cao ROI trên ảnh gốc (trước downsample).
     * @param fingerAngle  Góc ngón tay (rad) — atan2(tip - pip) trên ảnh gốc.
     * @param scaleFactor   Tỉ lệ downsample (1.0 = không downsample, 0.5 = giảm 2×).
     */
    data class NailRoi(
        val bitmap: Bitmap,
        val roiX: Float,
        val roiY: Float,
        val roiWidth: Float,
        val roiHeight: Float,
        val fingerAngle: Float,
        val scaleFactor: Float,
    )

    /**
     * Trích xuất ROI quanh đầu ngón tay.
     *
     * @param sourceBitmap  Ảnh gốc (thường là camera frame).
     * @param tipLandmark    Landmark TIP (đầu ngón) — normalized [0,1].
     * @param mcpLandmark    Landmark MCP (khớp gốc ngón) — normalized [0,1].
     * @param pipLandmark    Landmark PIP (khớp giữa) — normalized [0,1].
     * @return NailRoi hoặc null nếu landmarks không hợp lệ hoặc ROI ngoài bounds.
     */
    fun extractRoi(
        sourceBitmap: Bitmap,
        tipLandmark: NormalizedLandmark,
        mcpLandmark: NormalizedLandmark,
        pipLandmark: NormalizedLandmark,
    ): NailRoi? {
        val imgW = sourceBitmap.width
        val imgH = sourceBitmap.height

        // Tọa độ pixel của TIP trên ảnh gốc
        val tipX = tipLandmark.x() * imgW
        val tipY = tipLandmark.y() * imgH

        // Khoảng cách MCP→PIP (normalized) → ước lượng kích thước ROI
        val mcpPipDist = hypot(
            (pipLandmark.x() - mcpLandmark.x()).toDouble(),
            (pipLandmark.y() - mcpLandmark.y()).toDouble()
        ).toFloat()

        if (mcpPipDist < 1e-6f) return null

        // ROI size = 2.0 × mcpPipDist × imageSize (covers nail + surrounding skin)
        // Dùng min(imgW, imgH) để không lệch theo tỉ lệ ảnh
        val roiSizeBase = 2.0f * mcpPipDist * min(imgW.toFloat(), imgH.toFloat())
        if (roiSizeBase < MIN_ROI_SIZE) return null  // ROI quá nhỏ — không đủ detail

        val roiSize = roiSizeBase.coerceAtMost(MAX_ROI_SIZE.toFloat())

        // Góc ngón tay: atan2(tip - pip) — hướng từ PIP đến TIP
        val pipX = pipLandmark.x() * imgW
        val pipY = pipLandmark.y() * imgH
        val fingerAngle = atan2(
            (tipY - pipY).toDouble(),
            (tipX - pipX).toDouble()
        ).toFloat()

        // Tính downsample factor nếu ROI quá lớn
        val downsampleFactor = if (roiSize > maxRoiSize) {
            maxRoiSize.toFloat() / roiSize
        } else {
            1.0f
        }

        val outputSize = (roiSize * downsampleFactor).toInt().coerceAtLeast(16)

        // ── Cắt + xoay ROI ──────────────────────────────────────────────
        // Tạo matrix: dịch TIP về gốc → xoay để finger axis theo chiều dọc → cắt ROI
        // Sau xoay, finger axis sẽ dọc theo trục Y (từ dưới lên trên = đầu ngón).
        // ROI được căn giữa tại TIP landmark.
        val matrix = Matrix()

        // Bước 1: Dịch source sao cho TIP nằm tại (-roiSize/2, -roiSize/2) trong output
        // Bước 2: Xoay quanh TIP để finger axis thẳng đứng
        // Bước 3: Dịch về góc (0,0) của output bitmap

        // Góc xoay: muốn finger axis (PIP→TIP) song song trục -Y (lên trên).
        // fingerAngle = atan2(tipY - pipY, tipX - pipX) trong không gian ảnh (Y xuống).
        // Để PIP→TIP hướng lên trên (trục -Y), cần xoay ảnh một góc = (fingerAngle + π/2).
        val rotationDeg = Math.toDegrees(
            (fingerAngle + Math.PI / 2).toDouble()
        ).toFloat()

        matrix.postRotate(-rotationDeg, tipX, tipY)

        // Dịch để TIP nằm giữa ROI
        matrix.postTranslate(-tipX + roiSize / 2f, -tipY + roiSize / 2f)

        // Downsample nếu cần
        if (downsampleFactor < 1.0f) {
            matrix.postScale(downsampleFactor, downsampleFactor)
        }

        // Cắt ROI: vẽ source bitmap vào output bitmap qua matrix
        val roiBitmap = Bitmap.createBitmap(outputSize, outputSize, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(roiBitmap)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
        canvas.drawBitmap(sourceBitmap, matrix, paint)

        return NailRoi(
            bitmap = roiBitmap,
            roiX = tipX - roiSize / 2f,
            roiY = tipY - roiSize / 2f,
            roiWidth = roiSize,
            roiHeight = roiSize,
            fingerAngle = fingerAngle,
            scaleFactor = downsampleFactor,
        )
    }

    companion object {
        private const val TAG = "NailDetector"

        /** Kích thước ROI tối đa mặc định (pixel). ROI lớn hơn sẽ bị downsample. */
        const val DEFAULT_MAX_ROI_SIZE = 128

        /** Kích thước ROI tối thiểu — nhỏ hơn này thì không đủ detail để segment. */
        private const val MIN_ROI_SIZE = 24f

        /** Kích thước ROI tối đa tuyệt đối (dù maxRoiSize có lớn hơn). */
        private const val MAX_ROI_SIZE = 256
    }
}
