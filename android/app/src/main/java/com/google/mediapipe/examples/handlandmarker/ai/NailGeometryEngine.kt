/*
 * NailGeometryEngine.kt - PCA + nail bed polygon slicing
 *
 * Port of nail_desktop_app/nail_geometry.py — operates on List<PointF>
 * polygons produced by NailAiEngine.
 *
 * Public surface:
 *   - getDirectionFromPolygonPca(polygon, hintVector?): PointF
 *   - cutPolygonAtRatio(polygon, direction, bedRatio): List<PointF>
 *
 * Coordinate convention: image space (y grows downward).
 * direction = unit vector from nail base -> tip.
 */
package com.google.mediapipe.examples.handlandmarker.ai

import android.graphics.PointF
import kotlin.math.atan2
import kotlin.math.sqrt

object NailGeometryEngine {

    private const val EPS = 1e-9f

    /**
     * Anatomical direction priors per finger, expressed as unit vectors in pixel-space
     * coordinates. These reflect the natural resting pose of each finger on a right
     * hand with the palm facing the camera:
     *
     *   clsId 0 = Index  → upward (−y), slightly leftward
     *   clsId 1 = Middle  → upward (−y), centered
     *   clsId 2 = Pinky  → upward (−y), slightly rightward
     *   clsId 3 = Ring   → upward (−y), slightly rightward
     *   clsId 4 = Thumb  → outward left (−x), slightly upward
     *
     * Used to disambiguate PCA direction (resolves 180° flip) and as a fallback
     * when neither MediaPipe nor temporal history provides a hint.
     *
     * Vectors are unit-normalized in pixel space. The magnitude is ~1 so they scale
     * correctly regardless of frame size (the actual magnitude comes from the
     * diagonal computed in the caller).
     */
    private val ANATOMICAL_PRIOR: Map<Int, PointF> = run {
        fun u(x: Float, y: Float): PointF {
            val m = sqrt(x * x + y * y)
            return PointF(x / m, y / m)
        }
        mapOf(
            0 to u(-0.15f, -1f),  // index  — tip leans left (toward thumb side)
            1 to u( 0.00f, -1f),  // middle — straight up
            2 to u( 0.20f, -1f),  // pinky  — tip leans right (away from thumb side)
            3 to u( 0.10f, -1f),  // ring   — intermediate between middle and pinky
            4 to u(-1.00f, -0.3f), // thumb  — outward toward left
        )
    }

    /**
     * Resolve the disambiguation vector for a given clsId. Priority:
     *   1. hintVector (MediaPipe PIP→TIP, already scaled to pixel space)
     *   2. Anatomical prior for clsId (unit pixel-space vector)
     *   3. null (fall back to naive "tip points upward" heuristic)
     */
    private fun resolveDisambigVector(
        hintVector: PointF?,
        clsId: Int,
    ): PointF? = hintVector ?: ANATOMICAL_PRIOR[clsId]

    /**
     * Compute the unit vector along the polygon's principal axis (base -> tip)
     * using PCA. If `hintVector` is provided, the result is flipped so it
     * points in the same general direction as the hint (resolves 180° ambiguity).
     *
     * @param polygon    The nail outline polygon (in image coords).
     * @param hintVector Optional unit vector (e.g. MediaPipe PIP -> TIP) used to
     *                   disambiguate direction.
     * @return Unit PointF pointing base -> tip.
     */
    fun getDirectionFromPolygonPca(
        polygon: List<PointF>,
        hintVector: PointF? = null,
    ): PointF = getDirectionFromPolygonPca(polygon, hintVector, clsId = -1)

