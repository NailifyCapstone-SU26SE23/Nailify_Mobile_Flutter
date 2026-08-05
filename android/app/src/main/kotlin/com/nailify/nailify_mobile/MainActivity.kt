package com.nailify.nailify_mobile

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val channelName = "com.nailify.ar/tryon"

    // Lưu MethodChannel.Result của launchSnapshot để dùng trong onActivityResult
    private var pendingSnapshotResult: MethodChannel.Result? = null
    private val requestCodeSnapshot = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable"    -> result.success(findArActivityClass() != null)
                    "launch"         -> launchAr(
                        call.argument<Map<*, *>>("config"),
                        call.argument<String>("mode") ?: "live",
                        result
                    )
                    "launchSnapshot" -> launchSnapshot(
                        call.argument<Map<*, *>>("config"),
                        result
                    )
                    else             -> result.notImplemented()
                }
            }
    }

    // -------------------------------------------------------------------------
    // Live / Photo mode
    // -------------------------------------------------------------------------

    private fun launchAr(config: Map<*, *>?, mode: String, result: MethodChannel.Result) {
        if (config == null) {
            result.error("INVALID_CONFIG", "AR config is missing.", null)
            return
        }

        val activityClass = findArActivityClass()
        if (activityClass == null) {
            result.error(
                "AR_ACTIVITY_NOT_FOUND",
                "Copy the native AR module into Android and register com.google.mediapipe.examples.handlandmarker.MainActivity.",
                null
            )
            return
        }

        val intent = Intent(this, activityClass).apply {
            putExtra("nail_set_config_json", JSONObject(config.toStringKeyMap()).toString())
            putExtra("try_on_entry", mode)
            putExtra("auto_open_picker", mode == "photo")
            // Truyền mode cho CameraFragment phân biệt UI
            putExtra("camera_mode", "live")
        }
        startActivity(intent)
        result.success(null)
    }

    // -------------------------------------------------------------------------
    // Snapshot mode: mở AR Activity với camera_mode=snapshot
    // -------------------------------------------------------------------------

    private fun launchSnapshot(config: Map<*, *>?, result: MethodChannel.Result) {
        val activityClass = findArActivityClass()
        if (activityClass == null) {
            result.error(
                "AR_ACTIVITY_NOT_FOUND",
                "AR module not found.",
                null
            )
            return
        }

        // Lưu result để dùng khi onActivityResult được gọi
        pendingSnapshotResult = result

        val intent = Intent(this, activityClass).apply {
            if (config != null) {
                putExtra("nail_set_config_json", JSONObject(config.toStringKeyMap()).toString())
            }
            putExtra("camera_mode", "snapshot")
            putExtra("try_on_entry", "camera")  // navigate tới CameraFragment
        }
        startActivityForResult(intent, requestCodeSnapshot)
    }

    /**
     * Được gọi khi AR Activity kết thúc ở Snapshot mode.
     * Đọc ảnh + JSON tọa độ, trả về Flutter qua pendingSnapshotResult.
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == requestCodeSnapshot) {
            val pending = pendingSnapshotResult
            pendingSnapshotResult = null

            if (pending == null) return

            if (resultCode == Activity.RESULT_OK && data != null) {
                val imagePath     = data.getStringExtra("snapshot_image_path")
                val landmarksJson = data.getStringExtra("snapshot_landmarks_json")

                if (imagePath != null && landmarksJson != null) {
                    // Trả Map về Flutter — Flutter parse thành SnapshotResult
                    pending.success(mapOf(
                        "imagePath"     to imagePath,
                        "landmarksJson" to landmarksJson
                    ))
                } else {
                    pending.error("SNAPSHOT_FAILED", "Native did not return image or landmarks.", null)
                }
            } else {
                // Người dùng bấm Back hoặc lỗi
                pending.error("SNAPSHOT_CANCELLED", "Snapshot was cancelled.", null)
            }
        }
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private fun findArActivityClass(): Class<*>? {
        val candidates = listOf(
            "com.google.mediapipe.examples.handlandmarker.HandLandmarkerActivity",
            "com.google.mediapipe.examples.handlandmarker.MainActivity",
            "com.nailify.ar.HandLandmarkerActivity",
        )
        return candidates.firstNotNullOfOrNull { className ->
            runCatching { Class.forName(className) }.getOrNull()
        }
    }

    private fun Map<*, *>.toStringKeyMap(): Map<String, Any?> {
        return entries.associate { entry ->
            entry.key.toString() to entry.value.toJsonCompatible()
        }
    }

    private fun Any?.toJsonCompatible(): Any? {
        return when (this) {
            is Map<*, *> -> this.toStringKeyMap()
            is List<*>   -> this.map { it.toJsonCompatible() }
            else         -> this
        }
    }
}
