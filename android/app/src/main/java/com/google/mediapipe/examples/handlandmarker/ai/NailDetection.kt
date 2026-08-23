/*
 * NailDetection.kt - Data class for a single detected nail
 *
 * Port of nail_desktop_app/onnx_inference.py NailDetection (dataclass).
 * Holds YOLO-Seg detection data plus optional MediaPipe direction hint
 * and PCA-computed nail bed slice.
 *
 * All coordinates (polygon, bbox, etc.) are in the original image space
 * (not in model input space).
 */
package com.google.mediapipe.examples.handlandmarker.ai

import android.graphics.PointF

/**
 * A single detected nail from YOLO-Seg 5-class inference.
 *
 * @property bboxCx     Bounding box center X (pixels, original image)
 * @property bboxCy     Bounding box center Y (pixels, original image)
 * @property bboxW      Bounding box width  (pixels, original image)
 * @property bboxH      Bounding box height (pixels, original image)
 * @property polygon    Full nail outline extracted from segmentation mask contours
 * @property confidence Detection confidence score [0, 1]
 * @property clsId      Class id: 0=index, 1=middle, 2=pinky, 3=ring, 4=thumb
 * @property clsName    Human-readable class name
 * @property forwardVector  Unit vector (dx, dy) from MediaPipe PIP to TIP (base -> tip)
 * @property nailBedPolygon Polygon slice representing the nail bed (base 75% of full nail)
 * @property pcaDirection   PCA-computed unit vector (base -> tip) for the polygon
 * @property fingerName     Finger name assigned by MediaPipe matching ("thumb", "index",
 *                          "middle", "ring", "pinky"). Empty if not matched.
 * @property designAssetPath Path (relative to `assets/`) of the design PNG to render on
 *                           this nail. Null falls back to the default design.
 */
data class NailDetection(
    val bboxCx: Float,
    val bboxCy: Float,
    val bboxW: Float,
    val bboxH: Float,
    /** Mutable so PolygonTracker can EMA-blend in-place (mirror smoothing.py). */
    var polygon: List<PointF>,
    /** Mutable so PolygonTracker can EMA-blend in-place (mirror smoothing.py). */
    var confidence: Float,
    val clsId: Int,
    val clsName: String,
    val forwardVector: PointF? = null,
    val nailBedPolygon: List<PointF> = emptyList(),
    val pcaDirection: PointF? = null,
    val fingerName: String = "",
    val designAssetPath: String? = null,
) {
    /**
     * Track id assigned by PolygonTracker. -1 when untracked (e.g. just
     * created by AI engine, or rejected by the tracker's debounce).
     * Mutable so the tracker can update in-place without re-allocating
     * the data class (mirror smoothing.py).
     */
    var trackId: Int = -1

    /**
     * EMA-smoothed confidence. Updated by PolygonTracker; the renderer
     * should read this value rather than [confidence] if it is set
     * (>= 0). When the tracker is disabled this remains == confidence.
     */
    var smoothedConfidence: Float = confidence
    /** Axis-aligned bounding box (x1, y1, x2, y2) in original image coords. */
    val bboxXyxy: FloatArray
        get() = floatArrayOf(
            bboxCx - bboxW / 2f,
            bboxCy - bboxH / 2f,
            bboxCx + bboxW / 2f,
            bboxCy + bboxH / 2f,
        )
}

/**
 * The 5 finger classes the YOLO-Seg model was trained on.
 * Order matches the dataset (index/middle/pinky/ring/thumb).
 */
val FINGER_CLASS_NAMES: List<String> =
    listOf("index", "middle", "pinky", "ring", "thumb")