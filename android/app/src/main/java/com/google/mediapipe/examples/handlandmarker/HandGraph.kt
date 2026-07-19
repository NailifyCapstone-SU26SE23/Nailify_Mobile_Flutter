package com.google.mediapipe.examples.handlandmarker

import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import kotlin.math.sqrt

/**
 * Canonical hand skeleton graph theo MediaPipe HAND_CONNECTIONS.
 *
 * Cấu trúc bàn tay cố định, KHÔNG phụ thuộc vào MediaPipe có predict trước hay không.
 * Mỗi ngón là 1 chuỗi landmark trong graph. Đây là cách xác định ngón chính xác
 * (không dùng heuristic hay dự đoán).
 *
 *           1(THUMB_CMC) ─── 2(THUMB_MCP) ─── 3(THUMB_IP) ─── 4(THUMB_TIP)
 *          ┌
 *          │
 *  0(WRIST)┴──── 5(INDEX_MCP) ─── 6(INDEX_PIP) ─── 7(INDEX_DIP) ─── 8(INDEX_TIP)
 *          │
 *          ├──── 9(MIDDLE_MCP) ── 10 ── 11 ── 12
 *          │
 *          ├──── 13(RING_MCP) ── 14 ── 15 ── 16
 *          │
 *          └──── 17(PINKY_MCP) ── 18 ── 19 ── 20
 *
 * Khi ngón bị cụt: TIP/DIP/PIP vẫn được MediaPipe "vẽ" ra nhưng cluster gần MCP,
 * nên ta đo MCP→TIP distance để biết ngón nào còn thật.
 */
object HandGraph {

    /** Schema khớp MediaPipe HAND_LANDMARK constants. */
    enum class Landmark(val index: Int, val landmarkName: String) {
        WRIST(0, "wrist"),
        THUMB_CMC(1, "thumb_cmc"),
        THUMB_MCP(2, "thumb_mcp"),
        THUMB_IP(3, "thumb_ip"),
        THUMB_TIP(4, "thumb_tip"),
        INDEX_MCP(5, "index_mcp"),
        INDEX_PIP(6, "index_pip"),
        INDEX_DIP(7, "index_dip"),
        INDEX_TIP(8, "index_tip"),
        MIDDLE_MCP(9, "middle_mcp"),
        MIDDLE_PIP(10, "middle_pip"),
        MIDDLE_DIP(11, "middle_dip"),
        MIDDLE_TIP(12, "middle_tip"),
        RING_MCP(13, "ring_mcp"),
        RING_PIP(14, "ring_pip"),
        RING_DIP(15, "ring_dip"),
        RING_TIP(16, "ring_tip"),
        PINKY_MCP(17, "pinky_mcp"),
        PINKY_PIP(18, "pinky_pip"),
        PINKY_DIP(19, "pinky_dip"),
        PINKY_TIP(20, "pinky_tip");

        companion object {
            fun byIndex(i: Int): Landmark? = values().firstOrNull { it.index == i }
        }
    }

    /**
     * Mỗi ngón = chuỗi landmark trong graph.
     *
     * Quan trọng: thumb dùng CMC→MCP→IP→TIP (4 landmark riêng),
     * các ngón khác dùng MCP→PIP→DIP→TIP.
     */
    enum class Finger(val graphId: String) {
        THUMB("thumb"),
        INDEX("index"),
        MIDDLE("middle"),
        RING("ring"),
        PINKY("pinky");

        companion object {
            /** Thứ tự vẽ nail (bỏ qua ngón cụt). */
            val DRAW_ORDER = listOf(THUMB, INDEX, MIDDLE, RING, PINKY)
        }
    }

    /**
     * Chuỗi landmark cho mỗi ngón — đây là GRAPH STRUCTURE,
     * không phải giả định về sự tồn tại ngón.
     */
    fun chain(finger: Finger): List<Landmark> = when (finger) {
        Finger.THUMB  -> listOf(Landmark.THUMB_CMC,  Landmark.THUMB_MCP,  Landmark.THUMB_IP,  Landmark.THUMB_TIP)
        Finger.INDEX  -> listOf(Landmark.INDEX_MCP,  Landmark.INDEX_PIP,  Landmark.INDEX_DIP,  Landmark.INDEX_TIP)
        Finger.MIDDLE -> listOf(Landmark.MIDDLE_MCP, Landmark.MIDDLE_PIP, Landmark.MIDDLE_DIP, Landmark.MIDDLE_TIP)
        Finger.RING   -> listOf(Landmark.RING_MCP,   Landmark.RING_PIP,   Landmark.RING_DIP,   Landmark.RING_TIP)
        Finger.PINKY  -> listOf(Landmark.PINKY_MCP,  Landmark.PINKY_PIP,  Landmark.PINKY_DIP,  Landmark.PINKY_TIP)
    }

