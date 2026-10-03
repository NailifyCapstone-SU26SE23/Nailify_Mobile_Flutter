/*
 * NailSurfaceViewFactory.kt — Đăng ký NailSurfaceView với Flutter PlatformView.
 *
 * Flutter dựng widget này qua:
 *   AndroidView(
 *     viewType: 'nail_plugin/surface_view',
 *     creationParams: { 'sessionId': ... },
 *     onPlatformViewCreated: (id) => ...,
 *   )
 *
 * Đăng ký trong MainActivity qua:
 *   flutterEngine.platformViewRegistry.registerViewFactory(
 *       "nail_plugin/surface_view", NailSurfaceViewFactory())
 */
package com.nailify.nail_plugin.render

import android.content.Context
import android.util.Log
import android.view.SurfaceHolder
import com.nailify.nail_plugin.NailTryOnPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec

class NailSurfaceViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    companion object {
        private const val TAG = "NailSurfaceViewFactory"
    }

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        Log.d(TAG, "create(viewId=$viewId, args=$args)")
        val surfaceView = NailSurfaceView(context)

        // QUAN TRỌNG: Lưu holder vào factory trước để nếu surfaceCreated
        // chạy trước khi userCallback được set, ta vẫn có thể bind lại.
        val plugin = NailTryOnPlugin.peekActiveInstance()
        Log.d(TAG, "create: plugin=${plugin != null}")

        surfaceView.userCallback = object : NailSurfaceView.SurfaceCallback {
            override fun onSurfaceCreated(holder: SurfaceHolder) {
                Log.d(TAG, "userCallback.onSurfaceCalled → bindSurfaceToActiveSession")
                plugin?.bindSurfaceToActiveSession(holder)
            }
            override fun onSurfaceDestroyed(holder: SurfaceHolder) {
                Log.d(TAG, "userCallback.onSurfaceDestroyed → unbindSurfaceFromActiveSession")
                plugin?.unbindSurfaceFromActiveSession()
            }
        }

        // Sau khi userCallback đã được set, nếu surface đã valid (surfaceCreated
        // đã chạy trước đó), thử bind ngay để chắc chắn.
        if (plugin != null && surfaceView.holder.surface?.isValid == true) {
            Log.d(TAG, "create: surface already valid, binding immediately")
            plugin.bindSurfaceToActiveSession(surfaceView.holder)
        } else if (plugin != null) {
            Log.d(TAG, "create: surface not valid yet (will bind on surfaceCreated)")
        } else {
            Log.w(TAG, "create: no plugin active — surface will NOT be bound!")
        }

        return NailSurfaceViewWrapper(surfaceView)
    }

    private class NailSurfaceViewWrapper(private val view: NailSurfaceView) : PlatformView {
        override fun getView(): android.view.View = view
        override fun dispose() { /* SurfaceView lifecycle do Flutter quản lý */ }
    }
}