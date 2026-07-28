package com.google.mediapipe.examples.handlandmarker

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.nio.FloatBuffer
import kotlin.math.max
import kotlin.math.min

class YoloNailOnnxRecognizer(private val context: Context) : AutoCloseable {
    private val environment: OrtEnvironment = OrtEnvironment.getEnvironment()
    private var session: OrtSession? = null

    fun recognize(bitmap: Bitmap): HandRecognitionResult {
        return anchorsFromBoxes(recognizeNails(bitmap))
    }

    fun recognizeNails(bitmap: Bitmap): List<NailDetection> {
        val ortSession = getSession()
        val input = prepareInput(bitmap)
        val inputName = ortSession.inputNames.first()
        OnnxTensor.createTensor(
            environment,
            FloatBuffer.wrap(input.tensor),
            longArrayOf(1, 3, MODEL_SIZE.toLong(), MODEL_SIZE.toLong())
        ).use { tensor ->
            ortSession.run(mapOf(inputName to tensor)).use { outputs ->
                val boxes = decodeBoxes(outputs[0].value, input, bitmap.width, bitmap.height)
                return nonMaxSuppression(boxes)
            }
        }
    }

    override fun close() {
        session?.close()
        session = null
    }

    private fun getSession(): OrtSession {
        session?.let { return it }
        return context.assets.open(MODEL_ASSET).use { input ->
            environment.createSession(input.readBytes(), OrtSession.SessionOptions())
        }.also { createdSession ->
            session = createdSession
        }
    }

    private fun prepareInput(bitmap: Bitmap): PreparedInput {
        val scale = min(MODEL_SIZE.toFloat() / bitmap.width, MODEL_SIZE.toFloat() / bitmap.height)
        val resizedWidth = (bitmap.width * scale).toInt().coerceAtLeast(1)
        val resizedHeight = (bitmap.height * scale).toInt().coerceAtLeast(1)
        val padX = (MODEL_SIZE - resizedWidth) / 2f
        val padY = (MODEL_SIZE - resizedHeight) / 2f

        val resized = Bitmap.createScaledBitmap(bitmap, resizedWidth, resizedHeight, true)
        val letterboxed = Bitmap.createBitmap(MODEL_SIZE, MODEL_SIZE, Bitmap.Config.ARGB_8888)
        Canvas(letterboxed).apply {
            drawColor(Color.BLACK)
            drawBitmap(resized, padX, padY, null)
        }

        val pixels = IntArray(MODEL_SIZE * MODEL_SIZE)
        letterboxed.getPixels(pixels, 0, MODEL_SIZE, 0, 0, MODEL_SIZE, MODEL_SIZE)

        val planeSize = MODEL_SIZE * MODEL_SIZE
        val tensor = FloatArray(3 * planeSize)
        for (index in pixels.indices) {
            val pixel = pixels[index]
            tensor[index] = Color.red(pixel) / 255f
            tensor[planeSize + index] = Color.green(pixel) / 255f
            tensor[2 * planeSize + index] = Color.blue(pixel) / 255f
        }

        return PreparedInput(tensor, scale, padX, padY)
    }

    private fun decodeBoxes(
        output: Any,
        input: PreparedInput,
        imageWidth: Int,
        imageHeight: Int
    ): List<NailDetection> {
        val raw = output as Array<Array<FloatArray>>
        val channels = raw[0]
        val count = channels[0].size
        val boxes = mutableListOf<NailDetection>()

        for (i in 0 until count) {
            val confidence = channels[4][i]
            if (confidence < CONFIDENCE_THRESHOLD) continue

            val centerX = channels[0][i]
            val centerY = channels[1][i]
            val width = channels[2][i]
            val height = channels[3][i]

            val left = ((centerX - width / 2f - input.padX) / input.scale).coerceIn(0f, imageWidth.toFloat())
            val top = ((centerY - height / 2f - input.padY) / input.scale).coerceIn(0f, imageHeight.toFloat())
            val right = ((centerX + width / 2f - input.padX) / input.scale).coerceIn(0f, imageWidth.toFloat())
            val bottom = ((centerY + height / 2f - input.padY) / input.scale).coerceIn(0f, imageHeight.toFloat())

            if (right > left && bottom > top) {
                boxes.add(NailDetection(left, top, right, bottom, confidence, imageWidth, imageHeight))
            }
        }

        return boxes.sortedByDescending { it.confidence }.take(MAX_CANDIDATES)
    }

    private fun nonMaxSuppression(detections: List<NailDetection>): List<NailDetection> {
        val selected = mutableListOf<NailDetection>()
        detections.forEach { candidate ->
            if (selected.none { iou(candidate, it) > IOU_THRESHOLD }) {
                selected.add(candidate)
            }
        }
        return selected.take(MAX_NAILS)
    }

    private fun anchorsFromBoxes(detections: List<NailDetection>): HandRecognitionResult {
        if (detections.isEmpty()) return HandRecognitionResult(emptyList())

        val landmarks = MutableList(21) { HandRecognitionResult.Point(0.5f, 0.5f) }
        detections.sortedBy { it.centerX }.forEachIndexed { index, detection ->
            val tipIndex = FINGER_TIP_INDICES.getOrNull(index) ?: return@forEachIndexed
            val jointIndex = tipIndex - 1
            landmarks[tipIndex] = HandRecognitionResult.Point(detection.centerXNormalized, detection.centerYNormalized)
            landmarks[jointIndex] = HandRecognitionResult.Point(
                detection.centerXNormalized,
                (detection.centerYNormalized + detection.normalizedHeight).coerceAtMost(1f)
            )
        }
        return HandRecognitionResult(listOf(landmarks))
    }

    private fun iou(a: NailDetection, b: NailDetection): Float {
        val left = max(a.left, b.left)
        val top = max(a.top, b.top)
        val right = min(a.right, b.right)
        val bottom = min(a.bottom, b.bottom)
        val intersection = max(0f, right - left) * max(0f, bottom - top)
        val union = a.area + b.area - intersection
        return if (union <= 0f) 0f else intersection / union
    }

    private data class PreparedInput(
        val tensor: FloatArray,
        val scale: Float,
        val padX: Float,
        val padY: Float
    )

    data class NailDetection(
        val left: Float,
        val top: Float,
        val right: Float,
        val bottom: Float,
        val confidence: Float,
        val imageWidth: Int,
        val imageHeight: Int
    ) {
        val area: Float = (right - left) * (bottom - top)
        val centerX: Float = (left + right) / 2f
        val centerXNormalized: Float = centerX / imageWidth
        val centerYNormalized: Float = ((top + bottom) / 2f) / imageHeight
        val normalizedHeight: Float = (bottom - top) / imageHeight
        val normalizedWidth: Float = (right - left) / imageWidth
    }

    companion object {
        private const val MODEL_ASSET = "nail-seg.onnx"
        private const val MODEL_SIZE = 640
        private const val CONFIDENCE_THRESHOLD = 0.25f
        private const val IOU_THRESHOLD = 0.45f
        private const val MAX_CANDIDATES = 80
        private const val MAX_NAILS = 5
        private val FINGER_TIP_INDICES = listOf(4, 8, 12, 16, 20)

    }
}