    /**
     * Full overload that also accepts a finger class id for anatomical prior lookup.
     *
     * @param polygon    The nail outline polygon (in image coords).
     * @param hintVector Optional pixel-space unit vector (e.g. from MediaPipe).
     * @param clsId      YOLO class id (0=index, 1=middle, 2=pinky, 3=ring, 4=thumb).
     *                   Used to look up anatomical prior when hintVector is absent.
     * @return Unit PointF pointing base -> tip.
     */
    fun getDirectionFromPolygonPca(
        polygon: List<PointF>,
        hintVector: PointF?,
        clsId: Int,
    ): PointF {
        if (polygon.size < 2) return PointF(0f, -1f)

        // Centroid
        var cx = 0f
        var cy = 0f
        for (p in polygon) {
            cx += p.x
            cy += p.y
        }
        cx /= polygon.size
        cy /= polygon.size

        // Covariance matrix
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

        // Principal eigenvector of 2x2 symmetric matrix via closed-form.
        // trace = c00 + c11, det = c00 * c11 - c01^2
        // eigenvalues = (trace ± sqrt(trace^2 - 4 det)) / 2
        val trace = c00 + c11
        val det = c00 * c11 - c01 * c01
        val disc = trace * trace - 4f * det
        val sqrtDisc = if (disc > 0f) sqrt(disc) else 0f
        val lambda1 = (trace + sqrtDisc) / 2f

        // Eigenvector for lambda1: (c00 - lambda1, c01) (and equivalently (c01, c11 - lambda1))
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

        // Find tip and base indices by projecting polygon points onto pc1.
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
            if (proj > tipProj) {
                tipProj = proj
                tipX = p.x
                tipY = p.y
            }
            if (proj < baseProj) {
                baseProj = proj
                baseX = p.x
                baseY = p.y
            }
        }

        var dirX = tipX - baseX
        var dirY = tipY - baseY
        val mag = sqrt(dirX * dirX + dirY * dirY)
        if (mag < EPS) return PointF(0f, -1f)
        dirX /= mag
        dirY /= mag

        // Disambiguate: flip direction so it aligns with hint / anatomical prior.
        val disambig = resolveDisambigVector(hintVector, clsId)
        if (disambig != null) {
            val dot = dirX * disambig.x + dirY * disambig.y
            if (dot < 0f) {
                dirX = -dirX
                dirY = -dirY
            }
        } else {
            // Last resort: nail tip points upward in image space (y decreases).
            if (dirY > 0f) {
                dirX = -dirX
                dirY = -dirY
            }
        }

        return PointF(dirX, dirY)
    }

    /**
     * Cut the polygon at `bedRatio` from the base (along `direction`) and
     * return the resulting nail-bed sub-polygon.
     *
     * @param polygon   Full nail outline.
     * @param direction Unit vector base -> tip (from getDirectionFromPolygonPca).
     * @param bedRatio  Fraction of nail length to keep from the base (default 0.75).
     */
    fun cutPolygonAtRatio(
        polygon: List<PointF>,
        direction: PointF,
        bedRatio: Float = 0.75f,
    ): List<PointF> {
        if (polygon.size < 3) return polygon
        if (bedRatio <= 0f || bedRatio >= 1f) return polygon

        val dx = direction.x
        val dy = direction.y

        // Project every point onto the direction axis
        val projections = FloatArray(polygon.size) { i ->
            polygon[i].x * dx + polygon[i].y * dy
        }

        var minProj = Float.POSITIVE_INFINITY
        var maxProj = Float.NEGATIVE_INFINITY
        for (p in projections) {
            if (p < minProj) minProj = p
            if (p > maxProj) maxProj = p
        }
        val totalLength = maxProj - minProj
        if (totalLength < EPS) return polygon

        val cutoff = minProj + totalLength * bedRatio

        // Collect points that lie on the bed side (proj <= cutoff)
        val bedPoints = ArrayList<PointF>()
        for (i in polygon.indices) {
            if (projections[i] <= cutoff + EPS) {
                bedPoints.add(polygon[i])
            }
        }

        // Add two intersections of the cutoff line with polygon edges for a smooth cut
        val intersections = findCutoffEdgeIntersections(
            polygon, projections, cutoff,
        )
        if (intersections.size >= 2) {
            // Sort by projection on the perpendicular axis so the polygon stays convex
            val perpX = -dy
            val perpY = dx
            val sorted = intersections.sortedBy { it.x * perpX + it.y * perpY }
            bedPoints.add(sorted[0])
            bedPoints.add(sorted[1])
        }

        if (bedPoints.size < 3) return polygon
        return sortPolygonByAngle(bedPoints)
    }

    /**
     * Walk every polygon edge; collect intersections with the line
     * `direction . p == cutoff`.
     */
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

    /**
     * Sort polygon points by their angle around the centroid (counter-clockwise).
     */
    private fun sortPolygonByAngle(pts: List<PointF>): List<PointF> {
        if (pts.size < 3) return pts
        var cx = 0f
        var cy = 0f
        for (p in pts) {
            cx += p.x
            cy += p.y
        }
        cx /= pts.size
        cy /= pts.size
        return pts.sortedBy { atan2(it.y - cy, it.x - cx) }
    }
}