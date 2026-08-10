/*
 * NailOverlayEngine.kt — Homography-based design renderer.
 *
 * Port từ nail_desktop_app/overlay.py NailOverlayRenderer.
 */
package com.nailify.nail_plugin.ai

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.util.Log
import kotlin.math.max
import kotlin.math.sqrt

enum class BlendMode { ALPHA, MULTIPLY, SCREEN, PRESERVE_LIGHTING }

object NailOverlayEngine {
    private const val TAG = "NailOverlayEngine"
    private const val TIP_RECT_START = 0.4f

    fun render(
        frame: Bitmap,
        detections: List<NailDetection>,
        designs: Map<String, LoadedDesign>,
        defaultDesignAsset: String,
        blendMode: BlendMode = BlendMode.ALPHA,
    ): Bitmap {
        if (detections.isEmpty()) return frame
        val defaultDesign = designs[defaultDesignAsset]
        if (defaultDesign == null) {
            Log.w(TAG, "Default design asset '$defaultDesignAsset' not loaded; skipping render.")
            return frame
        }
        for (det in detections) {
            try {
                val design = det.designAssetPath?.let { designs[it] } ?: defaultDesign
                renderOne(frame, det, design, blendMode)
            } catch (e: Exception) {
                Log.w(TAG, "Render failed for cls=${det.clsName}: ${e.message}")
            }
        }
        return frame
    }

    private fun renderOne(
        frame: Bitmap,
        det: NailDetection,
        design: LoadedDesign,
        blendMode: BlendMode,
    ) {
        if (det.polygon.size < 3) return

        val pcaDir = det.pcaDirection ?: PointF(0f, -1f)
        var vLong = normalize(pcaDir) ?: return
        val rotationHint = det.forwardVector
        if (rotationHint != null) {
            val hintMag = sqrt(rotationHint.x * rotationHint.x + rotationHint.y * rotationHint.y)
            if (hintMag > 1e-9f) {
                val hintNorm = PointF(rotationHint.x / hintMag, rotationHint.y / hintMag)
                val dot = vLong.x * hintNorm.x + vLong.y * hintNorm.y
                if (dot < 0f) vLong = PointF(-vLong.x, -vLong.y)
            }
        }
        val vShort = PointF(-vLong.y, vLong.x)

        val bedSource = if (det.nailBedPolygon.size >= 3) det.nailBedPolygon else det.polygon
        var minShort = Float.POSITIVE_INFINITY
        var maxShort = Float.NEGATIVE_INFINITY
        for (p in bedSource) {
            val proj = p.x * vShort.x + p.y * vShort.y
            if (proj < minShort) minShort = proj
            if (proj > maxShort) maxShort = proj
        }
        val wBed = maxShort - minShort
        if (wBed < 1f) return

        var minLong = Float.POSITIVE_INFINITY
        var maxLong = Float.NEGATIVE_INFINITY
        for (p in det.polygon) {
            val proj = p.x * vLong.x + p.y * vLong.y
            if (proj < minLong) minLong = proj
            if (proj > maxLong) maxLong = proj
        }
        val nailLength = maxLong - minLong
        if (nailLength < 1f) return

        val aspectRatio = design.aspectRatio
        val hMapped = wBed * aspectRatio
        val tipProj = minLong + hMapped

        val cuticleL = PointF(minLong * vLong.x + minShort * vShort.x, minLong * vLong.y + minShort * vShort.y)
        val cuticleR = PointF(minLong * vLong.x + maxShort * vShort.x, minLong * vLong.y + maxShort * vShort.y)
        val tipR     = PointF(tipProj  * vLong.x + maxShort * vShort.x, tipProj  * vLong.y + maxShort * vShort.y)
        val tipL     = PointF(tipProj  * vLong.x + minShort * vShort.x, tipProj  * vLong.y + minShort * vShort.y)
        val dst = arrayOf(cuticleL, cuticleR, tipR, tipL)

        val ob = design.opaqueBounds
        val src = arrayOf(
            PointF(ob.left.toFloat(),  ob.bottom.toFloat()),
            PointF(ob.right.toFloat(), ob.bottom.toFloat()),
            PointF(ob.right.toFloat(), ob.top.toFloat()),
            PointF(ob.left.toFloat(),  ob.top.toFloat()),
        )

        val homography = findHomography(src, dst) ?: return
        val warped = warpPerspective(design.bitmap, homography, frame.width, frame.height)

        val designMask = alphaChannelMask(warped, frame.width, frame.height)
        if (designMask == null) return

        val nailMask = createHybridNailMask(
            frameW = frame.width,
            frameH = frame.height,
            polygon = det.polygon,
            vLong = vLong,
            vShort = vShort,
            minLong = minLong,
            maxLong = maxLong,
            minShort = minShort,
            maxShort = maxShort,
        ) ?: return

        val finalMask = andMask(designMask, nailMask) ?: return
        applyBlend(frame, warped, finalMask, blendMode)
    }

