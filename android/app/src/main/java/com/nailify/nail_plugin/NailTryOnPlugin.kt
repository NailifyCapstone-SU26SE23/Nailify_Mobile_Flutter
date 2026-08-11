/*
 * NailTryOnPlugin.kt — Native entry point cho Flutter plugin.
 *
 * Plugin này quản lý:
 *   - MethodChannel "com.nailify.ar/tryon" : start/stop session, manual offset, snapshot
 *   - EventChannel  "com.nailify.ar/tryon/events" : frame stats, detections count
 *
 * Mỗi session tạo ra 1 NailTryOnSession độc lập, gắn liền với 1 SurfaceView
 * (NailSurfaceView) do Flutter dựng qua AndroidView.
 *
 * Lifecycle:
 *   onAttachedToEngine   -> khởi tạo channels
 *   onDetachedFromEngine -> cleanup
 *   startSession         -> tạo session mới
 *   stopSession          -> giải phóng camera + AI engines
 */
package com.nailify.nail_plugin

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.nailify.nail_plugin.session.NailTryOnSession
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class NailTryOnPlugin : FlutterPlugin, ActivityAware {

    companion object {
        private const val TAG = "NailTryOnPlugin"
        const val METHOD_CHANNEL = "com.nailify.ar/tryon"
        const val EVENT_CHANNEL  = "com.nailify.ar/tryon/events"

        // Active plugin instance (1 plugin / Flutter engine).
        // Used by NailSurfaceViewFactory to bind surface holder to session.
        private var activeInstance: NailTryOnPlugin? = null
        fun peekActiveInstance(): NailTryOnPlugin? = activeInstance
    }

    private var context: Context? = null
    private var activity: Activity? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null

    // Session hiện tại (chỉ 1 session tại 1 thời điểm).
    private var session: NailTryOnSession? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Lưu pending surface holder — khi surfaceCreated chạy TRƯỚC startSession,
    // holder bị bỏ lỡ. Khi session được tạo, ta bind holder ngay.
    private var pendingHolder: android.view.SurfaceHolder? = null

    // -------------------------------------------------------------------------
    // FlutterPlugin lifecycle
    // -------------------------------------------------------------------------

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        activeInstance = this
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).apply {
            setMethodCallHandler { call, result -> onMethodCall(call, result) }
        }
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).apply {
            setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    session?.setEventSink(events)
                }
                override fun onCancel(arguments: Any?) {
                    session?.setEventSink(null)
                    eventSink = null
                }
            })
        }
        // Register SurfaceView factory để Flutter AndroidView tạo ra native view.
        binding.platformViewRegistry.registerViewFactory(
            "nail_plugin/surface_view",
            com.nailify.nail_plugin.render.NailSurfaceViewFactory(binding.binaryMessenger)
        )
        Log.i(TAG, "NailTryOnPlugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopSession()
        activeInstance = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        context = null
        Log.i(TAG, "NailTryOnPlugin detached from engine")
    }

    // Surface binding (gọi từ NailSurfaceViewFactory).
    fun bindSurfaceToActiveSession(holder: android.view.SurfaceHolder) {
        Log.i(TAG, "bindSurfaceToActiveSession: session=${session != null}, holder.isValid=${holder.surface?.isValid}")
        session?.let { sess ->
            // Khởi tạo renderer nếu chưa có.
            sess.attachSurface(holder)
            pendingHolder = null  // Đã bind rồi, xóa pending
        } ?: run {
            // Session chưa có → lưu holder để bind sau khi session được tạo.
            Log.w(TAG, "bindSurfaceToActiveSession: NO ACTIVE SESSION — saving as pending")
            pendingHolder = holder
        }
    }

    fun unbindSurfaceFromActiveSession() {
        Log.i(TAG, "unbindSurfaceFromActiveSession")
        session?.detachSurface()
        pendingHolder = null
    }

    // -------------------------------------------------------------------------
    // ActivityAware
    // -------------------------------------------------------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        // Re-attach session activity nếu session đã tồn tại trước khi activity attach.
        session?.rebindActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        session?.rebindActivity(binding.activity)
    }

    override fun onDetachedFromActivity() {
        activity = null
        session?.rebindActivity(null)
    }

    // -------------------------------------------------------------------------
    // MethodChannel handler
    // -------------------------------------------------------------------------

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(true)

            "startSession" -> {
                val config = call.argument<Map<*, *>>("config")
                val mode   = call.argument<String>("mode") ?: "live"
                val activityRef = activity
                if (activityRef == null) {
                    result.error("NO_ACTIVITY", "Plugin is not attached to an Activity yet.", null)
                    return
                }
                startSession(activityRef, config, mode)
                result.success(null)
            }

            "stopSession" -> {
                stopSession()
                result.success(null)
            }

            "updateManualOffset" -> {
                val dx = (call.argument<Number>("offsetX") ?: 0f).toFloat()
                val dy = (call.argument<Number>("offsetY") ?: 0f).toFloat()
                val scale = (call.argument<Number>("scale") ?: 1f).toFloat()
                val rotation = (call.argument<Number>("rotation") ?: 0f).toFloat()
                session?.updateManualOffset(dx, dy, scale, rotation)
                result.success(null)
            }

            "setDebugFlags" -> {
                val showSkeleton = call.argument<Boolean>("showSkeleton") ?: true
                val showBbox     = call.argument<Boolean>("showBbox") ?: true
                val showFps      = call.argument<Boolean>("showFps") ?: true
                session?.setDebugFlags(showSkeleton, showBbox, showFps)
                result.success(null)
            }

            "captureSnapshot" -> {
                val pending = session?.captureSnapshot()
                if (pending != null) {
                    pending.whenComplete { path, err ->
                        mainHandler.post {
                            if (err != null) {
                                result.error("SNAPSHOT_FAILED", err.message, null)
                            } else {
                                result.success(mapOf("imagePath" to (path ?: "")))
                            }
                        }
                    }
                } else {
                    result.error("NO_SESSION", "No active session.", null)
                }
            }

            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------------------------
    // Session helpers
    // -------------------------------------------------------------------------

    private fun startSession(activity: Activity, config: Map<*, *>?, mode: String) {
        // Lưu pending holder TRƯỚC khi stopSession xóa nó.
        val savedHolder = pendingHolder
        // Nếu session cũ vẫn còn thì giải phóng trước.
        stopSession()
        val lifecycleOwner = activity as? androidx.lifecycle.LifecycleOwner
        if (lifecycleOwner == null) {
            Log.w(TAG, "Activity is not LifecycleOwner; cannot bind CameraX")
            return
        }
        val newSession = NailTryOnSession(
            context = context ?: activity.applicationContext,
            activity = lifecycleOwner,
            mode = mode,
            config = config ?: emptyMap<String, Any?>(),
            eventSink = eventSink,
        )
        session = newSession
        newSession.start()

        // Bind pending holder (nếu surfaceCreated đã chạy trước khi session tạo).
        val holderToBind = savedHolder ?: pendingHolder
        if (holderToBind != null) {
            Log.i(TAG, "startSession: binding pending holder (isValid=${holderToBind.surface?.isValid})")
            newSession.attachSurface(holderToBind)
            pendingHolder = null
        } else {
            Log.w(TAG, "startSession: NO pending holder — surface not ready yet")
        }

        Log.i(TAG, "Session started: mode=$mode")
    }

    private fun stopSession() {
        session?.let {
            it.stop()
            Log.i(TAG, "Session stopped")
        }
        session = null
        // KHÔNG xóa pendingHolder ở đây! startSession cần nó.
    }
}