    /** MCP landmark cho mỗi ngón — dùng làm ANCHOR cho nail polygon. */
    fun mcpOf(finger: Finger): Landmark = when (finger) {
        Finger.THUMB  -> Landmark.THUMB_MCP  // MCP (index 2), KHÔNG dùng CMC — CMC nằm ở gốc cổ tay, không phải gốc ngón cái
        Finger.INDEX  -> Landmark.INDEX_MCP
        Finger.MIDDLE -> Landmark.MIDDLE_MCP
        Finger.RING   -> Landmark.RING_MCP
        Finger.PINKY  -> Landmark.PINKY_MCP
    }

    /** TIP landmark cho mỗi ngón. */
    fun tipOf(finger: Finger): Landmark = when (finger) {
        Finger.THUMB  -> Landmark.THUMB_TIP
        Finger.INDEX  -> Landmark.INDEX_TIP
        Finger.MIDDLE -> Landmark.MIDDLE_TIP
        Finger.RING   -> Landmark.RING_TIP
        Finger.PINKY  -> Landmark.PINKY_TIP
    }

    /**
     * Khoảng cách Euclidean 3D giữa 2 landmark (hợp lệ cho mọi NormalizedLandmark).
     * Dùng để đo MCP→TIP và đánh giá ngón có tồn tại hay không.
     */
    fun dist(a: NormalizedLandmark, b: NormalizedLandmark): Float {
        val dx = b.x() - a.x()
        val dy = b.y() - a.y()
        val dz = (b.z() - a.z()).coerceIn(-1f, 1f)
        return sqrt(dx * dx + dy * dy + dz * dz)
    }

    /**
     * Xác định các ngón thực sự tồn tại trong hand landmarks.
     *
     * Quy tắc:
     *  - Tính MCP→TIP distance cho từng ngón.
     *  - Ngón có distance lớn hơn threshold (relative to MCP→PIP) → ngón thật.
     *  - Ngón có MCP, TIP gần nhau → ngón bị cụt/che → KHÔNG vẽ.
     *
     * @param landmarks      List<NormalizedLandmark> của 1 hand (21 điểm)
     * @param length_ratio   Ngưỡng MCP→TIP / MCP→PIP. Mặc định: 1.2
     *                       (giảm từ 1.5 → 1.2 để tránh skip ngón khi camera angle
     *                       hoặc mild occlusion làm MCP→TIP ratio giảm nhẹ.
     *                       Ngón thật thường có MCP→TIP ≥ 1.2× MCP→PIP.)
     * @return Map<Finger, Boolean> cho 5 ngón
     */
    fun detectPresentFingers(
        landmarks: List<NormalizedLandmark>,
        length_ratio: Float = 1.2f
    ): Map<Finger, Boolean> {
        if (landmarks.size < 21) return Finger.values().associateWith { false }

        return Finger.values().associateWith { finger ->
            val mcpIdx = mcpOf(finger).index
            val tipIdx = tipOf(finger).index
            val pipIdx = chain(finger).getOrNull(1)?.index ?: return@associateWith false

            val mcp = landmarks.getOrNull(mcpIdx) ?: return@associateWith false
            val tip = landmarks.getOrNull(tipIdx) ?: return@associateWith false
            val pip = landmarks.getOrNull(pipIdx) ?: return@associateWith false

            val mcpTip = dist(mcp, tip)
            val mcpPip = dist(mcp, pip)
            if (mcpPip < 1e-6f) return@associateWith false

            (mcpTip / mcpPip) >= length_ratio
        }
    }

    /**
     * Hướng ngón = vector MCP→TIP (normalized).
     *
     * Vector này **không phụ thuộc** TIP có hợp lệ hay không vì trong
     * cả 2 trường hợp MCP giữ nguyên ở lòng bàn tay — ngón cụt TIP sẽ
     * cụm gần MCP, hướng vẫn xấp xỉ trùng MCP→WRIST (nhỏ). Ngón thật,
     * hướng gần như song song MCP→PIP.
     *
     * @return Unit vector (dx, dy, dz) hoặc (0,0,0) nếu landmarks không đủ
     */
    fun fingerDirection(
        landmarks: List<NormalizedLandmark>,
        finger: Finger
    ): Triple<Float, Float, Float> {
        val mcp = landmarks.getOrNull(mcpOf(finger).index) ?: return Triple(0f, 0f, 0f)
        val tip = landmarks.getOrNull(tipOf(finger).index) ?: return Triple(0f, 0f, 0f)
        val dx = tip.x() - mcp.x()
        val dy = tip.y() - mcp.y()
        val dz = (tip.z() - mcp.z()).coerceIn(-1f, 1f)
        val len = sqrt(dx * dx + dy * dy + dz * dz)
        return if (len > 1e-6f) Triple(dx / len, dy / len, dz / len)
        else Triple(0f, 0f, 0f)
    }

    /**
     * Đếm số ngón còn thật (loại trừ ngón cụt/che).
     */
    fun countPresent(fingers: Map<Finger, Boolean>): Int =
        fingers.values.count { it }
}
