/*
 * PolygonTracker.kt - Temporal smoothing for nail polygon / keypoints.
 *
 * Port of nail_desktop_app/smoothing.py PolygonTracker.
 *
 * Provides an Exponential Moving Average (EMA) filter that reduces jitter
 * across consecutive frames for live try-on. The tracker keeps state per
 * detection using a simple nearest-centroid association (Hungarian-style
 * greedy matching is overkill for 5-10 nails).
 *
 * Public API:
 *   val tracker = PolygonTracker(alpha = 0.5f, hysteresisFrames = 8)
 *   val smoothed = tracker.update(detections)
 *   // smoothed list has polygon + confidence EMA-blended across frames
 *
 * Two-pass matching:
 *   Pass 1: same-class matches (preferred - prevents two nails of different
 *           fingers from swapping IDs when centroids drift close).
 *   Pass 2: cross-class fills (recovers from cls_id flips without losing track).
 *
 * Debounce + hysteresis:
 *   - Tracks must appear for minConfirmFrames consecutive frames before
 *     being emitted (kills 1-frame false positives).
 *   - Tracks that disappear are kept alive for hysteresisFrames frames so
 *     they can be re-attached without re-arming (kills the "flash" when
 *     the model drops a nail for 1-3 frames during rotation).
 */
package com.google.mediapipe.examples.handlandmarker.ai

import android.graphics.PointF
import android.util.Log
import kotlin.math.hypot
import kotlin.math.max

