package com.google.mediapipe.examples.handlandmarker.model

import com.google.gson.annotations.SerializedName

data class FingerNailDesign(
    @SerializedName("color")
    val color: String = DEFAULT_COLOR,

    @SerializedName("decorations")
    val decorations: List<NailDecoration> = emptyList(),

    @SerializedName("customShapeSrc")
    val customShapeSrc: String? = null,

    @SerializedName("gradient")
    val gradient: GradientConfig? = null,
) {
    companion object {
        const val DEFAULT_COLOR = "#FF4081"
    }
}
