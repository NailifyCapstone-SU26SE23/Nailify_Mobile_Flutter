/*
 * NailAiEngine.kt - YOLO11n-Seg ONNX inference on Android.
 *
 * Port of nail_desktop_app/onnx_inference.py NailInference._parse_seg().
 * Designed for the 5-class nail model exported at imgsz=640.
 *
 *   output0: [1, 37, 8400]  (cx, cy, w, h, obj, cls[5], mask_coeffs[32])
 *   output1: [1, 32, 160, 160] mask prototypes
 *
 * Pipeline:
 *   Bitmap (ARGB)
 *     -> resize(640, 640) + RGB NCHW Float32 (HWC uint8 -> CHW float /255)
 *     -> OrtSession.run([output0, output1])
 *     -> parse bbox + class + mask coeffs
 *     -> sigmoid class scores -> conf = obj * max(cls)
 *     -> geometric filter + NMS
 *     -> for each detection: tensordot(coeffs[32], prototypes[32,160,160])
 *     -> crop mask to bbox -> threshold -> findContours -> approxPolyDP
 *     -> scale polygon back to original image coords
 *     -> NailDetection(polygon, cls, conf, ...)
 */
package com.google.mediapipe.examples.handlandmarker.ai

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.graphics.Bitmap
import android.graphics.PointF
import android.util.Log
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min

