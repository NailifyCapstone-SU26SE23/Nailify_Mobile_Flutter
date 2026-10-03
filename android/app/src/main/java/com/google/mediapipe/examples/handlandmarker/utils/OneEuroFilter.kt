package com.google.mediapipe.examples.handlandmarker.utils

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.exp

/**
 * One Euro Filter — thích nghi độ mượt dựa trên vận tốc của tín hiệu.
 *
 * Nguyên lý:
 *   - Khi tay đứng yên (vận tốc thấp) → tăng smoothing (giảm cutoff) → loại jitter.
 *   - Khi tay di chuyển nhanh (vận tốc cao) → giảm smoothing (tăng cutoff) → giảm lag.
 *
 * Công thức exponential low-pass:
 *   alpha  = 2πfc / (2πfc + Te⁻¹)   với fc = cutoff frequency, Te = sample period
 *   x̂(t) = alpha * x(t) + (1 - alpha) * x̂(t-1)
 *
 * Công thức cutoff động:
 *   fc = minCutoff + beta * |dx̂/dt|
 *
 * Tham chiếu: "1€ Filter: A Simple Speed-based Low-pass Filter for Noisy Input in Interactive Systems"
 *             Casiez, Roussel, Vogel, CHI 2012.
 *
 * @param freq        Tần số lấy mẫu ước tính (Hz). Dùng 30f hoặc 60f.
 * @param minCutoff   Cutoff tối thiểu (Hz). Giảm → mượt hơn khi đứng yên, nhưng tăng lag.
 * @param beta        Hệ số tốc độ. Tăng → giảm lag khi di chuyển nhanh.
 * @param dCutoff     Cutoff để lọc đạo hàm vận tốc (thường để cố định = 1.0).
 */
class OneEuroFilter(
    private var freq: Float = 30f,
    private var minCutoff: Float = 1.0f,
    private var beta: Float = 0.0f,
    private var dCutoff: Float = 1.0f
) {
    // Biến lưu giá trị đã lọc ở bước trước
    private var xPrev: Float? = null
    // Biến lưu đạo hàm (vận tốc) đã lọc ở bước trước
    private var dxPrev: Float = 0f
    // Thời gian (ms) của lần lọc trước — dùng để tính Hz thực tế
    private var tPrev: Long = -1L

    /**
     * Tính hệ số alpha cho bộ lọc low-pass.
     * alpha điều chỉnh mức độ trộn giữa giá trị mới và giá trị đã làm mượt.
     *
     * Công thức: alpha = (2πfc * Te) / (1 + 2πfc * Te)
     *            tương đương: r / (1 + r) với r = 2πfc / sampleRate
     */
    private fun alpha(cutoff: Float, sampleRate: Float): Float {
        val te = 1f / sampleRate          // Chu kỳ lấy mẫu (giây)
        val tau = 1f / (2f * PI.toFloat() * cutoff) // Hằng số thời gian
        return 1f / (1f + tau / te)
    }

    /**
     * Lọc một giá trị scalar mới.
     *
     * @param value     Giá trị thô cần làm mượt (px, độ, hoặc bất kỳ đơn vị nào).
     * @param timestamp Thời điểm lấy mẫu (ms từ SystemClock / System.currentTimeMillis).
     * @return          Giá trị đã được làm mượt.
     */
    fun filter(value: Float, timestamp: Long): Float {
        // --- Bước 1: Cập nhật tần số thực tế từ delta time ---
        val effectiveFreq = if (tPrev >= 0L) {
            val dt = (timestamp - tPrev) / 1000f // Đổi ms → giây
            if (dt > 0f) 1f / dt else freq
        } else {
            freq
        }
        tPrev = timestamp

        // --- Bước 2: Ước lượng đạo hàm (vận tốc) ---
        val prevX = xPrev ?: value          // Lần đầu tiên: coi dx = 0
        val dx = (value - prevX) * effectiveFreq

        // Lọc low-pass đạo hàm để tránh đạo hàm bị nhiễu
        val aD = alpha(dCutoff, effectiveFreq)
        val dxHat = aD * dx + (1f - aD) * dxPrev
        dxPrev = dxHat

        // --- Bước 3: Cutoff động — fc tăng theo tốc độ để giảm lag ---
        // fc = minCutoff + beta * |vận tốc|
        val cutoff = minCutoff + beta * abs(dxHat)

        // --- Bước 4: Lọc low-pass giá trị gốc với cutoff động ---
        val a = alpha(cutoff, effectiveFreq)
        val xHat = a * value + (1f - a) * prevX
        xPrev = xHat

        return xHat
    }

    /** Đặt lại bộ lọc về trạng thái ban đầu (dùng khi mất tracking). */
    fun reset() {
        xPrev = null
        dxPrev = 0f
        tPrev = -1L
    }
}
