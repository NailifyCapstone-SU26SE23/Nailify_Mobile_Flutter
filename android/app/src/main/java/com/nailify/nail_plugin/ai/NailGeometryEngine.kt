/*
 * NailGeometryEngine.kt — PCA + nail-bed polygon slicing.
 *
 * Port từ nail_desktop_app/nail_geometry.py. Coordinate convention: image
 * space (y grows downward). direction = unit vector base -> tip.
 */
package com.nailify.nail_plugin.ai

import android.graphics.PointF
import kotlin.math.atan2
import kotlin.math.sqrt

object NailGeometryEngine {

    private const val EPS = 1e-9f

    private val ANATOMICAL_PRIOR: Map<Int, PointF> = run {
        fun u(x: Float, y: Float): PointF {
            val m = sqrt(x * x + y * y)
            return PointF(x / m, y / m)
        }
        mapOf(
            0 to u(-0.15f, -1f),
            1 to u( 0.00f, -1f),
            2 to u( 0.20f, -1f),
            3 to u( 0.10f, -1f),
            4 to u(-1.00f, -0.3f),
        )
    }

    private fun resolveDisambigVector(hintVector: PointF?, clsId: Int): PointF? =
        hintVector ?: ANATOMICAL_PRIOR[clsId]

    fun getDirectionFromPolygonPca(
        polygon: List<PointF>,
        hintVector: PointF? = null,
    ): PointF = getDirectionFromPolygonPca(polygon, hintVector, clsId = -1)

    fun getDirectionFromPolygonPca(
        polygon: List<PointF>,
        hintVector: PointF?,
        clsId: Int,
    ): PointF {
        if (polygon.size < 2) return PointF(0f, -1f)
        var cx = 0f
        var cy = 0f
        for (p in polygon) { cx += p.x; cy += p.y }
        cx /= polygon.size
        cy /= polygon.size

        var c00 = 0f
        var c01 = 0f
        var c11 = 0f
        for (p in polygon) {
            val dx = p.x - cx
            val dy = p.y - cy
            c00 += dx * dx
            c01 += dx * dy
            c11 += dy * dy
        }
        val trace = c00 + c11
        val det = c00 * c11 - c01 * c01
        val disc = trace * trace - 4f * det
        val sqrtDisc = if (disc > 0f) sqrt(disc) else 0f
        val lambda1 = (trace + sqrtDisc) / 2f

        var pc1x = c00 - lambda1
        var pc1y = c01
        val pc1Mag = sqrt(pc1x * pc1x + pc1y * pc1y)
        if (pc1Mag < EPS) {
            pc1x = -c01
            pc1y = c11 - lambda1
            val altMag = sqrt(pc1x * pc1x + pc1y * pc1y)
            if (altMag < EPS) return PointF(0f, -1f)
            pc1x /= altMag
            pc1y /= altMag
        } else {
            pc1x /= pc1Mag
            pc1y /= pc1Mag
        }

        var tipProj = Float.NEGATIVE_INFINITY
        var baseProj = Float.POSITIVE_INFINITY
        var tipX = cx
        var tipY = cy
        var baseX = cx
        var baseY = cy
        for (p in polygon) {
            val dx = p.x - cx
            val dy = p.y - cy
            val proj = dx * pc1x + dy * pc1y
            if (proj > tipProj) { tipProj = proj; tipX = p.x; tipY = p.y }
            if (proj < baseProj) { baseProj = proj; baseX = p.x; baseY = p.y }
        }
        var dirX = tipX - baseX
        var dirY = tipY - baseY
        val mag = sqrt(dirX * dirX + dirY * dirY)
        if (mag < EPS) return PointF(0f, -1f)
        dirX /= mag
        dirY /= mag

        val disambig = resolveDisambigVector(hintVector, clsId)
        if (disambig != null) {
            val dot = dirX * disambig.x + dirY * disambig.y
            if (dot < 0f) { dirX = -dirX; dirY = -dirY }
        } else if (dirY > 0f) {
            dirX = -dirX; dirY = -dirY
        }
        return PointF(dirX, dirY)
    }

    fun cutPolygonAtRatio(
        polygon: List<PointF>,
        direction: PointF,
        bedRatio: Float = 0.75f,
    ): List<PointF> {
        if (polygon.size < 3) return polygon
        if (bedRatio <= 0f || bedRatio >= 1f) return polygon
        val dx = direction.x
        val dy = direction.y
        val projections = FloatArray(polygon.size) { i -> polygon[i].x * dx + polygon[i].y * dy }
        var minProj = Float.POSITIVE_INFINITY
        var maxProj = Float.NEGATIVE_INFINITY
        for (p in projections) {
            if (p < minProj) minProj = p
            if (p > maxProj) maxProj = p
        }
        val totalLength = maxProj - minProj
        if (totalLength < EPS) return polygon
        val cutoff = minProj + totalLength * bedRatio
        val bedPoints = ArrayList<PointF>()
        for (i in polygon.indices) {
            if (projections[i] <= cutoff + EPS) bedPoints.add(polygon[i])
        }
        val intersections = findCutoffEdgeIntersections(polygon, projections, cutoff)
        if (intersections.size >= 2) {
            val perpX = -dy
            val perpY = dx
            val sorted = intersections.sortedBy { it.x * perpX + it.y * perpY }
            bedPoints.add(sorted[0])
            bedPoints.add(sorted[1])
        }
        if (bedPoints.size < 3) return polygon
        return sortPolygonByAngle(bedPoints)
    }

    private fun findCutoffEdgeIntersections(
        pts: List<PointF>,
        projections: FloatArray,
        cutoff: Float,
    ): List<PointF> {
        val out = ArrayList<PointF>()
        val n = pts.size
        for (i in 0 until n) {
            val p1 = pts[i]
            val p2 = pts[(i + 1) % n]
            val proj1 = projections[i]
            val proj2 = projections[(i + 1) % n]
            val side1 = proj1 <= cutoff
            val side2 = proj2 <= cutoff
            if (side1 != side2) {
                val denom = proj2 - proj1
                val t = if (kotlin.math.abs(denom) < EPS) 0f
                else ((cutoff - proj1) / denom).coerceIn(0f, 1f)
                val ix = p1.x + t * (p2.x - p1.x)
                val iy = p1.y + t * (p2.y - p1.y)
                out.add(PointF(ix, iy))
            }
        }
        return out
    }

    private fun sortPolygonByAngle(pts: List<PointF>): List<PointF> {
        if (pts.size < 3) return pts
        var cx = 0f
        var cy = 0f
        for (p in pts) { cx += p.x; cy += p.y }
        cx /= pts.size; cy /= pts.size
        return pts.sortedBy { atan2(it.y - cy, it.x - cx) }
    }
}