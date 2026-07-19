package com.google.mediapipe.examples.handlandmarker

import android.content.Context
import android.graphics.PointF
import org.json.JSONArray
import org.json.JSONObject

/**
 * Polygon đường viền móng tay được load từ assets/nail_polygons/<shape>.json.
 *
 * Polygon ở local space (theo MCP anchor):
 *   - gốc (0,0) là MCP anchor
 *   - x: -width/2 .. +width/2 (width cố định = 1000 ở local space)
 *   - y: 0 = MCP anchor, tăng dần về TIP
 *
 * Khi render, polygon sẽ được transform:
 *   - scale theo chiều dài ngón thật
 *   - rotate theo hướng ngón
 *   - translate đến MCP pixel coords
 */
data class NailPolygon(
    val shape: String,
    val nailBedRatio: Float,
    val localVertices: List<PointF>
) {
    companion object {
        /**
         * Load polygon từ assets. Trả null nếu không tìm thấy file.
         */
        fun load(context: Context, shape: String): NailPolygon? {
            val filename = "nail_polygons/$shape.json"
            return try {
                val text = context.assets.open(filename).bufferedReader().use { it.readText() }
                parse(shape, JSONObject(text))
            } catch (e: Exception) {
                null
            }
        }

        private fun parse(shape: String, json: JSONObject): NailPolygon {
            val bedRatio = json.optDouble("nailBedRatio", 0.6).toFloat()
            val arr = json.getJSONArray("polygon")
            val verts = mutableListOf<PointF>()
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                verts.add(PointF(o.getDouble("x").toFloat(), o.getDouble("y").toFloat()))
            }
            return NailPolygon(shape, bedRatio, verts)
        }

        /**
         * Tính bounding box của polygon ở local space.
         */
        fun bounds(verts: List<PointF>): FloatArray {
            var minX = Float.MAX_VALUE; var maxX = -Float.MAX_VALUE
            var minY = Float.MAX_VALUE; var maxY = -Float.MAX_VALUE
            for (v in verts) {
                if (v.x < minX) minX = v.x
                if (v.x > maxX) maxX = v.x
                if (v.y < minY) minY = v.y
                if (v.y > maxY) maxY = v.y
            }
            return floatArrayOf(minX, minY, maxX, maxY)
        }
    }
}

/** Transform polygon từ local space → pixel space theo anchor và hướng ngón. */
class PolygonTransformer {

        /**
         * Transform vertices theo anchor (MCP pixel coords), góc xoay (rad), chiều rộng & chiều dài (pixel).
         *
         * Điểm anchor trong local space = (450, 0) = bottom edge của polygon (cuticle line).
         * Sau transform, điểm này → (anchorX, anchorY) pixel coords.
         *
         * Canvas/Android convention: y dương hướng XUỐNG (y-down).
         * Local space convention: y dương hướng LÊN (về TIP).
         * → Cần flip y: ly = localH - v.y
         *
         * Verify với ballerina (localH=1420):
         *   v.y=0    (cuticle): ly = 1420 → sx = 0, sy = lengthPx → anchorX, anchorY+lengthPx (bottom)
         *   v.y=1420 (free edge): ly = 0 → sx = 0, sy = 0 → anchorX, anchorY (top)
         *   v.y=-20  (apex): ly = 1440 → sx = small, sy = lengthPx*1.01 → just below cuticle ✓
         */
        fun transform(
            verts: List<PointF>,
            anchorX: Float,
            anchorY: Float,
            angleRad: Float,
            widthPx: Float,
            lengthPx: Float
        ): List<PointF> {
            val (sn, cs) = kotlin.math.sin(angleRad) to kotlin.math.cos(angleRad)
            val bounds = NailPolygon.bounds(verts)
            val localW = bounds[2] - bounds[0]
            val localH = bounds[3] - bounds[1]
            val scaleX = widthPx / localW
            val scaleY = lengthPx / localH

            return verts.map { v ->
                // Flip y-axis: local space y (0 = cuticle, positive toward free edge / up)
                // → canvas space y (positive = downward / down).
                // Vertex at y=0 (cuticle) → ly = localH (bottom in canvas after rotation).
                // Vertex at y=localH (free edge) → ly = 0 (top in canvas after rotation).
                val lx = v.x
                val ly = localH - v.y
                // Scale
                val sx = lx * scaleX
                val sy = ly * scaleY
                // Rotate around MCP anchor (= local origin = (0,0))
                val rx = sx * cs - sy * sn
                val ry = sx * sn + sy * cs
                // Translate to MCP pixel coords
                PointF(anchorX + rx, anchorY + ry)
            }
        }
    }
