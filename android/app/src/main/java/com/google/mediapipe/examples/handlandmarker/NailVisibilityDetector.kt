package com.google.mediapipe.examples.handlandmarker

import android.content.Context
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.atan2
import kotlin.math.hypot

data class NailVisibilityResult(
    val nailShown: Boolean,
    val confidence: Float
)

class NailVisibilityDetector(context: Context) {
    private val model: RandomForestModel = context.assets
        .open(MODEL_ASSET)
        .bufferedReader()
        .use { reader -> RandomForestModel.fromJson(JSONObject(reader.readText())) }

    fun detect(landmarks: List<NormalizedLandmark>): NailVisibilityResult {
        if (landmarks.size < REQUIRED_LANDMARK_COUNT) {
            return NailVisibilityResult(nailShown = false, confidence = 0f)
        }

        val features = calculateFeatures(landmarks)
        val confidence = model.predictPositiveProbability(features)
        return NailVisibilityResult(
            nailShown = confidence >= model.threshold,
            confidence = confidence
        )
    }

    private fun calculateFeatures(landmarks: List<NormalizedLandmark>): FloatArray {
        val depthFeatures = FINGER_TIPS.zip(FINGER_BASES).map { (tipIndex, baseIndex) ->
            landmarks[tipIndex].z() - landmarks[baseIndex].z()
        }
        val angleFeatures = FINGER_TIPS.zip(FINGER_JOINTS).map { (tipIndex, jointIndex) ->
            angleDegrees(landmarks[jointIndex], landmarks[tipIndex])
        }
        val avgFingerDepth = FINGER_TIPS
            .map { tipIndex -> landmarks[tipIndex].z() }
            .average()
            .toFloat()
        val fingerSpread = distance(landmarks[INDEX_TIP], landmarks[PINKY_TIP])

        return FloatArray(FEATURE_COUNT).also { features ->
            depthFeatures.forEachIndexed { index, value -> features[index] = value }
            angleFeatures.forEachIndexed { index, value -> features[index + depthFeatures.size] = value }
            features[8] = avgFingerDepth
            features[9] = fingerSpread
        }
    }

    private fun angleDegrees(from: NormalizedLandmark, to: NormalizedLandmark): Float {
        return Math.toDegrees(
            atan2((to.y() - from.y()).toDouble(), (to.x() - from.x()).toDouble())
        ).toFloat()
    }

    private fun distance(first: NormalizedLandmark, second: NormalizedLandmark): Float {
        return hypot(
            (first.x() - second.x()).toDouble(),
            (first.y() - second.y()).toDouble()
        ).toFloat()
    }

    private data class RandomForestModel(
        val threshold: Float,
        val trees: List<DecisionTree>
    ) {
        fun predictPositiveProbability(features: FloatArray): Float {
            if (trees.isEmpty()) return 0f
            val probabilitySum = trees.sumOf { tree ->
                tree.predictPositiveProbability(features).toDouble()
            }
            return (probabilitySum / trees.size).toFloat().coerceIn(0f, 1f)
        }

        companion object {
            fun fromJson(json: JSONObject): RandomForestModel {
                val treesJson = json.getJSONArray("trees")
                return RandomForestModel(
                    threshold = json.optDouble("threshold", DEFAULT_THRESHOLD.toDouble()).toFloat(),
                    trees = List(treesJson.length()) { index ->
                        DecisionTree.fromJson(treesJson.getJSONObject(index))
                    }
                )
            }
        }
    }

    private data class DecisionTree(
        val childrenLeft: IntArray,
        val childrenRight: IntArray,
        val feature: IntArray,
        val threshold: FloatArray,
        val positiveProbabilities: FloatArray
    ) {
        fun predictPositiveProbability(features: FloatArray): Float {
            var node = 0
            while (childrenLeft[node] != LEAF_NODE) {
                val featureIndex = feature[node]
                node = if (features[featureIndex] <= threshold[node]) {
                    childrenLeft[node]
                } else {
                    childrenRight[node]
                }
            }
            return positiveProbabilities[node]
        }

        companion object {
            fun fromJson(json: JSONObject): DecisionTree {
                return DecisionTree(
                    childrenLeft = json.getJSONArray("children_left").toIntArray(),
                    childrenRight = json.getJSONArray("children_right").toIntArray(),
                    feature = json.getJSONArray("feature").toIntArray(),
                    threshold = json.getJSONArray("threshold").toFloatArray(),
                    positiveProbabilities = json.getJSONArray("value").toPositiveProbabilityArray()
                )
            }
        }
    }

    companion object {
        private const val MODEL_ASSET = "nail_visibility_model.json"
        private const val DEFAULT_THRESHOLD = 0.8f
        private const val REQUIRED_LANDMARK_COUNT = 21
        private const val FEATURE_COUNT = 10
        private const val LEAF_NODE = -1

        private const val INDEX_TIP = 8
        private const val MIDDLE_TIP = 12
        private const val RING_TIP = 16
        private const val PINKY_TIP = 20

        private val FINGER_TIPS = listOf(INDEX_TIP, MIDDLE_TIP, RING_TIP, PINKY_TIP)
        private val FINGER_BASES = listOf(5, 9, 13, 17)
        private val FINGER_JOINTS = listOf(7, 11, 15, 19)
    }
}

private fun JSONArray.toIntArray(): IntArray {
    return IntArray(length()) { index -> getInt(index) }
}

private fun JSONArray.toFloatArray(): FloatArray {
    return FloatArray(length()) { index -> getDouble(index).toFloat() }
}

private fun JSONArray.toPositiveProbabilityArray(): FloatArray {
    return FloatArray(length()) { index ->
        getJSONArray(index).getJSONArray(0).getDouble(1).toFloat()
    }
}
