/*
 * NailSurfaceView.kt — Native SurfaceView host cho NailSurfaceRenderer.
 *
 * Flutter dựng view này qua AndroidView(viewType: "nail_plugin/surface_view").
 * Khi surface sẵn sàng, holder được truyền cho renderer qua NailTryOnSession.
 *
 * QUAN TRỌNG: SurfaceHolder.Callback phải được đăng ký TRƯỚC khi view được
 * attach vào window. Trước đây factory set `surfaceView.callback` SAU khi
 * `init {}` chạy addCallback() — dẫn đến surfaceCreated bị miss.
 *
 * Cách fix: implement SurfaceHolder.Callback TRỰC TIẾP trên class, gọi
 * userCallback.onSurfaceCreated chỉ khi != null.
 */
package com.nailify.nail_plugin.render

import android.content.Context
import android.util.AttributeSet
import android.util.Log
import android.view.SurfaceHolder
import android.view.SurfaceView

class NailSurfaceView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : SurfaceView(context, attrs, defStyleAttr), SurfaceHolder.Callback {

    companion object {
        private const val TAG = "NailSurfaceView"
    }

    interface SurfaceCallback {
        fun onSurfaceCreated(holder: SurfaceHolder)
        fun onSurfaceDestroyed(holder: SurfaceHolder)
    }

    /** Được set từ NailSurfaceViewFactory SAU khi view được tạo. */
    var userCallback: SurfaceCallback? = null

    init {
        // Đăng ký callback ngay để không miss surfaceCreated khi userCallback
        // được set trễ (Flutter factory set callback sau init{}).
        holder.addCallback(this)
        Log.d(TAG, "init: callback registered, isValid=${holder.surface?.isValid}")
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        Log.d(TAG, "surfaceCreated: surface.isValid=${holder.surface?.isValid}, userCallback=${userCallback != null}")
        userCallback?.onSurfaceCreated(holder)
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        // Surface size thay đổi; renderer tự handle khi lockCanvas.
        Log.d(TAG, "surfaceChanged: ${width}x${height}")
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        Log.d(TAG, "surfaceDestroyed")
        userCallback?.onSurfaceDestroyed(holder)
    }
}