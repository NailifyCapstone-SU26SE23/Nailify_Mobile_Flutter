package com.google.mediapipe.examples.handlandmarker.model

import com.google.gson.annotations.SerializedName

data class GradientConfig(
    @SerializedName("enabled")
    val enabled: Boolean = false,

    @SerializedName("type")
    val type: String = TYPE_LINEAR,

    @SerializedName("stops")
    val stops: List<String> = DEFAULT_STOPS,

    @SerializedName("stopCount")
    val stopCount: Int = 2,
) {
    companion object {
        const val TYPE_LINEAR = "linear"
        const val TYPE_HORIZONTAL = "horizontal"
        const val TYPE_RADIAL = "radial"

        val DEFAULT_STOPS = listOf("#FF4081", "#FFFFFF", "#000000")
    }
}
