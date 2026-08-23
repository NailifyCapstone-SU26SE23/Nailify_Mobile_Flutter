/*
 * NailDesignLoader.kt - Load RGBA design PNGs and compute opaque bounds.
 *
 * Port of nail_desktop_app/overlay.py NailOverlayRenderer._load().
 * Returns the bitmap in its original pixel size, plus the tight bounding
 * rectangle of opaque pixels (so transparent padding doesn't shrink the
 * design when we compute the homography).
 *
 * Supports both local assets (relative to `assets/`) and remote URLs
 * (http/https) so the Flutter layer can ship nail designs from the API
 * without bundling them into the APK.
 */
package com.google.mediapipe.examples.handlandmarker.ai

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.RectF
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

data class LoadedDesign(
    /** Full RGBA bitmap decoded from the asset / URL. */
    val bitmap: Bitmap,
    /** Tight bounding box of opaque pixels inside the bitmap, in bitmap coords. */
    val opaqueBounds: RectF,
    /** opaqueBounds.width() / opaqueBounds.height(). */
    val aspectRatio: Float,
) {
    val width: Int get() = bitmap.width
    val height: Int get() = bitmap.height
}

object NailDesignLoader {

    private const val TAG = "NailDesignLoader"

    /**
     * Decode a design from either a local asset path or a remote URL.
     *
     * @param context  Android context (needed for assets access).
     * @param path     Asset path (relative to `assets/`) OR absolute URL
     *                 starting with "http://" or "https://".
     * @param cacheDir Optional cache directory used to avoid re-downloading
     *                 the same URL on every call. May be null.
     * @return LoadedDesign or null if the resource cannot be decoded.
     */
    fun loadDesign(
        context: Context,
        path: String,
        cacheDir: File? = null,
    ): LoadedDesign? {
        if (path.isBlank()) return null
        return when {
            path.startsWith("http://") || path.startsWith("https://") -> {
                loadFromUrl(context, path, cacheDir)
            }
            else -> loadFromAsset(context, path)
        }
    }

    // --------------------------------------------------------------------- assets

    private fun loadFromAsset(context: Context, assetPath: String): LoadedDesign? {
        val bitmap: Bitmap = try {
            context.assets.open(assetPath).use { input ->
                BitmapFactory.decodeStream(input)
            } ?: run {
                Log.w(TAG, "BitmapFactory returned null for $assetPath")
                return null
            }
        } catch (e: IOException) {
            Log.w(TAG, "Failed to open asset $assetPath: ${e.message}")
            return null
        }

        return buildLoadedDesign(bitmap, assetPath)
    }

    // --------------------------------------------------------------------- URL

    private fun loadFromUrl(
        context: Context,
        url: String,
        cacheDir: File?,
    ): LoadedDesign? {
        // 1. Try cache first.
        val cachedFile = cacheDir?.let { urlToCacheFile(it, url) }
        if (cachedFile != null && cachedFile.exists() && cachedFile.length() > 0) {
            val bitmap = BitmapFactory.decodeFile(cachedFile.absolutePath)
            if (bitmap != null) {
                Log.d(TAG, "Loaded design from cache: $url")
                return buildLoadedDesign(bitmap, url)
            }
        }

        // 2. Download fresh.
        val connection: HttpURLConnection
        try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 5000
                readTimeout = 10000
                requestMethod = "GET"
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to open connection to $url: ${e.message}")
            return null
        }

        val bitmap: Bitmap? = try {
            connection.inputStream.use { input ->
                BitmapFactory.decodeStream(input)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to download design from $url: ${e.message}")
            null
        } finally {
            connection.disconnect()
        }

        if (bitmap == null) {
            return null
        }

        // 3. Persist to cache for next time.
        if (cachedFile != null) {
            try {
                cachedFile.parentFile?.mkdirs()
                FileOutputStream(cachedFile).use { out ->
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to cache design from $url: ${e.message}")
            }
        }

        return buildLoadedDesign(bitmap, url)
    }

    /**
     * Map a URL to a deterministic cache path. Uses the URL's hashCode so
     * identical URLs share the same cache file across sessions.
     */
    private fun urlToCacheFile(cacheDir: File, url: String): File {
        val sanitizedName = "url_${url.hashCode().toString().replace('-', 'n')}.png"
        return File(cacheDir, "nail_designs/$sanitizedName")
    }

    // --------------------------------------------------------------------- shared

    private fun buildLoadedDesign(bitmap: Bitmap, sourceLog: String): LoadedDesign? {
        val (ox, oy, ow, oh) = computeOpaqueBounds(bitmap)
        val aspect = if (oh > 0) ow.toFloat() / oh.toFloat() else 1f

        Log.d(
            TAG,
            "Loaded design $sourceLog (${bitmap.width}x${bitmap.height}) " +
                "opaque=$ox,$oy ${ow}x$oh aspect=$aspect"
        )

        return LoadedDesign(
            bitmap = bitmap,
            opaqueBounds = RectF(
                ox.toFloat(),
                oy.toFloat(),
                (ox + ow).toFloat(),
                (oy + oh).toFloat(),
            ),
            aspectRatio = aspect,
        )
    }

    /**
     * Compute the tight bounding box of opaque pixels. Mirrors the logic in
     * NailOverlayRenderer._load(): prefer the alpha channel when it has
     * transparency, otherwise fall back to "not pure white".
     */
    private fun computeOpaqueBounds(bitmap: Bitmap): IntArray {
        val w = bitmap.width
        val h = bitmap.height
        if (w == 0 || h == 0) return intArrayOf(0, 0, w, h)

        val hasAlpha = bitmap.hasAlpha() && bitmap.config?.let {
            it == Bitmap.Config.ARGB_8888 || it == Bitmap.Config.RGBA_F16
        } == true

        val pixels = IntArray(w * h)
        bitmap.getPixels(pixels, 0, w, 0, 0, w, h)

        var minX = w
        var minY = h
        var maxX = -1
        var maxY = -1

        if (hasAlpha) {
            for (y in 0 until h) {
                val rowOffset = y * w
                for (x in 0 until w) {
                    val alpha = Color.alpha(pixels[rowOffset + x])
                    if (alpha > 8) {
                        if (x < minX) minX = x
                        if (y < minY) minY = y
                        if (x > maxX) maxX = x
                        if (y > maxY) maxY = y
                    }
                }
            }
        } else {
            for (y in 0 until h) {
                val rowOffset = y * w
                for (x in 0 until w) {
                    val p = pixels[rowOffset + x]
                    val r = Color.red(p)
                    val g = Color.green(p)
                    val b = Color.blue(p)
                    // Non-white = design content
                    if (r < 250 || g < 250 || b < 250) {
                        if (x < minX) minX = x
                        if (y < minY) minY = y
                        if (x > maxX) maxX = x
                        if (y > maxY) maxY = y
                    }
                }
            }
        }

        if (maxX < minX || maxY < minY) {
            return intArrayOf(0, 0, w, h)
        }
        return intArrayOf(minX, minY, maxX - minX + 1, maxY - minY + 1)
    }
}
