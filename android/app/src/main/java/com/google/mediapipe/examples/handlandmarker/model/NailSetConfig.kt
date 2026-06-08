package com.google.mediapipe.examples.handlandmarker.model

import com.google.gson.annotations.SerializedName

data class NailSetConfig(
    @SerializedName("shape")
    val shape: String = SHAPE_BALLERINA,

    @SerializedName("shapeImageSrc")
    val shapeImageSrc: String? = null,

    @SerializedName("length")
    val length: Float = 1.0f,

    @SerializedName("material")
    val material: String = MATERIAL_STANDARD,

    @SerializedName("gradient")
    val gradient: GradientConfig = GradientConfig(),

    @SerializedName("nails")
    val nails: List<FingerNailDesign> = defaultNails(),
) {
    companion object {
        const val SHAPE_BALLERINA = "ballerina"
        const val SHAPE_STILETTO = "stiletto"
        const val SHAPE_SQUOVAL = "squoval"

        const val MATERIAL_STANDARD = "standard"
        const val MATERIAL_METALLIC = "metallic"
        const val MATERIAL_IRIDESCENT = "iridescent"
        const val MATERIAL_MATTE = "matte"

        const val FINGER_COUNT = 5

        fun default(): NailSetConfig = NailSetConfig()

        fun defaultNails(): List<FingerNailDesign> =
            List(FINGER_COUNT) { FingerNailDesign() }
    }
}
