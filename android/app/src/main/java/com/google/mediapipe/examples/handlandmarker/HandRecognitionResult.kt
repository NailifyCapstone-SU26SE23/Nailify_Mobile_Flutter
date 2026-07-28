package com.google.mediapipe.examples.handlandmarker

data class HandRecognitionResult(
    val hands: List<List<Point>>
) {
    data class Point(
        val x: Float,
        val y: Float
    )
}
