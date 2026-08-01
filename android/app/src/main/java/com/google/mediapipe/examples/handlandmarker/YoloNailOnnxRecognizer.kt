package com.google.mediapipe.examples.handlandmarker

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.max
import kotlin.math.min

class YoloNailOnnxRecognizer(private val context: Context) : AutoCloseable {
    private var interpreter: Interpreter? = null
    private val outputBoxes = Array(1) { Array(BOX_CHANNELS + CLASS_LABELS.size + MASK_CHANNELS) { FloatArray(BOX_COUNT) } }
    private val outputMasks = Array(1) { Array(MASK_CHANNELS) { Array(MASK_SIZE) { FloatArray(MASK_SIZE) } } }

    fun recognize(bitmap: Bitmap): HandRecognitionResult {
        return anchorsFromBoxes(recognizeNails(bitmap))
    }

    fun recognizeNails(bitmap: Bitmap): List<NailDetection> {
        val tflite = getInterpreter()
        val input = prepareInput(bitmap)
        tflite.runForMultipleInputsOutputs(
            arrayOf(input.tensor),
            mapOf(0 to outputBoxes, 1 to outputMasks)
        )
        return nonMaxSuppression(decodeBoxes(outputBoxes, input, bitmap.width, bitmap.height))
    }

    override fun close() {
        interpreter?.close()
        interpreter = null
    }

    private fun getInterpreter(): Interpreter {
        interpreter?.let { return it }
        return context.assets.open(MODEL_ASSET).use { input ->
            val modelBytes = input.readBytes()
            val modelBuffer = ByteBuffer.allocateDirect(modelBytes.size).apply {
                order(ByteOrder.nativeOrder())
                put(modelBytes)
                rewind()
            }
            Interpreter(
                modelBuffer,
                Interpreter.Options().apply {
                    setNumThreads(TFLITE_NUM_THREADS)
                }
            )
        }.also { createdInterpreter ->
            validateTensorContract(createdInterpreter)
            interpreter = createdInterpreter
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
        val tensor = ByteBuffer.allocateDirect(3 * planeSize * FLOAT_BYTES).apply {
            order(ByteOrder.nativeOrder())
        }
        for (index in pixels.indices) {
            val pixel = pixels[index]
            tensor.putFloat(index * FLOAT_BYTES, Color.red(pixel) / 255f)
            tensor.putFloat((planeSize + index) * FLOAT_BYTES, Color.green(pixel) / 255f)
            tensor.putFloat((2 * planeSize + index) * FLOAT_BYTES, Color.blue(pixel) / 255f)
        }
        tensor.rewind()

        return PreparedInput(tensor, scale, padX, padY)
    }

    private fun decodeBoxes(
        output: Array<Array<FloatArray>>,
        input: PreparedInput,
        imageWidth: Int,
        imageHeight: Int
    ): List<NailDetection> {
        val channels = output[0]
        require(channels.size >= BOX_CHANNELS + CLASS_LABELS.size) {
            "Unexpected YOLO output channels: ${channels.size}"
        }
        val count = channels[0].size
        val boxes = mutableListOf<NailDetection>()
        for (i in 0 until count) {
            var classId = 0
            var confidence = channels[BOX_CHANNELS][i]
            for (candidateClassId in 1 until CLASS_LABELS.size) {
                val score = channels[BOX_CHANNELS + candidateClassId][i]
                if (score > confidence) {
                    confidence = score
                    classId = candidateClassId
                }
            }
            if (confidence < CONFIDENCE_THRESHOLD) continue

            val centerX = toModelCoordinate(channels[0][i])
            val centerY = toModelCoordinate(channels[1][i])
            val width = toModelCoordinate(channels[2][i])
            val height = toModelCoordinate(channels[3][i])

            val left = ((centerX - width / 2f - input.padX) / input.scale).coerceIn(0f, imageWidth.toFloat())
            val top = ((centerY - height / 2f - input.padY) / input.scale).coerceIn(0f, imageHeight.toFloat())
            val right = ((centerX + width / 2f - input.padX) / input.scale).coerceIn(0f, imageWidth.toFloat())
            val bottom = ((centerY + height / 2f - input.padY) / input.scale).coerceIn(0f, imageHeight.toFloat())

            if (right > left && bottom > top) {
                boxes.add(
                    NailDetection(
                        left,
                        top,
                        right,
                        bottom,
                        confidence,
                        classId,
                        CLASS_LABELS[classId],
                        imageWidth,
                        imageHeight
                    )
                )
            }
        }

        return boxes.sortedByDescending { it.confidence }.take(MAX_CANDIDATES)
    }

    private fun nonMaxSuppression(detections: List<NailDetection>): List<NailDetection> {
        val selected = mutableListOf<NailDetection>()
        detections.forEach { candidate ->
            if (selected.none { it.classId == candidate.classId && iou(candidate, it) > IOU_THRESHOLD }) {
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

    private fun toModelCoordinate(value: Float): Float {
        return if (value <= NORMALIZED_COORDINATE_MAX) value * MODEL_SIZE else value
    }

    private data class PreparedInput(
        val tensor: ByteBuffer,
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
        val classId: Int,
        val className: String,
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
        private const val MODEL_ASSET = "best.tflite"
        private const val MODEL_SIZE = 320
        private const val BOX_COUNT = 2100
        private const val BOX_CHANNELS = 4
        private const val MASK_CHANNELS = 32
        private const val MASK_SIZE = 80
        private const val FLOAT_BYTES = 4
        private const val TFLITE_NUM_THREADS = 4
        private const val NORMALIZED_COORDINATE_MAX = 1.5f
        private const val CONFIDENCE_THRESHOLD = 0.1f
        private const val IOU_THRESHOLD = 0.45f
        private const val MAX_CANDIDATES = 80
        private const val MAX_NAILS = 5
        private val FINGER_TIP_INDICES = listOf(4, 8, 12, 16, 20)
        private val CLASS_LABELS = listOf("index", "middle", "pinky", "ring", "thumb")

    }

    private fun validateTensorContract(tflite: Interpreter) {
        val inputTensor = tflite.getInputTensor(0)
        require(inputTensor.dataType() == DataType.FLOAT32) {
            "Unexpected TFLite input type: ${inputTensor.dataType()}"
        }
        require(inputTensor.shape().contentEquals(intArrayOf(1, 3, MODEL_SIZE, MODEL_SIZE))) {
            "Unexpected TFLite input shape: ${inputTensor.shape().contentToString()}"
        }

        val boxesTensor = tflite.getOutputTensor(0)
        require(boxesTensor.dataType() == DataType.FLOAT32) {
            "Unexpected TFLite boxes output type: ${boxesTensor.dataType()}"
        }
        require(boxesTensor.shape().contentEquals(intArrayOf(1, BOX_CHANNELS + CLASS_LABELS.size + MASK_CHANNELS, BOX_COUNT))) {
            "Unexpected TFLite boxes output shape: ${boxesTensor.shape().contentToString()}"
        }

        val masksTensor = tflite.getOutputTensor(1)
        require(masksTensor.dataType() == DataType.FLOAT32) {
            "Unexpected TFLite masks output type: ${masksTensor.dataType()}"
        }
        require(masksTensor.shape().contentEquals(intArrayOf(1, MASK_CHANNELS, MASK_SIZE, MASK_SIZE))) {
            "Unexpected TFLite masks output shape: ${masksTensor.shape().contentToString()}"
        }
    }
}