class PolygonTracker(
    /** EMA smoothing factor in (0, 1]. Higher = more responsive, lower = smoother. */
    val alpha: Float = 0.5f,
    /** Max centroid distance (pixels) for steady-state association. */
    val distThreshold: Float = 150f,
    /** Min consecutive frames before a track is emitted to the overlay. */
    val minConfirmFrames: Int = 1,
    /** Frames a disappeared track is kept alive for re-attach. */
    val hysteresisFrames: Int = 8,
    /** Multiplier applied to distThreshold when re-attaching a hidden track. */
    val reattachDistMultiplier: Float = 1.5f,
) {
    init {
        require(alpha > 0f && alpha <= 1f) { "alpha must be in (0, 1], got $alpha" }
        require(minConfirmFrames >= 1) { "minConfirmFrames must be >= 1, got $minConfirmFrames" }
    }

    /** Per-track state snapshot (the previous frame's polygon/confidence/cls). */
    private data class TrackState(
        var polygon: List<PointF>,
        var confidence: Float,
        var clsId: Int,
    )

    private val beta = 1f - alpha

    private var nextId: Int = 0
    private val prev: MutableMap<Int, TrackState> = HashMap()
    private val frameCount: MutableMap<Int, Int> = HashMap()
    private val hiddenCount: MutableMap<Int, Int> = HashMap()
    private val confirmedIds: MutableSet<Int> = HashSet()

    private var lastUpdateCount: Int = 0

    /**
     * Blend each detection's polygon against the previous frame.
     *
     * Mutates each detection in-place (polygon, confidence, trackId) and
     * returns the subset of tracks that have been confirmed (either via
     * the debounce window or via hysteresis re-attach).
     *
     * Tracks that haven't been seen for `minConfirmFrames` consecutive frames
     * are filtered out of the returned list; their `trackId` is set to -1
     * so downstream consumers don't treat them as confirmed.
     */
    fun update(detections: List<NailDetection>): List<NailDetection> {
        if (detections.isEmpty()) {
            // Age all tracks. Drop anything past hysteresis.
            val toRemove = ArrayList<Int>()
            for (tid in prev.keys) {
                hiddenCount[tid] = (hiddenCount[tid] ?: 0) + 1
                if ((hiddenCount[tid] ?: 0) > hysteresisFrames) {
                    toRemove.add(tid)
                }
            }
            for (tid in toRemove) {
                prev.remove(tid)
                hiddenCount.remove(tid)
                frameCount.remove(tid)
                confirmedIds.remove(tid)
            }
            lastUpdateCount = 0
            return detections
        }

        // Associate current detections with previous tracks.
        val assignments = associate(detections)

        // Age tracks that weren't matched this frame.
        val activeIdsNow = HashSet<Int>()
        for ((_, tid) in assignments) {
            if (tid >= 0) activeIdsNow.add(tid)
        }
        for (tid in prev.keys) {
            if (tid !in activeIdsNow) {
                hiddenCount[tid] = (hiddenCount[tid] ?: 0) + 1
            }
        }

        // Apply EMA per assignment.
        for ((det, trackId) in assignments) {
            if (trackId < 0) {
                // Should not happen, but guard.
                continue
            }
            val prevState = prev[trackId]
            val wasHidden = prevState != null && (hiddenCount[trackId] ?: 0) > 0

            if (prevState == null) {
                // First time seeing this track - store as-is.
                prev[trackId] = TrackState(
                    polygon = det.polygon,
                    confidence = det.confidence,
                    clsId = det.clsId,
                )
            } else {
                // EMA blend polygon.
                det.polygon = blendPolygons(prevState.polygon, det.polygon)
                // EMA blend confidence to stabilize jitter
                // (YOLO can jump 0.59 -> 0.79 between adjacent frames).
                val prevConf = prevState.confidence
                det.confidence = alpha * det.confidence + beta * prevConf
                det.smoothedConfidence = det.confidence

                // Store the smoothed snapshot for next frame.
                prev[trackId] = TrackState(
                    polygon = det.polygon,
                    confidence = det.confidence,
                    clsId = det.clsId,
                )

                // Hysteresis: a track coming back from a brief hide keeps its
                // confirmed status, so it does NOT need to re-arm from frame 0.
                if (wasHidden && trackId in confirmedIds) {
                    frameCount[trackId] = max(
                        frameCount[trackId] ?: 0,
                        minConfirmFrames,
                    )
                }
            }

            // Tag the detection for downstream consumers.
            det.trackId = trackId
        }

        // Increment frame_count for surviving tracks.
        for (tid in activeIdsNow) {
            frameCount[tid] = (frameCount[tid] ?: 0) + 1
        }

        // Build the final list: keep confirmed tracks (debounce or hysteresis).
        val confirmedPairs = assignments.filter { (det, tid) ->
            tid >= 0 && (
                (frameCount[tid] ?: 0) >= minConfirmFrames ||
                    tid in confirmedIds
                )
        }

        if (confirmedPairs.size < assignments.size) {
            Log.d(
                TAG,
                "Debounce: ${confirmedPairs.size}/${assignments.size} tracks confirmed " +
                    "(minConfirmFrames=$minConfirmFrames)"
            )
        }

        // Mark all confirmed tracks so hysteresis re-attach keeps them.
        for ((_, tid) in confirmedPairs) {
            if (tid >= 0) confirmedIds.add(tid)
        }

        // GC tracks hidden for longer than the hysteresis window.
        val toRemoveGc = ArrayList<Int>()
        for (tid in prev.keys) {
            if (tid !in activeIdsNow && (hiddenCount[tid] ?: 0) > hysteresisFrames) {
                toRemoveGc.add(tid)
            }
        }
        for (tid in toRemoveGc) {
            prev.remove(tid)
            hiddenCount.remove(tid)
            frameCount.remove(tid)
            confirmedIds.remove(tid)
        }

        lastUpdateCount = confirmedPairs.size

        // Reset trackId on bounced detections so downstream consumers don't
        // treat them as confirmed.
        val confirmedIdsFinal = confirmedPairs.map { it.second }.toSet()
        for ((det, tid) in assignments) {
            if (tid !in confirmedIdsFinal) {
                det.trackId = -1
                det.smoothedConfidence = det.confidence
            }
        }

        return confirmedPairs.map { (det, _) -> det }
    }

    /** Clear all tracked state. Call when changing camera or scene. */
    fun reset() {
        prev.clear()
        frameCount.clear()
        hiddenCount.clear()
        confirmedIds.clear()
        nextId = 0
        Log.d(TAG, "PolygonTracker reset")
    }

    // ------------------------------------------------------------ helpers ----

    /**
     * Two-pass matching: prefer same-class tracks, then fall back to nearest.
     * Pass 1: same-class matches (preferred) - prevents two nails of
     *         different fingers from swapping IDs when centroids drift close.
     * Pass 2: cross-class fills - recovers from cls_id flips without losing track.
     */
    private fun associate(
        detections: List<NailDetection>,
    ): List<Pair<NailDetection, Int>> {
        val prevIds = prev.keys.toList()
        if (prevIds.isEmpty()) {
            // No prior state - assign fresh IDs.
            return detections.map { det -> det to allocId() }
        }

        val prevCentroids = HashMap<Int, PointF>()
        val prevCls = HashMap<Int, Int>()
        for (tid in prevIds) {
            val state = prev[tid] ?: continue
            prevCentroids[tid] = centroid(state.polygon)
            prevCls[tid] = state.clsId
        }

        val curCentroids = detections.map { centroid(it.polygon) }

        val used = HashSet<Int>()
        val result = ArrayList<Pair<NailDetection, Int>>(detections.size)

        // Re-attach threshold wider than the steady-state dist_threshold,
        // because the hand may have moved a lot while hidden.
        val reattachThreshold = distThreshold * reattachDistMultiplier

        // ---------- Pass 1: same-class matches (preferred). ----------
        for ((i, det) in detections.withIndex()) {
            val allowed = if (det.clsId >= 0) {
                prevCls.filterValues { it == det.clsId }.keys
            } else null
            val (bestTid, _) = pickBestTid(
                i, curCentroids, prevCentroids, used, allowed, reattachThreshold,
            )
            if (bestTid != null) {
                used.add(bestTid)
                result.add(det to bestTid)
            } else {
                // Placeholder; Pass 2 may overwrite.
                result.add(det to -1)
            }
        }

        // ---------- Pass 2: fill in unmatched detections with nearest tracks. ----------
        for (i in result.indices) {
            val (det, tid) = result[i]
            if (tid >= 0) continue
            val (bestTid, bestDist) = pickBestTid(
                i, curCentroids, prevCentroids, used, null, reattachThreshold,
            )
            val newTid = if (bestTid == null || bestDist > reattachThreshold) {
                allocId()
            } else {
                used.add(bestTid)
                bestTid
            }
            result[i] = det to newTid
        }
        return result
    }

    private fun pickBestTid(
        i: Int,
        curCentroids: List<PointF>,
        prevCentroids: Map<Int, PointF>,
        used: Set<Int>,
        allowed: Set<Int>?,
        maxDist: Float,
    ): Pair<Int?, Float> {
        val c = curCentroids[i]
        var bestTid: Int? = null
        var bestDist = Float.POSITIVE_INFINITY
        for ((tid, pc) in prevCentroids) {
            if (tid in used) continue
            if (allowed != null && tid !in allowed) continue
            val d = dist(c, pc)
            if (d < bestDist) {
                bestDist = d
                bestTid = tid
            }
        }
        if (bestDist > maxDist) {
            return null to bestDist
        }
        return bestTid to bestDist
    }

    private fun blendPolygons(
        prev: List<PointF>,
        curr: List<PointF>,
    ): List<PointF> {
        if (prev.size != curr.size) {
            // Different point count (model output jitter) - fallback to current.
            return curr
        }
        if (alpha >= 1f) return curr
        val out = ArrayList<PointF>(curr.size)
        for (k in prev.indices) {
            val p = prev[k]
            val c = curr[k]
            out.add(
                PointF(
                    alpha * c.x + beta * p.x,
                    alpha * c.y + beta * p.y,
                )
            )
        }
        return out
    }

    private fun centroid(polygon: List<PointF>): PointF {
        if (polygon.isEmpty()) return PointF(0f, 0f)
        var sx = 0f
        var sy = 0f
        for (p in polygon) {
            sx += p.x
            sy += p.y
        }
        val n = polygon.size
        return PointF(sx / n, sy / n)
    }

    private fun dist(a: PointF, b: PointF): Float {
        return hypot(a.x - b.x, a.y - b.y)
    }

    private fun allocId(): Int {
        val tid = nextId
        nextId += 1
        return tid
    }

    companion object {
        private const val TAG = "PolygonTracker"
    }
}
