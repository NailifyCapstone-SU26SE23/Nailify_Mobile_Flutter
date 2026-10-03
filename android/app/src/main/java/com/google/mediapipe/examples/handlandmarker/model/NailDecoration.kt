package com.google.mediapipe.examples.handlandmarker.model

import com.google.gson.annotations.SerializedName

data class NailDecoration(
    @SerializedName("id")
    val id: String,

    @SerializedName("type")
    val type: String,

    @SerializedName("componentId")
    val componentId: String? = null,

    @SerializedName("imageSrc")
    val imageSrc: String,

    @SerializedName("x")
    val x: Float = 0f,

    @SerializedName("y")
    val y: Float = 0f,

    @SerializedName("scale")
    val scale: Float = DEFAULT_PATTERN_SCALE,

    @SerializedName("rotation")
    val rotation: Float = 0f,
) {
    companion object {
        const val TYPE_PATTERN = "pattern"
        const val TYPE_GEM = "gem"

        const val DEFAULT_PATTERN_SCALE = 0.35f
        const val DEFAULT_GEM_SCALE = 0.2f
    }
}