    private fun normalize(v: PointF): PointF? {
        val m = sqrt(v.x * v.x + v.y * v.y)
        if (m < 1e-9f) return null
        return PointF(v.x / m, v.y / m)
    }

    private fun findHomography(src: Array<PointF>, dst: Array<PointF>): FloatArray? {
        if (src.size != 4 || dst.size != 4) return null
        val a = FloatArray(8 * 8)
        val b = FloatArray(8)
        for (i in 0 until 4) {
            val (sx, sy) = src[i].x to src[i].y
            val (dx, dy) = dst[i].x to dst[i].y
            val row0 = i * 2
            val row1 = row0 + 1
            a[row0 * 8 + 0] = sx
            a[row0 * 8 + 1] = sy
            a[row0 * 8 + 2] = 1f
            a[row0 * 8 + 3] = 0f
            a[row0 * 8 + 4] = 0f
            a[row0 * 8 + 5] = 0f
            a[row0 * 8 + 6] = -sx * dx
            a[row0 * 8 + 7] = -sy * dx
            b[row0] = dx
            a[row1 * 8 + 0] = 0f
            a[row1 * 8 + 1] = 0f
            a[row1 * 8 + 2] = 0f
            a[row1 * 8 + 3] = sx
            a[row1 * 8 + 4] = sy
            a[row1 * 8 + 5] = 1f
            a[row1 * 8 + 6] = -sx * dy
            a[row1 * 8 + 7] = -sy * dy
            b[row1] = dy
        }
        val h = solveLinearSystem(a, b) ?: return null
        return floatArrayOf(
            h[0], h[1], h[2],
            h[3], h[4], h[5],
            h[6], h[7], 1f,
        )
    }

    private fun solveLinearSystem(aIn: FloatArray, bIn: FloatArray): FloatArray? {
        val n = bIn.size
        require(aIn.size == n * n) { "matrix size mismatch" }
        val a = aIn.copyOf()
        val b = bIn.copyOf()
        for (i in 0 until n) {
            var pivotRow = i
            var pivotVal = kotlin.math.abs(a[i * n + i])
            for (r in i + 1 until n) {
                val v = kotlin.math.abs(a[r * n + i])
                if (v > pivotVal) { pivotVal = v; pivotRow = r }
            }
            if (pivotVal < 1e-9f) return null
            if (pivotRow != i) {
                for (c in 0 until n) {
                    val tmp = a[i * n + c]
                    a[i * n + c] = a[pivotRow * n + c]
                    a[pivotRow * n + c] = tmp
                }
                val tmp = b[i]; b[i] = b[pivotRow]; b[pivotRow] = tmp
            }
            val pivot = a[i * n + i]
            for (c in 0 until n) a[i * n + c] /= pivot
            b[i] /= pivot
            for (r in 0 until n) {
                if (r == i) continue
                val factor = a[r * n + i]
                if (kotlin.math.abs(factor) < 1e-9f) continue
                for (c in 0 until n) a[r * n + c] -= factor * a[i * n + c]
                b[r] -= factor * b[i]
            }
        }
        return b
    }