class NailAiEngine(
    private val context: Context,
    /** Path inside `assets/` to the ONNX model (default `nail_seg_5class.onnx`). */
    private val modelAssetPath: String = "nail_seg_5class.onnx",
    /** YOLO-Seg training size. The exported ONNX was trained at 640. */
    private val inputSize: Int = 640,
    /** Number of classes the model predicts (matches FINGER_CLASS_NAMES). */
    private val numClasses: Int = 5,
    /** Number of mask coefficients (YOLO11 default). */
    private val numMaskCoeffs: Int = 32,
    /** Fallback confidence threshold when a per-class entry is missing.
     *  Per-class thresholds (see [perClassThresholds]) override this for known fingers. */
    private val confThreshold: Float = 0.25f,
    /** Per-class confidence thresholds, keyed by class NAME (e.g. "thumb").
     *  Mirrors `config.PER_CLASS_CONF_THRESHOLD` in the desktop pipeline. */
    private val perClassThresholds: Map<String, Float> = emptyMap(),
    /** IoU threshold for NMS. */
    private val iouThreshold: Float = 0.45f,
    /** Mask binarization threshold after sigmoid. */
    private val maskThreshold: Float = 0.3f,
    /** Min/max contour area (in ORIGINAL image coords) to keep a detection. */
    private val minArea: Float = 300f,
    private val maxArea: Float = 8000f,
    /** Geometric filter bounds (in MODEL input coords, 640x640). Matches desktop. */
    private val minBboxW: Float = 25f,  // match desktop
    private val maxBboxW: Float = 80f,
    private val minBboxH: Float = 12f,
    private val maxBboxH: Float = 50f,
    private val maxAspectRatio: Float = 5.0f,
) {

    private val ortEnv: OrtEnvironment = OrtEnvironment.getEnvironment()
    private var session: OrtSession? = null
    private val inputName: String
        get() = session?.inputInfo?.keys?.firstOrNull() ?: DEFAULT_INPUT_NAME
    private val outputNames: List<String>
        get() = session?.outputInfo?.keys?.toList() ?: listOf("output0", "output1")

    @Volatile private var loaded = false

    /** Lazily load the model from `assets/`. Safe to call multiple times. */
    fun load(): Boolean {
        if (loaded) return true
        return try {
            val bytes = context.assets.open(modelAssetPath).use { it.readBytes() }
            session = ortEnv.createSession(bytes, OrtSession.SessionOptions())
            loaded = true
            Log.i(TAG, "Model loaded ($modelAssetPath), inputs=${session?.inputInfo?.keys}, outputs=${session?.outputInfo?.keys}")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load model: ${e.message}")
            false
        }
    }

    fun close() {
        session?.close()
        session = null
        loaded = false
    }

    /**
     * Run inference on `bitmap` (any size) and return a list of NailDetection.
     * Returns empty list if model isn't loaded yet.
     */
    fun run(bitmap: Bitmap): List<NailDetection> {
        if (!loaded && !load()) return emptyList()
        val sess = session ?: return emptyList()
        val origW = bitmap.width
        val origH = bitmap.height
        if (origW == 0 || origH == 0) return emptyList()

        // 1. Preprocess: LETTERBOX to inputSize x inputSize (giữ aspect ratio).
        //    Trước đây dùng createScaledBitmap → stretch ngang/dọc, model không thấy nail.
        //    YOLO được train với padding xám 114,114,114 (chuẩn letterbox).
        val scale = minOf(inputSize.toFloat() / origW, inputSize.toFloat() / origH)
        val newW = (origW * scale).toInt().coerceAtLeast(1)
        val newH = (origH * scale).toInt().coerceAtLeast(1)
        val padLeft = (inputSize - newW) / 2
        val padTop = (inputSize - newH) / 2
        val scaled = Bitmap.createScaledBitmap(bitmap, newW, newH, true)
        val resized = Bitmap.createBitmap(inputSize, inputSize, Bitmap.Config.ARGB_8888)
        val lc = android.graphics.Canvas(resized)
        lc.drawColor(android.graphics.Color.rgb(114, 114, 114))
        lc.drawBitmap(scaled, padLeft.toFloat(), padTop.toFloat(), null)
        if (scaled !== bitmap) scaled.recycle()

        val tensor = bitmapToNchwFloat(resized)
        val shape = longArrayOf(1, 3, inputSize.toLong(), inputSize.toLong())
        val buffer = java.nio.ByteBuffer
            .allocateDirect(tensor.size * 4)
            .order(java.nio.ByteOrder.nativeOrder())
            .asFloatBuffer()
        buffer.put(tensor)
        buffer.rewind()
        val inputTensor = OnnxTensor.createTensor(ortEnv, buffer, shape)

        // 2. Run.
        val rawOutputs = try {
            sess.run(mapOf(inputName to inputTensor))
        } catch (e: Exception) {
            Log.w(TAG, "onnx session.run failed: ${e.message}")
            inputTensor.close()
            return emptyList()
        }
        inputTensor.close()

        // Bitmap letterboxed chỉ dùng để tạo tensor — giải phóng ngay để tránh OOM.
        if (resized !== bitmap && !resized.isRecycled) {
            resized.recycle()
        }

        // 3. Extract raw outputs as flat float arrays.
        val outputList = rawOutputs.toList()
        rawOutputs.close()

        val out0 = (outputList.getOrNull(0)?.value as? Array<*>)
            ?: return emptyList()
        val out1 = (outputList.getOrNull(1)?.value as? Array<*>)
        // Output0: [1, 37, N] -> Array<Array<FloatArray>> of shape [1][37][N]
        val out0Arr = out0 as Array<Array<FloatArray>>
        val rawBoxes = out0Arr[0]                       // [37][N]
        val numChannels = rawBoxes.size                 // 37
        val numAnchors = rawBoxes[0].size               // 8400 (imgsz=640)
        // Transpose to [N][37] for easy per-anchor access.
        val preds = Array(numAnchors) { ArrayList<Float>(numChannels) }
        for (c in 0 until numChannels) {
            val ch = rawBoxes[c]
            for (n in 0 until numAnchors) preds[n].add(ch[n])
        }

        // 4. Parse class / objectness / bbox channels.
        // Layout (no obj): [cx, cy, w, h, cls(5), mask(32)]
        // Layout (with obj): [cx, cy, w, h, obj, cls(5), mask(32)] -> total 42
        // Modern YOLO11-Seg without separate objectness -> 4 + 5 + 32 = 41 (Ultralytics simplifies obj channel away).
        // We accept both by computing numMask = 32 and the rest stays implicit.
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
            cx[n] = row[0]
            cy[n] = row[1]
            bw[n] = row[2]
            bh[n] = row[3]
            if (hasObjChannel) obj[n] = sigmoid(row[objChannelIdx])
            for (c in 0 until numClasses) {
                clsRaw[n][c] = row[clsChannelStart + c]
            }
            for (c in 0 until numMaskCoeffs) {
                coeffs[n][c] = row[coeffChannelStart + c]
            }
        }

        // 5. Per-anchor best class probability + argmax id (sigmoid per class).
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

        // 6. Geometric filter (model coords). Mirrors desktop onnx_inference.py:
        //   - bbox width  ∈ [20, 100] px
        //   - bbox height ∈ [9, 60]   px
        //   - bbox center within input image (with 4 px padding)
        //   - bbox aspect ratio (w/h) ≤ 5.0  (rejects skin strips)
        //   - per-class confidence (when provided) overrides [confThreshold]
        val keepIdx = ArrayList<Int>()
        for (n in 0 until numAnchors) {
            // Per-class threshold lookup (uses class name, see FINGER_CLASS_NAMES).
            val clsName = FINGER_CLASS_NAMES.getOrNull(clsId[n])
            val perClassThresh = if (clsName != null) perClassThresholds[clsName] else null
            val requiredConf = perClassThresh ?: confThreshold
            if (conf[n] < requiredConf) continue
            if (bw[n] < minBboxW || bw[n] > maxBboxW) continue
            if (bh[n] < minBboxH || bh[n] > maxBboxH) continue
            if (cx[n] < 4f || cx[n] > inputSize.toFloat() - 4f) continue
            if (cy[n] < 4f || cy[n] > inputSize.toFloat() - 4f) continue
            if (bh[n] > 0f && (bw[n] / bh[n]) > maxAspectRatio) continue
            keepIdx.add(n)
        }
        if (keepIdx.isEmpty()) return emptyList()

        // 7. NMS (single class, in model coords).
        val x1 = FloatArray(keepIdx.size) { i -> cx[keepIdx[i]] - bw[keepIdx[i]] * 0.5f }
        val y1 = FloatArray(keepIdx.size) { i -> cy[keepIdx[i]] - bh[keepIdx[i]] * 0.5f }
        val x2 = FloatArray(keepIdx.size) { i -> cx[keepIdx[i]] + bw[keepIdx[i]] * 0.5f }
        val y2 = FloatArray(keepIdx.size) { i -> cy[keepIdx[i]] + bh[keepIdx[i]] * 0.5f }
        val scores = FloatArray(keepIdx.size) { i -> conf[keepIdx[i]] }
        val nmsOrder = nmsSingleClass(x1, y1, x2, y2, scores, iouThreshold)

        // 8. For each surviving detection: reconstruct mask -> contour -> polygon.
        // Letterbox unmap: polygon ở model space (inputSize x inputSize) → phải trừ
        // padding offset trước, rồi chia cho scale factor để về original image coords.
        val invScale = 1f / scale

        // Output1 prototypes: shape [1, 32, Ph, Pw]. Use only when present.
        val protoArr = out1 as? Array<Array<Array<FloatArray>>>
        // protoArr: [1][32][Ph][Pw]
        // We need to derive protoH/protoW from the actual runtime shape because the
        // OnnxTensor.unwrap returns nested arrays whose inner length may be flat or 2D.
        val protoResult: Triple<Array<FloatArray>?, Int, Int> = when {
            protoArr == null -> Triple(null, 0, 0)
            protoArr[0].isNotEmpty() && protoArr[0][0].isNotEmpty() &&
                protoArr[0][0][0] is FloatArray -> {
                // 4D layout: [1][32][Ph][Pw]
                val ph = protoArr[0][0].size
                val pw = protoArr[0][0][0].size
                // Flatten each [Ph][Pw] plane to a [Ph*Pw] flat array for fast tensordot.
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
            protoArr[0].isNotEmpty() -> {
                // Some exports return [1][32][Ph*Pw] already flat → reuse as-is.
                @Suppress("UNCHECKED_CAST")
                val flat = protoArr[0] as Array<FloatArray>
                val len = flat[0].size
                Triple(flat, len, 1)
            }
            else -> Triple(null, 0, 0)
        }
        val protoFlat = protoResult.first
        val maskProtoH = protoResult.second
        val maskProtoW = protoResult.third

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

            // 8a. Reconstruct mask at proto resolution, then resize to inputSize.
            var polygonModel = polygonFromMask(
                proto = protoFlat,
                protoH = maskProtoH,
                protoW = maskProtoW,
                coeffs = coeffs[globalIdx],
                detCx = detCx, detCy = detCy, detBw = detBw, detBh = detBh,
                inputSize = inputSize, maskThreshold = maskThreshold,
            )
            if (polygonModel == null) {
                // Fallback: rectangular bbox as polygon.
                polygonModel = arrayOf(
                    floatArrayOf(detCx - detBw * 0.5f, detCy - detBh * 0.5f),
                    floatArrayOf(detCx + detBw * 0.5f, detCy - detBh * 0.5f),
                    floatArrayOf(detCx + detBw * 0.5f, detCy + detBh * 0.5f),
                    floatArrayOf(detCx - detBw * 0.5f, detCy + detBh * 0.5f),
                )
            }
            if (polygonModel.size < 3) continue

            // 9. Polygon -> original image coords (unmap letterbox padding + scale).
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
            // maxArea được đo ở original image coords. Không nhân * 4 như trước.
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

    // ----------------------------------------------------------- helpers ----

    /** Convert a resized bitmap into an NCHW float32 RGB array normalized to [0,1]. */
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
            val r = android.graphics.Color.red(p) / 255f
            val g = android.graphics.Color.green(p) / 255f
            val b = android.graphics.Color.blue(p) / 255f
            out[rOff++] = r
            out[gOff++] = g
            out[bOff++] = b
        }
        return out
    }

    /** Reconstruct the per-detection mask and run findContours -> approxPolyDP. */
    private fun polygonFromMask(
        proto: Array<FloatArray>?,         // [32][Ph*Pw] or null
        protoH: Int,
        protoW: Int,
        coeffs: FloatArray,               // length 32
        detCx: Float, detCy: Float, detBw: Float, detBh: Float,
        inputSize: Int,
        maskThreshold: Float,
    ): Array<FloatArray>? {
        if (proto == null || protoH == 0 || protoW == 0) return null
        // 1. tensordot(coeffs[32], proto[32, H, W]) -> mask [H, W]
        val mask = FloatArray(protoH * protoW)
        for (idx in 0 until protoH * protoW) {
            var sum = 0f
            for (k in 0 until 32) sum += coeffs[k] * proto[k][idx]
            mask[idx] = sigmoid(sum)
        }
        // 2. Resize mask from (protoH, protoW) to (inputSize, inputSize). Use bilinear.
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
        // 3. Crop mask to bbox in inputSize coords (segmentation requirement).
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
        // 4. Marching-squares-ish contour: walk the edge between pixels.
        val polygon = marchingSquaresContour(cropped, bboxW, bboxH)
        if (polygon.size < 3) return null
        // 5. Translate back to full image coords.
        return Array(polygon.size) { i ->
            floatArrayOf(
                polygon[i][0] + x1m,
                polygon[i][1] + y1m,
            )
        }
    }

    /**
     * Lightweight outer-contour extractor using Moore-neighbor tracing on
     * the binarised mask. Returns vertices in (x, y) order, may be noisy —
     * downstream code approximates via PCA + cutPolygonAtRatio, which is
     * robust to noisy outlines.
     */
    private fun marchingSquaresContour(mask: BooleanArray, w: Int, h: Int): Array<FloatArray> {
        // Find a starting pixel (leftmost topmost).
        var startX = -1
        var startY = -1
        for (y in 0 until h) {
            for (x in 0 until w) {
                if (mask[y * w + x]) { startX = x; startY = y; break }
            }
            if (startX >= 0) break
        }
        if (startX < 0) return emptyArray()

        // Moore neighborhood offsets, clockwise starting from west.
        val dx = intArrayOf(-1, -1, 0, 1, 1, 1, 0, -1)
        val dy = intArrayOf(0, -1, -1, -1, 0, 1, 1, 1)

        val out = ArrayList<FloatArray>(32)
        var cx = startX
        var cy = startY
        // Initial entry direction: came from the west.
        var fromDir = 0
        val maxSteps = w * h * 4
        var steps = 0
        do {
            out.add(floatArrayOf(cx.toFloat(), cy.toFloat()))
            var found = false
            val startSearch = (fromDir + 6) % 8   // start at "back-left"
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

    /** NMS for axis-aligned boxes (in model coords). Returns indices into the input arrays. */
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

    companion object {
        private const val TAG = "NailAiEngine"
        private const val DEFAULT_INPUT_NAME = "images"
    }
}