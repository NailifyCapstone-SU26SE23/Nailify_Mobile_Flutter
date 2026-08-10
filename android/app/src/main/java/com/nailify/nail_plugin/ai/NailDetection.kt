/*
 * NailDetection.kt — Data class cho 1 nail detection.
 *
 * Mirrors nail_desktop_app/onnx_inference.py NailDetection với một số field
 * bổ sung cho mobile pipeline (forwardVector, nailBedPolygon, designAssetPath).
 */
package com.nailify.nail_plugin.ai

import android.graphics.PointF

data class NailDetection(
    val bboxCx: Float = 0f,
    val bboxCy: Float = 0f,
    val bboxW: Float = 0f,
    val bboxH: Float = 0f,
    val polygon: List<PointF> = emptyList(),
    val confidence: Float = 0f,
    val clsId: Int = 0,
    val clsName: String = "",
    val trackId: Int = -1,
    // PCA direction (base -> tip), set bởi NailGeometryEngine.
    var pcaDirection: PointF? = null,
    // MediaPipe forward unit vector (scaled to pixel space). Dùng cho PCA flip.
    var forwardVector: PointF? = null,
    // Polygon đã slice ở bedRatio (chỉ giữ phần nail bed).
    val nailBedPolygon: List<PointF> = emptyList(),
    // Đường dẫn tới design asset (relative to assets/) cho renderer.
    val designAssetPath: String? = null,
)

/** Class names cho YOLO output — match training order. */
val FINGER_CLASS_NAMES: List<String> = listOf("index", "middle", "pinky", "ring", "thumb")