    private fun warpPerspective(src: Bitmap, h: FloatArray, outW: Int, outH: Int): Bitmap {
        val dst = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
        val srcW = src.width
        val srcH = src.height
        val pixels = IntArray(srcW * srcH)
        src.getPixels(pixels, 0, srcW, 0, 0, srcW, srcH)
        val det = h[0] * (h[4] * h[8] - h[5] * h[7]) -
                  h[1] * (h[3] * h[8] - h[5] * h[6]) +
                  h[2] * (h[3] * h[7] - h[4] * h[6])
        if (kotlin.math.abs(det) < 1e-12f) return dst

        val invDet = 1f / det
        val inv = FloatArray(9)
        inv[0] =  (h[4] * h[8] - h[5] * h[7]) * invDet
        inv[1] = -(h[1] * h[8] - h[2] * h[7]) * invDet
        inv[2] =  (h[1] * h[5] - h[2] * h[4]) * invDet
        inv[3] = -(h[3] * h[8] - h[5] * h[6]) * invDet
        inv[4] =  (h[0] * h[8] - h[2] * h[6]) * invDet
        inv[5] = -(h[0] * h[5] - h[2] * h[3]) * invDet
        inv[6] =  (h[3] * h[7] - h[4] * h[6]) * invDet
        inv[7] = -(h[0] * h[7] - h[1] * h[6]) * invDet
        inv[8] =  (h[0] * h[4] - h[1] * h[3]) * invDet

        val out = IntArray(outW * outH)
        for (y in 0 until outH) {
            for (x in 0 until outW) {
                val sx = inv[0] * x + inv[1] * y + inv[2]
                val sy = inv[3] * x + inv[4] * y + inv[5]
                val sw = inv[6] * x + inv[7] * y + inv[8]
                if (sw == 0f) continue
                val px = sx / sw
                val py = sy / sw
                if (px < 0f || px > srcW - 1f || py < 0f || py > srcH - 1f) continue
                val x0 = px.toInt().coerceIn(0, srcW - 1)
                val y0 = py.toInt().coerceIn(0, srcH - 1)
                val x1 = (x0 + 1).coerceAtMost(srcW - 1)
                val y1 = (y0 + 1).coerceAtMost(srcH - 1)
                val fx = px - x0
                val fy = py - y0
                val p00 = pixels[y0 * srcW + x0]
                val p10 = pixels[y0 * srcW + x1]
                val p01 = pixels[y1 * srcW + x0]
                val p11 = pixels[y1 * srcW + x1]
                val a = lerpColor(p00, p10, fx)
                val b = lerpColor(p01, p11, fx)
                out[y * outW + x] = lerpColor(a, b, fy)
            }
        }
        dst.setPixels(out, 0, outW, 0, 0, outW, outH)
        return dst
    }

    private fun lerpColor(c0: Int, c1: Int, t: Float): Int {
        val a = (Color.alpha(c0) * (1f - t) + Color.alpha(c1) * t).toInt()
        val r = (Color.red(c0)   * (1f - t) + Color.red(c1)   * t).toInt()
        val g = (Color.green(c0) * (1f - t) + Color.green(c1) * t).toInt()
        val b = (Color.blue(c0)  * (1f - t) + Color.blue(c1)  * t).toInt()
        return Color.argb(a, r, g, b)
    }

