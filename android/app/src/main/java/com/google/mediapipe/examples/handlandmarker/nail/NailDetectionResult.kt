package com.google.mediapipe.examples.handlandmarker.nail

import android.graphics.PointF

/**
 * Kết quả phát hiện móng cho một ngón tay.
 *
 * Được tạo bởi [NailDetectionPipeline] sau khi chạy ROI extraction → segmentation → boundary detection.
 * OverlayView dùng các giá trị này (nếu `detected = true`) để scale/position/rotate móng
 * cho khớp với móng thật, thay vì dùng geometric approximation (mcpPipDist).
 *
 * Tất cả tọa độ và kích thước đều ở **image space** (pixel trên ảnh gốc),
 * đã được scale từ ROI-local sang toạ độ ảnh đầy đủ.
 *
 * @param fingerIndex   0=thumb, 1=index, 2=middle, 3=ring, 4=pinky
 * @param detected      true nếu phát hiện thành công boundary; false = fallback
 * @param nailCenterX   Tọa độ X tâm móng trên ảnh gốc (pixel)
 * @param nailCenterY   Tọa độ Y tâm móng trên ảnh gốc (pixel)
 * @param nailWidthPx   Chiều rộng móng phát hiện được (pixel trên ảnh gốc)
 * @param nailLengthPx   Chiều dài móng phát hiện được (pixel trên ảnh gốc)
 * @param rotationDeg    Góc xoay móng (độ, 0° = thẳng đứng dọc theo trục Y)
 * @param confidence     Độ tin cậy 0.0–1.0 (dựa trên nail area / ROI area + aspect ratio)
 * @param boundaryPoints Đường viền móng (ROI-local coords, optional — cho debug/preview)
 * @param nailArea       Số pixel được phân loại là móng (trong ROI)
 */
data class NailDetectionResult(
    val fingerIndex: Int,
    val detected: Boolean,
    val nailCenterX: Float,
    val nailCenterY: Float,
    val nailWidthPx: Float,
    val nailLengthPx: Float,
    val rotationDeg: Float,
    val confidence: Float,
    val boundaryPoints: List<PointF> = emptyList(),
    val nailArea: Int = 0,
    val boundaryPrincipalAngleDeg: Float? = null,
    val roiLocalRelX: Float? = null,
    val roiLocalRelY: Float? = null,
) {
    companion object {
        /**
         * Tạo kết quả "không phát hiện" — dùng khi ROI extraction hoặc segmentation thất bại.
         * OverlayView sẽ fallback sang geometric approximation (mcpPipDist).
         */
        fun failed(fingerIndex: Int): NailDetectionResult = NailDetectionResult(
            fingerIndex = fingerIndex,
            detected = false,
            nailCenterX = 0f,
            nailCenterY = 0f,
            nailWidthPx = 0f,
            nailLengthPx = 0f,
            rotationDeg = 0f,
            confidence = 0f,
        )
    }
}
