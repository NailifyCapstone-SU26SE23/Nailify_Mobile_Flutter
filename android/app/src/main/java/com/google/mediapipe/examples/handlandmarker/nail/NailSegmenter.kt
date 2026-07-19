package com.google.mediapipe.examples.handlandmarker.nail

import android.graphics.Bitmap
import android.graphics.Color
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Phase 3: Skin/Nail Segmentation (Classical CV).
 *
 * Phân loại mỗi pixel trong ROI là "móng" (1) hay "da" (0) dựa trên:
 *   - **Color features (HSV)**: Móng có saturation thấp (< 0.35) và value cao (> 0.55).
 *   - **Texture feature (local variance)**: Móng mượt hơn da → variance thấp.
 *   - **Otsu's method**: Tự động tìm threshold tối ưu cho mọi skin tone & lighting.
 *   - **Morphological refinement**: Erode + dilate + largest connected component.
 *
 * Output: Binary mask (ByteArray, 1 byte/pixel, 0=skin, 1=nail).
 *
 * @param textureWindowSize  Kích thước cửa sổ tính local variance (mặc định 5 = 5×5).
 * @param textureDivisor     Hệ số chuẩn hóa texture score (mặc định 40 → variance 40 = score 0).
 */
class NailSegmenter(
    private val textureWindowSize: Int = DEFAULT_TEXTURE_WINDOW,
    private val textureDivisor: Float = DEFAULT_TEXTURE_DIVISOR,
) {

    /**
     * Kết quả segmentation.
     *
     * @param mask       Binary mask: 1=nail, 0=skin. Kích thước = width × height.
     * @param width      Chiều rộng mask.
     * @param height     Chiều cao mask.
     * @param nailArea   Số pixel = 1 (nail).
     * @param threshold  Threshold tối ưu do Otsu tìm ra.
     */
    data class SegmentationResult(
        val mask: ByteArray,
        val width: Int,
        val height: Int,
        val nailArea: Int,
        val threshold: Float,
    )

    /**
     * Chạy segmentation trên ROI bitmap.
     *
     * Pipeline:
     *   1. Trích xuất HSV + texture features cho mỗi pixel.
     *   2. Tính combined score = 0.6 × colorScore + 0.4 × textureScore.
     *   3. Otsu threshold trên histogram của combined score.
     *   4. Binary mask: score > threshold → nail (1).
     *   5. Morphological: erode → dilate → largest connected component.
     *
     * @param roiBitmap  Bitmap ROI (ARGB_8888) từ NailDetector.
     * @return SegmentationResult chứa binary mask.
     */
    fun segment(roiBitmap: Bitmap): SegmentationResult {
        val w = roiBitmap.width
        val h = roiBitmap.height
        val pixelCount = w * h

        if (pixelCount == 0) {
            return SegmentationResult(ByteArray(0), 0, 0, 0, 0.5f)
        }

        // ── Bước 1: Trích xuất features ──────────────────────────────────
        val pixels = IntArray(pixelCount)
        roiBitmap.getPixels(pixels, 0, w, 0, 0, w, h)

        val colorScores = FloatArray(pixelCount)
        val textureScores = FloatArray(pixelCount)
        val combinedScores = FloatArray(pixelCount)

        // Color features
        val hsv = FloatArray(3)
        for (i in pixels.indices) {
            val pixel = pixels[i]
            Color.RGBToHSV(
                (pixel shr 16) and 0xFF,
                (pixel shr 8) and 0xFF,
                pixel and 0xFF,
                hsv
            )
            // hsv[0] = hue [0,360), hsv[1] = saturation [0,1], hsv[2] = value [0,1]
            val s = hsv[1]
            val v = hsv[2]
            // Nail score: low saturation + high value
            colorScores[i] = (1f - s) * 0.5f + v * 0.5f
        }

        // Texture features (local variance in 5×5 window)
        computeLocalVariance(pixels, w, h, textureScores, textureWindowSize)

        // Combined score
        for (i in pixels.indices) {
            textureScores[i] = max(0f, 1f - textureScores[i] / textureDivisor)
            combinedScores[i] = COLOR_WEIGHT * colorScores[i] + TEXTURE_WEIGHT * textureScores[i]
        }

        // ── Bước 2: Otsu threshold ────────────────────────────────────────
        val threshold = otsuThreshold(combinedScores)

        // ── Bước 3: Binary mask ──────────────────────────────────────────
        val mask = ByteArray(pixelCount)
        var nailArea = 0
        for (i in pixels.indices) {
            if (combinedScores[i] > threshold) {
                mask[i] = 1
                nailArea++
            }
        }

        // ── Bước 4: Morphological refinement ─────────────────────────────
        erode(mask, w, h)
        dilate(mask, w, h)

        // Keep only the largest connected component
        val refinedMask = largestConnectedComponent(mask, w, h)

        // Recount nail area after refinement
        var refinedArea = 0
        for (b in refinedMask) if (b == 1.toByte()) refinedArea++

        return SegmentationResult(
            mask = refinedMask,
            width = w,
            height = h,
            nailArea = refinedArea,
            threshold = threshold,
        )
    }

    // ─── HSV COLOR FEATURES ──────────────────────────────────────────────
    // (Computed inline in segment() above)

    // ─── TEXTURE FEATURE (LOCAL VARIANCE) ────────────────────────────────

    /**
     * Tính local variance cho mỗi pixel trong cửa sổ windowSize×windowSize.
     *
     * @param pixels    Pixel array (ARGB).
     * @param w         Chiều rộng.
     * @param h         Chiều cao.
     * @param output    Output array — variance cho mỗi pixel.
     * @param windowSize Kích thước cửa sổ (phải lẻ).
     */
    private fun computeLocalVariance(
        pixels: IntArray,
        w: Int,
        h: Int,
        output: FloatArray,
        windowSize: Int
    ) {
        val half = windowSize / 2
        val windowArea = (windowSize * windowSize).toFloat()

        // Convert pixels to luminance array (faster than computing per pixel)
        val luminance = FloatArray(pixels.size)
        for (i in pixels.indices) {
            val pixel = pixels[i]
            val r = (pixel shr 16) and 0xFF
            val g = (pixel shr 8) and 0xFF
            val b = pixel and 0xFF
            luminance[i] = 0.299f * r + 0.587f * g + 0.114f * b
        }

        for (y in 0 until h) {
            for (x in 0 until w) {
                val idx = y * w + x

                // Tính mean trong cửa sổ
                var sum = 0f
                var count = 0
                val yStart = max(0, y - half)
                val yEnd = min(h - 1, y + half)
                val xStart = max(0, x - half)
                val xEnd = min(w - 1, x + half)

                for (wy in yStart..yEnd) {
                    for (wx in xStart..xEnd) {
                        sum += luminance[wy * w + wx]
                        count++
                    }
                }

                if (count < 2) {
                    output[idx] = 0f
                    continue
                }

                val mean = sum / count

                // Tính variance
                var sumSqDiff = 0f
                for (wy in yStart..yEnd) {
                    for (wx in xStart..xEnd) {
                        val diff = luminance[wy * w + wx] - mean
                        sumSqDiff += diff * diff
                    }
                }

                output[idx] = sqrt(sumSqDiff / count)
            }
        }
    }

    // ─── OTSU'S METHOD ────────────────────────────────────────────────────

    /**
     * Tìm threshold tối ưu bằng Otsu's method.
     *
     * Otsu tìm threshold mà tối đa hóa between-class variance — tự động chia
     * histogram thành 2 lớp (nail vs skin) mà không cần ngưỡng cố định.
     *
     * @param scores  Combined scores [0,1] cho mỗi pixel.
     * @return Threshold tối ưu [0,1].
     */
    private fun otsuThreshold(scores: FloatArray): Float {
        val numBins = 256
        val histogram = IntArray(numBins)

        // Build histogram
        for (score in scores) {
            val bin = (score * (numBins - 1)).toInt().coerceIn(0, numBins - 1)
            histogram[bin]++
        }

        val total = scores.size
        if (total == 0) return 0.5f

        // Compute CDF and weighted CDF
        var sum = 0L
        for (i in 0 until numBins) {
            sum += i.toLong() * histogram[i]
        }

        var sumB = 0L
        var wB = 0
        var maxVariance = 0f
        var thresholdBin = numBins / 2

        for (i in 0 until numBins) {
            wB += histogram[i]
            if (wB == 0) continue

            val wF = total - wB
            if (wF == 0) break

            sumB += i.toLong() * histogram[i]

            val mB = sumB.toFloat() / wB
            val mF = (sum - sumB).toFloat() / wF

            val betweenVariance = wB.toFloat() * wF * (mB - mF) * (mB - mF)

            if (betweenVariance > maxVariance) {
                maxVariance = betweenVariance
                thresholdBin = i
            }
        }

        return thresholdBin.toFloat() / (numBins - 1)
    }

    // ─── MORPHOLOGICAL OPERATIONS ──────────────────────────────────────

    /**
     * Erode: pixel = 1 chỉ nếu tất cả neighbors trong kernel 3×3 = 1.
     * Loại bỏ các pixel nail đơn lẻ (noise).
     */
    private fun erode(mask: ByteArray, w: Int, h: Int) {
        val temp = mask.copyOf()
        for (y in 0 until h) {
            for (x in 0 until w) {
                val idx = y * w + x
                if (temp[idx] == 0.toByte()) continue

                // Check if any neighbor is 0 → erode this pixel
                var erode = false
                for (dy in -1..1) {
                    for (dx in -1..1) {
                        val nx = x + dx
                        val ny = y + dy
                        if (nx < 0 || nx >= w || ny < 0 || ny >= h) {
                            erode = true  // Border = treat as 0
                            break
                        }
                        if (temp[ny * w + nx] == 0.toByte()) {
                            erode = true
                            break
                        }
                    }
                    if (erode) break
                }
                if (erode) mask[idx] = 0
            }
        }
    }

    /**
     * Dilate: pixel = 1 nếu bất kỳ neighbor trong kernel 3×3 = 1.
     * Lấp đầy các lỗ nhỏ trong vùng nail.
     */
    private fun dilate(mask: ByteArray, w: Int, h: Int) {
        val temp = mask.copyOf()
        for (y in 0 until h) {
            for (x in 0 until w) {
                val idx = y * w + x
                if (temp[idx] == 1.toByte()) continue

                // Check if any neighbor is 1 → dilate this pixel
                for (dy in -1..1) {
                    for (dx in -1..1) {
                        val nx = x + dx
                        val ny = y + dy
                        if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue
                        if (temp[ny * w + nx] == 1.toByte()) {
                            mask[idx] = 1
                            break
                        }
                    }
                    if (mask[idx] == 1.toByte()) break
                }
            }
        }
    }

    /**
     * Giữ lại connected component lớn nhất (BFS).
     * Loại bỏ các vùng nail false-positive nhỏ, lẻ tẻ.
     */
    private fun largestConnectedComponent(mask: ByteArray, w: Int, h: Int): ByteArray {
        val visited = BooleanArray(mask.size)
        var largestComponent = listOf<Int>()
        var largestSize = 0

        for (startIdx in mask.indices) {
            if (mask[startIdx] != 1.toByte() || visited[startIdx]) continue

            // BFS từ pixel này
            val component = mutableListOf<Int>()
            val queue = ArrayDeque<Int>()
            queue.add(startIdx)
            visited[startIdx] = true

            while (queue.isNotEmpty()) {
                val idx = queue.removeFirst()
                component.add(idx)

                val x = idx % w
                val y = idx / w

                // 4-connectivity
                val neighbors = intArrayOf(
                    if (x > 0) idx - 1 else -1,
                    if (x < w - 1) idx + 1 else -1,
                    if (y > 0) idx - w else -1,
                    if (y < h - 1) idx + w else -1,
                )

                for (neighborIdx in neighbors) {
                    if (neighborIdx < 0) continue
                    if (visited[neighborIdx]) continue
                    if (mask[neighborIdx] != 1.toByte()) continue
                    visited[neighborIdx] = true
                    queue.add(neighborIdx)
                }
            }

            if (component.size > largestSize) {
                largestSize = component.size
                largestComponent = component
            }
        }

        // Tạo mask mới chỉ chứa largest component
        val result = ByteArray(mask.size)
        for (idx in largestComponent) {
            result[idx] = 1
        }

        return result
    }

    companion object {
        private const val TAG = "NailSegmenter"

        /** Trọng số color score trong combined score. */
        private const val COLOR_WEIGHT = 0.6f

        /** Trọng số texture score trong combined score. */
        private const val TEXTURE_WEIGHT = 0.4f

        /** Kích thước cửa sổ texture mặc định (5×5). */
        private const val DEFAULT_TEXTURE_WINDOW = 5

        /** Hệ số chuẩn hóa texture (variance 40 → score 0). */
        private const val DEFAULT_TEXTURE_DIVISOR = 40f
    }
}
