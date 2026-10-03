package com.google.mediapipe.examples.handlandmarker.data.api

data class ApiResponse<T>(
    val status: Int,
    val message: String?,
    val data: T?
)
