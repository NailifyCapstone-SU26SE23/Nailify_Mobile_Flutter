package com.nailify.nailify_mobile

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val channelName = "com.nailify.ar/tryon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(findArActivityClass() != null)
                    "launch" -> launchAr(
                        call.argument<Map<*, *>>("config"),
                        call.argument<String>("mode") ?: "live",
                        result
                    )
                    else -> result.notImplemented()
                }
            }
    }

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
        }
        startActivity(intent)
        result.success(null)
    }

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
            is List<*> -> this.map { it.toJsonCompatible() }
            else -> this
        }
    }
}
