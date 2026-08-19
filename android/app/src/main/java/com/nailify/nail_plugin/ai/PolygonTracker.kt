/*
 * PolygonTracker.kt — Temporal smoothing (EMA + hysteresis + cls_id-aware matching).
 *
 * Port từ nail_desktop_app/smoothing.py PolygonTracker. Mỗi detection đầu vào
 * được match với track cũ qua (clsId, distance) rồi EMA-smooth. Track được
 * confirm khi số hit >= minConfirmFrames, hoặc khi hysteresis re-attach trong
 * vùng lân cận.
 */
package com.nailify.nail_plugin.ai

import android.graphics.PointF

class PolygonTracker(
    private val alpha: Float = 0.5f,
    private val distThreshold: Float = 150f,
    private val minConfirmFrames: Int = 1,
    private val hysteresisFrames: Int = 2,
    private val reattachDistMultiplier: Float = 1.5f,
) {
    private data class Track(
        var trackId: Int,
        var polygon: MutableList<PointF>,
        var clsId: Int,
        var confidence: Float,
        var hitFrames: Int,
        var missFrames: Int,
        var bboxCx: Float,
        var bboxCy: Float,
        var bboxW: Float,
        var bboxH: Float,
        var lastDet: NailDetection? = null,
    )

    private val tracks = ArrayList<Track>()
    private var nextId = 1

    fun reset() {
        tracks.clear()
        nextId = 1
    }

    fun update(detections: List<NailDetection>): List<NailDetection> {
        if (detections.isEmpty()) {
            for (t in tracks) {
                t.missFrames++
            }
            pruneOld()
            return emptyList()
        }

        val originalTrackCount = tracks.size
        val matched = BooleanArray(originalTrackCount)
        val outDetections = ArrayList<NailDetection>(detections.size)

        for (det in detections) {
            val centroidX = det.bboxCx
            val centroidY = det.bboxCy
            // Tìm track cùng clsId gần nhất trong distThreshold.
            var bestIdx = -1
            var bestDist = Float.POSITIVE_INFINITY
            for (i in 0 until originalTrackCount) {
                if (matched[i]) continue
                val t = tracks[i]
                if (t.clsId != det.clsId) continue
                val d = kotlin.math.hypot(
                    (centroidX - t.bboxCx).toDouble(),
                    (centroidY - t.bboxCy).toDouble()
                ).toFloat()
                if (d < bestDist) { bestDist = d; bestIdx = i }
            }
            val track = if (bestIdx >= 0 && bestDist <= distThreshold) tracks[bestIdx] else null
            if (track != null) {
                matched[bestIdx] = true
                // FIX #4: Hit đầu tiên sau khi re-attach (hitFrames == 0 trước khi ++,
                // hoặc track vừa được prune rồi tạo lại) → KHÔNG EMA; giữ nguyên
                // detection mới để anchor không bị "trôi" giữa polygon cũ (đã cached)
                // và polygon mới (sai lệch do async). Từ hit thứ 2 trở đi mới EMA.
                val effectiveAlpha = if (track.hitFrames == 0) 1.0f else alpha
                // EMA smooth.
                val smoothed = ArrayList<PointF>(det.polygon.size)
                for ((i, p) in det.polygon.withIndex()) {
                    val prev = track.polygon.getOrNull(i)
                    if (prev == null || effectiveAlpha >= 1.0f) {
                        smoothed.add(PointF(p.x, p.y))
                    } else {
                        smoothed.add(
                            PointF(
                                effectiveAlpha * p.x + (1 - effectiveAlpha) * prev.x,
                                effectiveAlpha * p.y + (1 - effectiveAlpha) * prev.y
                            )
                        )
                    }
                }
                track.polygon = smoothed
                track.bboxCx = effectiveAlpha * det.bboxCx + (1 - effectiveAlpha) * track.bboxCx
                track.bboxCy = effectiveAlpha * det.bboxCy + (1 - effectiveAlpha) * track.bboxCy
                track.bboxW  = effectiveAlpha * det.bboxW  + (1 - effectiveAlpha) * track.bboxW
                track.bboxH  = effectiveAlpha * det.bboxH  + (1 - effectiveAlpha) * track.bboxH
                track.confidence = effectiveAlpha * det.confidence + (1 - effectiveAlpha) * track.confidence
                track.hitFrames++
                track.missFrames = 0
                track.lastDet = det
            } else {
                val newId = nextId++
                tracks.add(
                    Track(
                        trackId = newId,
                        polygon = det.polygon.map { PointF(it.x, it.y) }.toMutableList(),
                        clsId = det.clsId,
                        confidence = det.confidence,
                        hitFrames = 1,
                        missFrames = 0,
                        bboxCx = det.bboxCx,
                        bboxCy = det.bboxCy,
                        bboxW = det.bboxW,
                        bboxH = det.bboxH,
                        lastDet = det,
                    )
                )
            }
        }

        // Mark unmatched tracks missFrames++.
        for (i in 0 until originalTrackCount) {
            if (!matched[i]) tracks[i].missFrames++
        }
        pruneOld()

        // Build output: confirmed tracks (hit >= minConfirmFrames) hoặc hysteresis.
        // Group by clsId and select the best track for each class (lowest missFrames, highest confidence)
        val bestTracks = HashMap<Int, Track>()
        for (t in tracks) {
            val confirmed = t.hitFrames >= minConfirmFrames || t.missFrames <= hysteresisFrames
            if (!confirmed) continue
            
            val existing = bestTracks[t.clsId]
            if (existing == null) {
                bestTracks[t.clsId] = t
            } else {
                if (t.missFrames < existing.missFrames || (t.missFrames == existing.missFrames && t.confidence > existing.confidence)) {
                    bestTracks[t.clsId] = t
                }
            }
        }
        
        for (t in bestTracks.values) {
            val base = t.lastDet
            if (base != null) {
                outDetections.add(
                    base.copy(
                        bboxCx = t.bboxCx,
                        bboxCy = t.bboxCy,
                        bboxW = t.bboxW,
                        bboxH = t.bboxH,
                        polygon = t.polygon.toList(),
                        confidence = t.confidence,
                        trackId = t.trackId,
                        clsName = FINGER_CLASS_NAMES.getOrElse(t.clsId) { "" }
                    )
                )
            } else {
                outDetections.add(
                    NailDetection(
                        bboxCx = t.bboxCx,
                        bboxCy = t.bboxCy,
                        bboxW = t.bboxW,
                        bboxH = t.bboxH,
                        polygon = t.polygon.toList(),
                        confidence = t.confidence,
                        clsId = t.clsId,
                        clsName = FINGER_CLASS_NAMES.getOrElse(t.clsId) { "" },
                        trackId = t.trackId,
                    )
                )
            }
        }
        return outDetections
    }

    private fun pruneOld() {
        val it = tracks.iterator()
        while (it.hasNext()) {
            val t = it.next()
            if (t.missFrames > hysteresisFrames) it.remove()
        }
    }
}