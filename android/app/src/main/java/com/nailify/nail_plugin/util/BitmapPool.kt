/*
 * BitmapPool.kt — Reuse Bitmap objects để giảm GC pressure trong hot loop.
 *
 * Camera preview thường xuyất allocate Bitmap mỗi frame (640x480 ARGB_8888
 * = 1.2 MB). BitmapPool giữ một stack các bitmap đã được recycle, tái sử dụng
 * qua obtain()/recycle().
 */
package com.nailify.nail_plugin.util

import android.graphics.Bitmap

class BitmapPool(private val w: Int, private val h: Int, private val config: Bitmap.Config = Bitmap.Config.ARGB_8888) {
    private val pool = ArrayDeque<Bitmap>()

    @Synchronized
    fun obtain(): Bitmap {
        val cached = pool.removeLastOrNull()
        if (cached != null && !cached.isRecycled) return cached
        return Bitmap.createBitmap(w, h, config)
    }

    /** Recycle bitmap về pool. KHÔNG gọi bitmap.recycle() — để pool quản lý. */
    @Synchronized
    fun recycle(bitmap: Bitmap) {
        if (bitmap.isRecycled) return
        // Tránh pool quá lớn (giữ max 4 bitmap).
        if (pool.size >= 4) bitmap.recycle() else pool.addLast(bitmap)
    }

    @Synchronized
    fun clear() {
        for (b in pool) {
            try { b.recycle() } catch (_: Exception) {}
        }
        pool.clear()
    }
}