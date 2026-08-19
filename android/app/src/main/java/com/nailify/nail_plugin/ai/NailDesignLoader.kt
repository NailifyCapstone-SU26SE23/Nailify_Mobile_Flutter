/*
 * NailDesignLoader.kt — Load PNG design từ assets/ (cached).
 */
package com.nailify.nail_plugin.ai

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Rect
import android.util.Log
import java.io.File
import java.net.URL

data class LoadedDesign(
    val bitmap: Bitmap,
    val opaqueBounds: Rect,
    val aspectRatio: Float,
)

object NailDesignLoader {

    private const val TAG = "NailDesignLoader"

    fun loadDesign(
        context: Context,
        assetPath: String,
        cacheDir: File,
    ): LoadedDesign? {
        return try {
            val bitmap = if (assetPath.startsWith("http")) {
                downloadBitmap(assetPath, cacheDir)
            } else {
                context.assets.open(assetPath).use { BitmapFactory.decodeStream(it) }
            } ?: run {
                Log.w(TAG, "Failed to decode $assetPath")
                return null
            }
            analyzeOpaqueBounds(bitmap)
        } catch (e: Exception) {
            Log.w(TAG, "loadDesign($assetPath) failed: ${e.message}", e)
            null
        }
    }

    private fun downloadBitmap(url: String, cacheDir: File): Bitmap? {
        return try {
            val name = "design_${url.hashCode()}.png"
            val file = File(cacheDir, name)
            if (!file.exists()) {
                URL(url).openStream().use { input ->
                    file.outputStream().use { input.copyTo(it) }
                }
            }
            BitmapFactory.decodeFile(file.absolutePath)
        } catch (e: Exception) {
            Log.w(TAG, "downloadBitmap($url) failed: ${e.message}", e)
            null
        }
    }

    private fun analyzeOpaqueBounds(bitmap: Bitmap): LoadedDesign {
        val w = bitmap.width
        val h = bitmap.height
        var minX = w
        var maxX = -1
        var minY = h
        var maxY = -1
        for (y in 0 until h step 2) {
            for (x in 0 until w step 2) {
                if (Color.alpha(bitmap.getPixel(x, y)) > 16) {
                    if (x < minX) minX = x
                    if (x > maxX) maxX = x
                    if (y < minY) minY = y
                    if (y > maxY) maxY = y
                }
            }
        }
        val bounds = if (maxX < 0) Rect(0, 0, w - 1, h - 1) else Rect(minX, minY, maxX, maxY)
        val widthF = (bounds.right - bounds.left).coerceAtLeast(1).toFloat()
        val heightF = (bounds.bottom - bounds.top).coerceAtLeast(1).toFloat()
        return LoadedDesign(
            bitmap = bitmap,
            opaqueBounds = bounds,
            aspectRatio = widthF / heightF,
        )
    }
}