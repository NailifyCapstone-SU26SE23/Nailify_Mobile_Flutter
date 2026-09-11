package com.google.mediapipe.examples.handlandmarker.nail

import android.graphics.PointF
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Phase 4: Nail Boundary Detection.
 *
 * Từ binary mask (từ NailSegmenter), trích xuất đường viền móng và tính
 * các đặc trưng hình học (bounding box, center, width, length, aspect ratio)
 * dùng cho auto-scaling.
 *
 * Pipeline: binary mask → contour tracing (Moore) → RDP simplification → validation.
 *
 * @param rdpEpsilon   Epsilon cho Ramer-Douglas-Peucker simplification (pixel trong ROI).
 * @param minBoundaryPoints  Số điểm boundary tối thiểu để chấp nhận (default 5).
 */
class BoundaryDetector(
    private val rdpEpsilon: Float = DEFAULT_RDP_EPSILON,
    private val minBoundaryPoints: Int = DEFAULT_MIN_BOUNDARY_POINTS,
) {

    /**
     * Kết quả boundary detection.
     *
     * @param detected       true nếu boundary hợp lệ; false nếu bị reject (fallback).
     * @param boundaryPoints Đường viền đơn giản hoá (RDP) trong ROI-local coords.
     * @param centerX        Tọa độ X tâm bounding box (ROI-local).
     * @param centerY        Tọa độ Y tâm bounding box (ROI-local).
     * @param width          Chiều rộng bounding box (ROI-local, perpendicular to finger axis).
     * @param length         Chiều dài bounding box (ROI-local, along finger axis).
     * @param area           Số pixel nail trong mask.
     * @param roiArea        Tổng số pixel trong ROI.
     * @param principalAngle Góc trục chính (rad) từ PCA của boundary points.
     * @param confidence     Độ tin cậy 0.0–1.0.
     */
    data class BoundaryResult(
        val detected: Boolean,
        val boundaryPoints: List<PointF>,
        val centerX: Float,
        val centerY: Float,
        val width: Float,
        val length: Float,
        val area: Int,
        val roiArea: Int,
        val principalAngle: Float,
        val confidence: Float,
    )

    /**
     * Phát hiện boundary từ binary mask.
     *
     * @param mask     Binary mask từ NailSegmenter (1=nail, 0=skin).
     * @param width    Chiều rộng mask.
     * @param height   Chiều cao mask.
     * @return BoundaryResult. `detected = false` nếu validation fail.
     */
    fun detect(mask: ByteArray, width: Int, height: Int): BoundaryResult {
        val roiArea = width * height

        // ── Bước 1: Tìm leftmost nail pixel (starting point) ─────────────
        var startX = -1
        var startY = -1
        outer@ for (y in 0 until height) {
            for (x in 0 until width) {
                if (mask[y * width + x] == 1.toByte()) {
                    startX = x
                    startY = y
                    break@outer
                }
            }
        }

        if (startX < 0) {
            // Không có pixel nail nào
            return BoundaryResult(
                detected = false, boundaryPoints = emptyList(),
                centerX = 0f, centerY = 0f, width = 0f, length = 0f,
                area = 0, roiArea = roiArea, principalAngle = 0f, confidence = 0f
            )
        }

        // ── Bước 2: Contour tracing (Moore neighborhood) ──────────────────
        val contour = mooreBoundaryTracing(mask, width, height, startX, startY)

        if (contour.size < minBoundaryPoints) {
            return BoundaryResult(
                detected = false, boundaryPoints = contour,
                centerX = startX.toFloat(), centerY = startY.toFloat(),
                width = 0f, length = 0f, area = countNailPixels(mask),
                roiArea = roiArea, principalAngle = 0f, confidence = 0f
            )
        }

        // ── Bước 3: Simplify boundary (RDP) ──────────────────────────────
        val simplified = rdpSimplify(contour, rdpEpsilon)

        // ── Bước 4: Geometric features ───────────────────────────────────
        var minX = Float.MAX_VALUE
        var minY = Float.MAX_VALUE
        var maxX = Float.MIN_VALUE
        var maxY = Float.MIN_VALUE

        for (p in simplified) {
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
        }

        val bboxWidth = maxX - minX
        val bboxLength = maxY - minY
        val centerX = (minX + maxX) / 2f
        val centerY = (minY + maxY) / 2f

        val nailArea = countNailPixels(mask)

        // ── Bước 5: PCA — principal angle ────────────────────────────────
        val principalAngle = computePrincipalAngle(simplified, centerX, centerY)

        // ── Bước 6: Validation ────────────────────────────────────────────
        val areaRatio = nailArea.toFloat() / roiArea.toFloat()
        val aspectRatio = if (bboxLength > 1f) bboxWidth / bboxLength else 0f

        val rejectReason = when {
            areaRatio < MIN_AREA_RATIO -> "AREA_TOO_SMALL($areaRatio)"
            areaRatio > MAX_AREA_RATIO -> "AREA_TOO_LARGE($areaRatio)"
            aspectRatio < MIN_ASPECT_RATIO -> "ASPECT_TOO_NARROW($aspectRatio)"
            aspectRatio > MAX_ASPECT_RATIO -> "ASPECT_TOO_WIDE($aspectRatio)"
            simplified.size < minBoundaryPoints -> "TOO_FEW_POINTS(${simplified.size})"
            else -> null
        }

        val detected = rejectReason == null
        // Confidence dựa trên: nail area ratio (0.2-0.7 = good) + aspect ratio proximity to 1.0
        val areaConfidence = when {
            areaRatio in 0.2f..0.7f -> 1f - abs(areaRatio - 0.4f) / 0.3f
            areaRatio < 0.2f -> areaRatio / 0.2f
            else -> max(0f, 1f - (areaRatio - 0.7f) / 0.3f)
        }.coerceIn(0f, 1f)
        val aspectConfidence = 1f - abs(aspectRatio - 1f).coerceAtMost(1f)
        val confidence = (0.6f * areaConfidence + 0.4f * aspectConfidence).coerceIn(0f, 1f)

        return BoundaryResult(
            detected = detected,
            boundaryPoints = simplified,
            centerX = centerX,
            centerY = centerY,
            width = bboxWidth,
            length = bboxLength,
            area = nailArea,
            roiArea = roiArea,
            principalAngle = principalAngle,
            confidence = confidence,
        )
    }

    // ─── MOORE BOUNDARY TRACING ──────────────────────────────────────────

    /**
     * Moore neighborhood boundary tracing (a.k.a. "square tracing").
     *
     * Bắt đầu từ leftmost nail pixel, đi theo chiều kim đồng hồ quanh boundary.
     * Dừng khi quay về điểm bắt đầu.
     *
     * @param mask    Binary mask.
     * @param w       Chiều rộng.
     * @param h       Chiều cao.
     * @param startX  Tọa độ X điểm bắt đầu (leftmost nail pixel).
     * @param startY  Tọa độ Y điểm bắt đầu.
     * @return Danh sách điểm boundary (theo chiều kim đồng hồ).
     */
    private fun mooreBoundaryTracing(
        mask: ByteArray, w: Int, h: Int,
        startX: Int, startY: Int
    ): List<PointF> {
        val contour = mutableListOf<PointF>()

        // 8-connectivity directions (clockwise from East)
        // dx[i], dy[i] for i = 0..7
        val dx = intArrayOf(1, 1, 0, -1, -1, -1, 0, 1)
        val dy = intArrayOf(0, 1, 1, 1, 0, -1, -1, -1)

        var cx = startX
        var cy = startY
        contour.add(PointF(cx.toFloat(), cy.toFloat()))

        // Bắt đầu tìm boundary: đi theo hướng North (lên) trước
        // Trong không gian ảnh, North = y-1 = direction index 6
        var dir = 6  // Bắt đầu nhìn lên (North)

        // Giới hạn số bước để tránh infinite loop
        val maxSteps = w * h * 2
        var steps = 0

        while (steps < maxSteps) {
            steps++

            // Tìm nail pixel tiếp theo theo chiều kim đồng hồ
            var foundNext = false
            for (i in 0..7) {
                val checkDir = (dir + i + 6) % 8  // Bắt đầu từ trái của hướng hiện tại
                val nx = cx + dx[checkDir]
                val ny = cy + dy[checkDir]

                if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue
                if (mask[ny * w + nx] == 1.toByte()) {
                    // Tìm thấy! Di chuyển đến pixel này
                    cx = nx
                    cy = ny
                    // Hướng tiếp theo = ngược lại của hướng vừa đi + 1 (xoay phải)
                    dir = (checkDir + 6) % 8

                    // Kiểm tra nếu đã quay về điểm bắt đầu
                    if (cx == startX && cy == startY) {
                        return contour
                    }

                    contour.add(PointF(cx.toFloat(), cy.toFloat()))
                    foundNext = true
                    break
                }
            }

            if (!foundNext) break  // Đơn lẻ — không có neighbor nail
        }

        return contour
    }

    // ─── RAMER-DOUGLAS-PEUCKER SIMPLIFICATION ────────────────────────────

    /**
     * Đơn giản hoá đường viền bằng Ramer-Douglas-Peucker.
     *
     * Giữ lại các điểm "quan trọng" (đỉnh, góc) và loại bỏ các điểm thẳng hàng.
     *
     * @param points  Danh sách điểm boundary.
     * @param epsilon Ngưỡng khoảng cách tối đa (pixel). Điểm có khoảng cách < epsilon bị loại.
     * @return Danh sách điểm đã đơn giản hoá.
     */
    private fun rdpSimplify(points: List<PointF>, epsilon: Float): List<PointF> {
        if (points.size < 3) return points

        val keep = BooleanArray(points.size)
        keep[0] = true
        keep[points.size - 1] = true

        rdpRecursive(points, 0, points.size - 1, epsilon, keep)

        val result = mutableListOf<PointF>()
        for (i in points.indices) {
            if (keep[i]) result.add(points[i])
        }
        return result
    }

    private fun rdpRecursive(
        points: List<PointF>,
        startIdx: Int,
        endIdx: Int,
        epsilon: Float,
        keep: BooleanArray
    ) {
        if (endIdx <= startIdx + 1) return

        // Tìm điểm xa nhất khỏi đường thẳng start→end
        var maxDist = 0f
        var maxIdx = -1

        val startPt = points[startIdx]
        val endPt = points[endIdx]

        for (i in (startIdx + 1) until endIdx) {
            val dist = perpendicularDistance(points[i], startPt, endPt)
            if (dist > maxDist) {
                maxDist = dist
                maxIdx = i
            }
        }

        if (maxDist > epsilon && maxIdx >= 0) {
            keep[maxIdx] = true
            rdpRecursive(points, startIdx, maxIdx, epsilon, keep)
            rdpRecursive(points, maxIdx, endIdx, epsilon, keep)
        }
        // Nếu maxDist <= epsilon, tất cả điểm giữa đều bị loại (không giữ)
    }

    /**
     * Khoảng cách từ điểm p đến đường thẳng a→b (perpendicular distance).
     */
    private fun perpendicularDistance(p: PointF, a: PointF, b: PointF): Float {
        val dx = b.x - a.x
        val dy = b.y - a.y
        val lenSq = dx * dx + dy * dy
        if (lenSq < 1e-6f) {
            // a == b, trả về khoảng cách từ p đến a
            return hypot(p.x - a.x, p.y - a.y)
        }
        // |cross product| / |b-a|
        return abs((p.x - a.x) * dy - (p.y - a.y) * dx) / sqrt(lenSq)
    }

    // ─── PCA (PRINCIPAL COMPONENT ANALYSIS) ──────────────────────────────

    /**
     * Tính góc trục chính (principal angle) từ PCA của boundary points.
     *
     * Trục chính = hướng có variance lớn nhất → hướng dài nhất của móng.
     *
     * @param points   Boundary points.
     * @param centerX  Tọa độ X tâm (đã tính sẵn).
     * @param centerY  Tọa độ Y tâm (đã tính sẵn).
     * @return Góc (rad) của trục chính so với trục +X.
     */
    private fun computePrincipalAngle(
        points: List<PointF>,
        centerX: Float,
        centerY: Float
    ): Float {
        if (points.size < 2) return 0f

        var sumXX = 0f
        var sumYY = 0f
        var sumXY = 0f

        for (p in points) {
            val dx = p.x - centerX
            val dy = p.y - centerY
            sumXX += dx * dx
            sumYY += dy * dy
            sumXY += dx * dy
        }

        val n = points.size.toFloat()

        // Covariance matrix: [[sumXX, sumXY], [sumXY, sumYY]]
        // Principal angle = 0.5 × atan2(2×sumXY, sumXX - sumYY)
        return 0.5f * atan2(2f * sumXY / n, (sumXX - sumYY) / n)
    }

    // ─── HELPERS ─────────────────────────────────────────────────────────

    private fun countNailPixels(mask: ByteArray): Int {
        var count = 0
        for (b in mask) if (b == 1.toByte()) count++
        return count
    }

    companion object {
        private const val TAG = "BoundaryDetector"

        /** Epsilon mặc định cho RDP (pixel trong ROI). */
        private const val DEFAULT_RDP_EPSILON = 2f

        /** Số điểm boundary tối thiểu để chấp nhận. */
        private const val DEFAULT_MIN_BOUNDARY_POINTS = 5

        /** Tỉ lệ diện tích nail / ROI tối thiểu (dưới = quá nhỏ → reject). */
        private const val MIN_AREA_RATIO = 0.05f

        /** Tỉ lệ diện tích nail / ROI tối đa (trên = quá lớn → reject). */
        private const val MAX_AREA_RATIO = 0.85f

        /** Aspect ratio (width/length) tối thiểu. */
        private const val MIN_ASPECT_RATIO = 0.2f

        /** Aspect ratio (width/length) tối đa. */
        private const val MAX_ASPECT_RATIO = 5.0f
    }
}
