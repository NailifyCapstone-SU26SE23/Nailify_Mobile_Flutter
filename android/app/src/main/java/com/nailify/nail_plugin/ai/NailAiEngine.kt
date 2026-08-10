/*
 * NailAiEngine.kt — YOLO-Seg ONNX inference (CPU).
 *
 * FIX so với version cũ:
 *  - Bitmap pool 640x640 (recycle-safe).
 *  - Mở rộng bbox filter tạm thời để debug 0-detection.
 *  - KHÔNG thay đổi OrtSession usage — caller (PipelineExecutor) phải
 *    đảm bảo chỉ 1 thread gọi run() tại 1 thời điểm.
 *
 * Output shapes:
 *   output0: [1, 37, 8400] (cx, cy, w, h, cls[5], mask_coeffs[32]) — không có obj channel
 *   output1: [1, 32, 160, 160] mask prototypes
 */
package com.nailify.nail_plugin.ai

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.PointF
import android.util.Log
import com.nailify.nail_plugin.util.BitmapPool
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min

class NailAiEngine(
    private val context: Context,
    private val modelAssetPath: String = "nail_seg_5class.onnx",
    private val inputSize: Int = 640,
    private val numClasses: Int = 5,
    private val numMaskCoeffs: Int = 32,
    // DEBUG: bbox filter mở rộng để khảo sát 0-detection; tighten sau khi xác nhận model load đúng.
    private val confThreshold: Float = 0.20f,
    private val perClassThresholds: Map<String, Float> = mapOf(
        "thumb" to 0.30f, "index" to 0.25f, "middle" to 0.20f,
        "ring" to 0.25f, "pinky" to 0.30f,
    ),
    private val iouThreshold: Float = 0.45f,
    private val maskThreshold: Float = 0.3f,
    private val minArea: Float = 200f,
    private val maxArea: Float = 20000f,
    private val minBboxW: Float = 10f,
    private val maxBboxW: Float = 200f,
    private val minBboxH: Float = 5f,
    private val maxBboxH: Float = 150f,
    private val maxAspectRatio: Float = 6.0f,
) {
    companion object {
        private const val TAG = "NailAiEngine"
        private const val DEFAULT_INPUT_NAME = "images"
    }

    private val ortEnv: OrtEnvironment = OrtEnvironment.getEnvironment()
    private var session: OrtSession? = null
    private val bitmapPool = BitmapPool(inputSize, inputSize)

    private val inputName: String
        get() = session?.inputInfo?.keys?.firstOrNull() ?: DEFAULT_INPUT_NAME

    @Volatile private var loaded = false

    fun load(): Boolean {
        if (loaded) return true
        return try {
            val bytes = context.assets.open(modelAssetPath).use { it.readBytes() }
            session = ortEnv.createSession(bytes, OrtSession.SessionOptions())
            loaded = true
            Log.i(TAG, "Model loaded ($modelAssetPath), inputs=${session?.inputInfo?.keys}, outputs=${session?.outputInfo?.keys}")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load model: ${e.message}", e)
            false
        }
    }

    fun close() {
        try { session?.close() } catch (_: Exception) {}
        session = null
        loaded = false
        bitmapPool.clear()
    }

    /**
     * Run inference on `bitmap` (any size). Trả về List<NailDetection> trong image pixel coords.
     * Caller PHẢI đảm bảo gọi tuần tự trên 1 thread (OrtSession.run không thread-safe).
     */
    fun run(bitmap: Bitmap): List<NailDetection> {
        if (!loaded && !load()) return emptyList()
        val sess = session ?: return emptyList()
        if (bitmap.isRecycled) return emptyList()
        val origW = bitmap.width
        val origH = bitmap.height
        if (origW == 0 || origH == 0) return emptyList()

        // 1. Letterbox: scale giữ aspect ratio, pad với 114,114,114.
        val scale = min(inputSize.toFloat() / origW, inputSize.toFloat() / origH)
        val newW = (origW * scale).toInt().coerceAtLeast(1)
        val newH = (origH * scale).toInt().coerceAtLeast(1)
        val padLeft = (inputSize - newW) / 2
        val padTop = (inputSize - newH) / 2

        val resized = bitmapPool.obtain()
        val canvas = Canvas(resized)
        canvas.drawColor(Color.rgb(114, 114, 114))
        val scaled = if (newW != origW || newH != origH) {
            Bitmap.createScaledBitmap(bitmap, newW, newH, true)
        } else bitmap
        canvas.drawBitmap(scaled, padLeft.toFloat(), padTop.toFloat(), null)
        if (scaled !== bitmap) scaled.recycle()

        // 2. Bitmap -> NCHW float32 (RGB normalized to [0,1]).
        val tensor = bitmapToNchwFloat(resized)
        bitmapPool.recycle(resized)

        val shape = longArrayOf(1, 3, inputSize.toLong(), inputSize.toLong())
        val buffer = ByteBuffer.allocateDirect(tensor.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
        buffer.put(tensor)
        buffer.rewind()
        val inputTensor = try {
            OnnxTensor.createTensor(ortEnv, buffer, shape)
        } catch (e: Exception) {
            Log.w(TAG, "createTensor failed: ${e.message}", e)
            return emptyList()
        }

        // 3. Run.
        val rawOutputs = try {
            sess.run(mapOf(inputName to inputTensor))
        } catch (e: Exception) {
            Log.w(TAG, "onnx session.run failed: ${e.message}", e)
            inputTensor.close()
            return emptyList()
        }
        inputTensor.close()

        // 4. Parse.
        val outList = rawOutputs.toList()
        rawOutputs.close()

        val out0 = (outList.getOrNull(0)?.value as? Array<*>)
            ?: return emptyList()
        val out1 = (outList.getOrNull(1)?.value)
        val out0Arr = out0 as Array<Array<FloatArray>>
        val rawBoxes = out0Arr[0]
        val numChannels = rawBoxes.size
        val numAnchors = rawBoxes[0].size
        val preds = Array(numAnchors) { ArrayList<Float>(numChannels) }
        for (c in 0 until numChannels) {
            val ch = rawBoxes[c]
            for (n in 0 until numAnchors) preds[n].add(ch[n])
        }

        // Detect layout (with/without obj channel).
        val hasObjChannel = numChannels == (4 + 1 + numClasses + numMaskCoeffs)
        val objChannelIdx = if (hasObjChannel) 4 else -1
        val clsChannelStart = if (hasObjChannel) 5 else 4
        val coeffChannelStart = clsChannelStart + numClasses

        val cx = FloatArray(numAnchors)
        val cy = FloatArray(numAnchors)
        val bw = FloatArray(numAnchors)
        val bh = FloatArray(numAnchors)
        val obj = FloatArray(numAnchors) { 1f }
        val clsRaw: Array<FloatArray> = Array(numAnchors) { FloatArray(numClasses) }
        val coeffs: Array<FloatArray> = Array(numAnchors) { FloatArray(numMaskCoeffs) }

        for (n in 0 until numAnchors) {
            val row = preds[n]
            cx[n] = row[0]; cy[n] = row[1]; bw[n] = row[2]; bh[n] = row[3]
            if (hasObjChannel) obj[n] = sigmoid(row[objChannelIdx])
            for (c in 0 until numClasses) clsRaw[n][c] = row[clsChannelStart + c]
            for (c in 0 until numMaskCoeffs) coeffs[n][c] = row[coeffChannelStart + c]
        }

        val cls = FloatArray(numAnchors)
        val clsId = IntArray(numAnchors)
        for (n in 0 until numAnchors) {
            var bestP = Float.NEGATIVE_INFINITY
            var bestId = 0
            for (c in 0 until numClasses) {
                val p = if (clsRaw[n][c] in 0f..1f) clsRaw[n][c] else sigmoid(clsRaw[n][c])
                if (p > bestP) { bestP = p; bestId = c }
            }
            cls[n] = bestP
            clsId[n] = bestId
        }
        val conf = FloatArray(numAnchors) { n -> obj[n] * cls[n] }

        // Geometric filter.
        val keepIdx = ArrayList<Int>()
        for (n in 0 until numAnchors) {
            val clsName = FINGER_CLASS_NAMES.getOrNull(clsId[n])
            val perClassThresh = if (clsName != null) perClassThresholds[clsName] else null
            val requiredConf = perClassThresh ?: confThreshold
            if (conf[n] < requiredConf) continue
            if (bw[n] < minBboxW || bw[n] > maxBboxW) continue
            if (bh[n] < minBboxH || bh[n] > maxBboxH) continue
            if (cx[n] < 4f || cx[n] > inputSize - 4f) continue
            if (cy[n] < 4f || cy[n] > inputSize - 4f) continue
            if (bh[n] > 0f && (bw[n] / bh[n]) > maxAspectRatio) continue
            keepIdx.add(n)
        }
        if (keepIdx.isEmpty()) return emptyList()

        val x1 = FloatArray(keepIdx.size) { i -> cx[keepIdx[i]] - bw[keepIdx[i]] * 0.5f }
        val y1 = FloatArray(keepIdx.size) { i -> cy[keepIdx[i]] - bh[keepIdx[i]] * 0.5f }
        val x2 = FloatArray(keepIdx.size) { i -> cx[keepIdx[i]] + bw[keepIdx[i]] * 0.5f }
        val y2 = FloatArray(keepIdx.size) { i -> cy[keepIdx[i]] + bh[keepIdx[i]] * 0.5f }
        val scores = FloatArray(keepIdx.size) { i -> conf[keepIdx[i]] }
        val nmsOrder = nmsSingleClass(x1, y1, x2, y2, scores, iouThreshold)

        val invScale = 1f / scale

        val protoArr = out1 as? Array<Array<Array<FloatArray>>>
        val protoResult: Triple<Array<FloatArray>?, Int, Int> = when {
            protoArr == null -> Triple(null, 0, 0)
            protoArr[0].isNotEmpty() && protoArr[0][0].isNotEmpty() &&
                protoArr[0][0][0] is FloatArray -> {
                val ph = protoArr[0][0].size
                val pw = protoArr[0][0][0].size
                val flat = Array(numMaskCoeffs) { FloatArray(ph * pw) }
                for (k in 0 until numMaskCoeffs) {
                    val plane = protoArr[0][k]
                    val arr = flat[k]
                    for (i in 0 until ph) {
                        val srcRow = plane[i]
                        val dstOff = i * pw
                        for (j in 0 until pw) arr[dstOff + j] = srcRow[j]
                    }
                }
                Triple(flat, ph, pw)
            }
            else -> Triple(null, 0, 0)
        }
        val protoFlat = protoResult.first
        val protoH = protoResult.second
        val protoW = protoResult.third

        val detections = ArrayList<NailDetection>(nmsOrder.size)
        for (orderIdx in nmsOrder) {
            val globalIdx = keepIdx[orderIdx]
            val detCx = cx[globalIdx]
            val detCy = cy[globalIdx]
            val detBw = bw[globalIdx]
            val detBh = bh[globalIdx]
            val detConf = conf[globalIdx]
            val detClsId = clsId[globalIdx].coerceIn(0, numClasses - 1)
            val detClsName = FINGER_CLASS_NAMES.getOrElse(detClsId) { "class_$detClsId" }

            var polygonModel = polygonFromMask(
                proto = protoFlat,
                protoH = protoH,
                protoW = protoW,
                coeffs = coeffs[globalIdx],
                detCx = detCx, detCy = detCy, detBw = detBw, detBh = detBh,
                inputSize = inputSize, maskThreshold = maskThreshold,
            )
            if (polygonModel == null) {
                polygonModel = arrayOf(
                    floatArrayOf(detCx - detBw * 0.5f, detCy - detBh * 0.5f),
                    floatArrayOf(detCx + detBw * 0.5f, detCy - detBh * 0.5f),
                    floatArrayOf(detCx + detBw * 0.5f, detCy + detBh * 0.5f),
                    floatArrayOf(detCx - detBw * 0.5f, detCy + detBh * 0.5f),
                )
            }
            if (polygonModel.size < 3) continue

            val polygon: List<PointF> = polygonModel.map { p ->
                PointF((p[0] - padLeft) * invScale, (p[1] - padTop) * invScale)
            }
            var minPx = Float.POSITIVE_INFINITY
            var minPy = Float.POSITIVE_INFINITY
            var maxPx = Float.NEGATIVE_INFINITY
            var maxPy = Float.NEGATIVE_INFINITY
            for (p in polygon) {
                if (p.x < minPx) minPx = p.x
                if (p.y < minPy) minPy = p.y
                if (p.x > maxPx) maxPx = p.x
                if (p.y > maxPy) maxPy = p.y
            }
            val bbW = maxPx - minPx
            val bbH = maxPy - minPy
            val area = bbW * bbH
            if (area < minArea || area > maxArea) continue

            detections.add(
                NailDetection(
                    bboxCx = (minPx + maxPx) * 0.5f,
                    bboxCy = (minPy + maxPy) * 0.5f,
                    bboxW  = bbW,
                    bboxH  = bbH,
                    polygon = polygon,
                    confidence = detConf,
                    clsId = detClsId,
                    clsName = detClsName,
                )
            )
        }
        return detections
    }

    // --------------------------------------------------------------- helpers

    private fun bitmapToNchwFloat(bitmap: Bitmap): FloatArray {
        val w = bitmap.width
        val h = bitmap.height
        val out = FloatArray(3 * w * h)
        val pixels = IntArray(w * h)
        bitmap.getPixels(pixels, 0, w, 0, 0, w, h)
        var rOff = 0
        var gOff = w * h
        var bOff = 2 * w * h
        for (p in pixels) {
            out[rOff++] = Color.red(p) / 255f
            out[gOff++] = Color.green(p) / 255f
            out[bOff++] = Color.blue(p) / 255f
        }
        return out
    }

    private fun polygonFromMask(
        proto: Array<FloatArray>?,
        protoH: Int,
        protoW: Int,
        coeffs: FloatArray,
        detCx: Float, detCy: Float, detBw: Float, detBh: Float,
        inputSize: Int,
        maskThreshold: Float,
    ): Array<FloatArray>? {
        if (proto == null || protoH == 0 || protoW == 0) return null
        val mask = FloatArray(protoH * protoW)
        for (idx in 0 until protoH * protoW) {
            var sum = 0f
            for (k in 0 until 32) sum += coeffs[k] * proto[k][idx]
            mask[idx] = sigmoid(sum)
        }
        val maskBig = FloatArray(inputSize * inputSize)
        for (y in 0 until inputSize) {
            val py = y.toFloat() * (protoH - 1).toFloat() / (inputSize - 1).toFloat()
            val y0 = py.toInt().coerceIn(0, protoH - 1)
            val y1 = (y0 + 1).coerceAtMost(protoH - 1)
            val fy = py - y0
            for (x in 0 until inputSize) {
                val px = x.toFloat() * (protoW - 1).toFloat() / (inputSize - 1).toFloat()
                val x0 = px.toInt().coerceIn(0, protoW - 1)
                val x1 = (x0 + 1).coerceAtMost(protoW - 1)
                val fx = px - x0
                val v00 = mask[y0 * protoW + x0]
                val v10 = mask[y0 * protoW + x1]
                val v01 = mask[y1 * protoW + x0]
                val v11 = mask[y1 * protoW + x1]
                val v0 = v00 + (v10 - v00) * fx
                val v1 = v01 + (v11 - v01) * fx
                maskBig[y * inputSize + x] = v0 + (v1 - v0) * fy
            }
        }
        val x1m = (detCx - detBw * 0.5f).toInt().coerceIn(0, inputSize - 1)
        val y1m = (detCy - detBh * 0.5f).toInt().coerceIn(0, inputSize - 1)
        val x2m = (detCx + detBw * 0.5f).toInt().coerceIn(x1m + 1, inputSize)
        val y2m = (detCy + detBh * 0.5f).toInt().coerceIn(y1m + 1, inputSize)
        val bboxW = (x2m - x1m).coerceAtLeast(1)
        val bboxH = (y2m - y1m).coerceAtLeast(1)
        val cropped = BooleanArray(bboxW * bboxH)
        for (y in 0 until bboxH) {
            val srcRow = (y1m + y) * inputSize
            val dstRow = y * bboxW
            for (x in 0 until bboxW) {
                cropped[dstRow + x] = maskBig[srcRow + (x1m + x)] > maskThreshold
            }
        }
        val polygon = marchingSquaresContour(cropped, bboxW, bboxH)
        if (polygon.size < 3) return null
        return Array(polygon.size) { i ->
            floatArrayOf(polygon[i][0] + x1m, polygon[i][1] + y1m)
        }
    }

    private fun marchingSquaresContour(mask: BooleanArray, w: Int, h: Int): Array<FloatArray> {
        var startX = -1
        var startY = -1
        for (y in 0 until h) {
            for (x in 0 until w) {
                if (mask[y * w + x]) { startX = x; startY = y; break }
            }
            if (startX >= 0) break
        }
        if (startX < 0) return emptyArray()
        val dx = intArrayOf(-1, -1, 0, 1, 1, 1, 0, -1)
        val dy = intArrayOf(0, -1, -1, -1, 0, 1, 1, 1)
        val out = ArrayList<FloatArray>(32)
        var cx = startX
        var cy = startY
        var fromDir = 0
        val maxSteps = w * h * 4
        var steps = 0
        do {
            out.add(floatArrayOf(cx.toFloat(), cy.toFloat()))
            var found = false
            val startSearch = (fromDir + 6) % 8
            for (i in 0 until 8) {
                val dir = (startSearch + i) % 8
                val nx = cx + dx[dir]
                val ny = cy + dy[dir]
                if (nx in 0 until w && ny in 0 until h && mask[ny * w + nx]) {
                    fromDir = (dir + 4) % 8
                    cx = nx; cy = ny
                    found = true
                    break
                }
            }
            if (!found) break
            steps++
        } while ((cx != startX || cy != startY) && steps < maxSteps)
        return out.toTypedArray()
    }

    private fun nmsSingleClass(
        x1: FloatArray, y1: FloatArray, x2: FloatArray, y2: FloatArray,
        scores: FloatArray, iouThr: Float,
    ): List<Int> {
        val n = scores.size
        if (n == 0) return emptyList()
        val order = (0 until n).sortedByDescending { scores[it] }.toMutableList()
        val keep = ArrayList<Int>(n)
        val areas = FloatArray(n) { i -> max(0f, x2[i] - x1[i]) * max(0f, y2[i] - y1[i]) }
        while (order.isNotEmpty()) {
            val i = order[0]
            keep.add(i)
            if (order.size == 1) break
            val rest = order.subList(1, order.size)
            val survivors = ArrayList<Int>(rest.size)
            for (j in rest) {
                val xx1 = max(x1[i], x1[j])
                val yy1 = max(y1[i], y1[j])
                val xx2 = min(x2[i], x2[j])
                val yy2 = min(y2[i], y2[j])
                val interW = max(0f, xx2 - xx1)
                val interH = max(0f, yy2 - yy1)
                val inter = interW * interH
                val union = areas[i] + areas[j] - inter + 1e-9f
                if (inter / union <= iouThr) survivors.add(j)
            }
            order.clear(); order.addAll(survivors)
        }
        return keep
    }

    private fun sigmoid(x: Float): Float = 1f / (1f + exp(-x))
}