    private fun alphaChannelMask(rgba: Bitmap, w: Int, h: Int): Bitmap? {
        val mask = Bitmap.createBitmap(w, h, Bitmap.Config.ALPHA_8)
        val canvas = Canvas(mask)
        val paint = Paint().apply {
            xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC)
        }
        canvas.drawBitmap(rgba, 0f, 0f, paint)
        val centerAlpha = if (mask.getPixel(w / 2, h / 2) == 0) {
            val samples = intArrayOf(0, w / 4, w / 2, 3 * w / 4, w - 1)
            var nonZero = false
            for (sx in samples) {
                for (sy in samples) {
                    if (mask.getPixel(sx, sy) != 0) { nonZero = true; break }
                }
                if (nonZero) break
            }
            if (!nonZero) return null
            0
        } else 0
        return mask
    }

    private fun createHybridNailMask(
        frameW: Int,
        frameH: Int,
        polygon: List<PointF>,
        vLong: PointF,
        vShort: PointF,
        minLong: Float,
        maxLong: Float,
        minShort: Float,
        maxShort: Float,
    ): Bitmap? {
        val mask = Bitmap.createBitmap(frameW, frameH, Bitmap.Config.ALPHA_8)
        val canvas = Canvas(mask)
        val path = Path()
        path.moveTo(polygon[0].x, polygon[0].y)
        for (i in 1 until polygon.size) path.lineTo(polygon[i].x, polygon[i].y)
        path.close()
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        canvas.drawPath(path, fillPaint)
        val startLong = minLong + (maxLong - minLong) * TIP_RECT_START
        val rectBL = PointF(startLong * vLong.x + minShort * vShort.x, startLong * vLong.y + minShort * vShort.y)
        val rectBR = PointF(startLong * vLong.x + maxShort * vShort.x, startLong * vLong.y + maxShort * vShort.y)
        val rectTR = PointF(maxLong  * vLong.x + maxShort * vShort.x, maxLong  * vLong.y + maxShort * vShort.y)
        val rectTL = PointF(maxLong  * vLong.x + minShort * vShort.x, maxLong  * vLong.y + minShort * vShort.y)
        val rectPath = Path().apply {
            moveTo(rectBL.x, rectBL.y)
            lineTo(rectBR.x, rectBR.y)
            lineTo(rectTR.x, rectTR.y)
            lineTo(rectTL.x, rectTL.y)
            close()
        }
        canvas.drawPath(rectPath, fillPaint)
        return mask
    }

    private fun andMask(a: Bitmap, b: Bitmap): Bitmap? {
        val w = a.width
        val h = a.height
        if (b.width != w || b.height != h) return null
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ALPHA_8)
        val canvas = Canvas(out)
        val base = Paint().apply { xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC) }
        canvas.drawBitmap(a, 0f, 0f, base)
        val top = Paint().apply { xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN) }
        canvas.drawBitmap(b, 0f, 0f, top)
        return out
    }

    private fun applyBlend(frame: Bitmap, warped: Bitmap, mask: Bitmap, mode: BlendMode) {
        val w = frame.width
        val h = frame.height
        val framePixels = IntArray(w * h)
        val warpedPixels = IntArray(w * h)
        val maskPixels = ByteArray(w * h)
        frame.getPixels(framePixels, 0, w, 0, 0, w, h)
        warped.getPixels(warpedPixels, 0, w, 0, 0, w, h)
        val maskBuffer = java.nio.ByteBuffer.wrap(maskPixels)
        mask.copyPixelsToBuffer(maskBuffer)
        for (i in 0 until w * h) {
            val m = maskPixels[i].toInt() and 0xFF
            if (m == 0) continue
            val dstColor = framePixels[i]
            val srcColor = warpedPixels[i]
            val blended = when (mode) {
                BlendMode.ALPHA -> blendAlpha(srcColor, dstColor, m)
                BlendMode.MULTIPLY -> blendMultiply(srcColor, dstColor, m)
                BlendMode.SCREEN -> blendScreen(srcColor, dstColor, m)
                BlendMode.PRESERVE_LIGHTING -> blendPreserveLighting(srcColor, dstColor, m)
            }
            framePixels[i] = blended
        }
        frame.setPixels(framePixels, 0, w, 0, 0, w, h)
    }

    private fun blendAlpha(src: Int, dst: Int, maskAlpha: Int): Int {
        val a = maskAlpha / 255f
        val sa = Color.alpha(src) / 255f * a
        val r = (Color.red(src)   * sa + Color.red(dst)   * (1f - sa)).toInt()
        val g = (Color.green(src) * sa + Color.green(dst) * (1f - sa)).toInt()
        val b = (Color.blue(src)  * sa + Color.blue(dst)  * (1f - sa)).toInt()
        return Color.argb(255, r.coerceIn(0, 255), g.coerceIn(0, 255), b.coerceIn(0, 255))
    }

    private fun blendMultiply(src: Int, dst: Int, maskAlpha: Int): Int {
        val r = (Color.red(src)   * Color.red(dst)   / 255)
        val g = (Color.green(src) * Color.green(dst) / 255)
        val b = (Color.blue(src)  * Color.blue(dst)  / 255)
        val mul = Color.argb(255, r.coerceIn(0, 255), g.coerceIn(0, 255), b.coerceIn(0, 255))
        return blendAlpha(mul, dst, maskAlpha)
    }

    private fun blendScreen(src: Int, dst: Int, maskAlpha: Int): Int {
        val r = 255 - ((255 - Color.red(src))   * (255 - Color.red(dst))   / 255)
        val g = 255 - ((255 - Color.green(src)) * (255 - Color.green(dst)) / 255)
        val b = 255 - ((255 - Color.blue(src))  * (255 - Color.blue(dst))  / 255)
        val scr = Color.argb(255, r.coerceIn(0, 255), g.coerceIn(0, 255), b.coerceIn(0, 255))
        return blendAlpha(scr, dst, maskAlpha)
    }

    private fun blendPreserveLighting(src: Int, dst: Int, maskAlpha: Int): Int {
        val dstR = Color.red(dst)
        val dstG = Color.green(dst)
        val dstB = Color.blue(dst)
        val lum = 0.114f * dstR + 0.587f * dstG + 0.299f * dstB
        val ratio = (lum / 128f).coerceIn(0.3f, 2.0f)
        val r = (Color.red(src)   * ratio).toInt().coerceIn(0, 255)
        val g = (Color.green(src) * ratio).toInt().coerceIn(0, 255)
        val b = (Color.blue(src)  * ratio).toInt().coerceIn(0, 255)
        val adj = Color.argb(255, r, g, b)
        return blendAlpha(adj, dst, maskAlpha)
    }
}