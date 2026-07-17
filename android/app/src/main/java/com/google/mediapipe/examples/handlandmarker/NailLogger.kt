package com.google.mediapipe.examples.handlandmarker

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.File

/**
 * Centralized logging utility for the Nailify app.
 * Writes structured NDJSON logs to a file and also to Android Logcat.
 *
 * Usage:
 *   NailLogger.d("CameraFragment", "onResults", mapOf("hands" to 1, "inferenceTime" to 45))
 *   NailLogger.e("HandLandmarkerHelper", "detectLiveStream", "Failed to detect hand", exception)
 */
object NailLogger {

    private const val TAG = "Nailify"
    private const val SESSION_ID = "11fb36"
    private var logFilePath: String? = null
    private var isEnabled = true

    // Log to both file (NDJSON) and Logcat
    fun d(component: String, stage: String, data: Map<String, Any?>) {
        log("DEBUG", component, stage, data, null)
    }

    fun i(component: String, stage: String, data: Map<String, Any?>) {
        log("INFO", component, stage, data, null)
    }

    fun w(component: String, stage: String, data: Map<String, Any?>) {
        log("WARN", component, stage, data, null)
    }

    fun e(component: String, stage: String, message: String, throwable: Throwable? = null) {
        val data = mutableMapOf<String, Any?>("errorMessage" to message)
        throwable?.let { data["stackTrace"] = it.stackTraceToString() }
        log("ERROR", component, stage, data, throwable)
    }

    // Pipeline stage constants for consistent naming
    object Stage {
        const val HAND_DETECT = "hand_detect"              // MediaPipe detects hand
        const val LANDMARK_EXTRACT = "landmark_extract"   // Landmarks extracted
        const val FINGER_VALIDATE = "finger_validate"     // Finger validity check (fold/occlusion)
        const val NAIL_DESIGN_LOAD = "nail_design_load"  // Nail design loaded
        const val NAIL_RENDER = "nail_render"             // Nails rendered on canvas
        const val SNAPSHOT_CAPTURE = "snapshot_capture"   // Camera frame captured
        const val SNAPSHOT_PROCESS = "snapshot_process"   // Snapshot processing
        const val BITMAP_SAVE = "bitmap_save"             // Bitmap saved to gallery
        const val DECORATION_LOAD = "decoration_load"     // Decoration bitmaps loaded
    }

    // Pipeline component constants
    object Component {
        const val CAMERA_FRAGMENT = "CameraFragment"
        const val GALLERY_FRAGMENT = "GalleryFragment"
        const val OVERLAY_VIEW = "OverlayView"
        const val HAND_LANDMARKER_HELPER = "HandLandmarkerHelper"
    }

    private fun log(
        level: String,
        component: String,
        stage: String,
        data: Map<String, Any?>,
        throwable: Throwable?
    ) {
        if (!isEnabled) return

        val timestamp = System.currentTimeMillis()

        // Build NDJSON entry
        val entry = JSONObject().apply {
            put("sessionId", SESSION_ID)
            put("level", level)
            put("component", component)
            put("stage", stage)
            put("message", "${component}/${stage}")
            put("data", JSONObject(data.filterValues { it != null }))
            put("timestamp", timestamp)
        }

        // Write to file
        logFilePath?.let { path ->
            try {
                File(path).appendText(entry.toString() + "\n")
            } catch (_: Exception) {
                // Silently fail file write
            }
        }

        // Write to Logcat
        val logTag = "$TAG/$component"
        val dataStr = data.entries.joinToString(", ") { "${it.key}=${it.value}" }
        when (level) {
            "DEBUG" -> Log.d(logTag, "[$stage] $dataStr")
            "INFO"  -> Log.i(logTag, "[$stage] $dataStr")
            "WARN"  -> Log.w(logTag, "[$stage] $dataStr")
            "ERROR" -> Log.e(logTag, "[$stage] $dataStr", throwable)
        }
    }

    /**
     * Initialize the logger with a file path.
     * Call this once from Application or MainActivity.
     */
    fun init(context: Context) {
        logFilePath = "${context.filesDir.absolutePath}/nailify_debug.log"
        d("NailLogger", "init", mapOf(
            "logFile" to logFilePath,
            "sessionId" to SESSION_ID
        ))
    }

    /**
     * Disable logging (for release builds).
     */
    fun disable() {
        isEnabled = false
    }

    /**
     * Clear the log file.
     */
    fun clearLog() {
        logFilePath?.let { path ->
            try {
                File(path).writeText("")
            } catch (_: Exception) {
                // Silently fail
            }
        }
    }

    /**
     * Get the current log file path.
     */
    fun getLogPath(): String? = logFilePath
}
