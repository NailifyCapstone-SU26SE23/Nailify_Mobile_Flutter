/*
 * CameraController.kt — Wraps CameraX ImageAnalysis để xuất bitmap.
 *
 * Luồng:
 *   CameraX -> ImageProxy (RGBA_8888) -> ImageProxy.toBitmap() ->
 *   rotate bitmap (theo rotationDegrees) -> flip ngang nếu front camera ->
 *   callback onFrame(bitmap, rotation, isFront)
 *
 * Quan trọng:
 *   - Một executor duy nhất cho ImageAnalysis.setAnalyzer (cùng thread với
 *     pipeline AI để tránh race trên OrtSession).
 *   - STRATEGY_KEEP_ONLY_LATEST: bỏ frame cũ nếu pipeline bận.
 *   - KHÔNG bind Preview use case: ta dùng SurfaceView riêng (NailSurfaceView)
 *     để render, không cần PreviewView. Bind Preview mà không có consumer
 *     dẫn đến CameraX "Connection timed out" sau vài giây.
 */
package com.nailify.nail_plugin.camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Log
import android.util.Size
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.common.util.concurrent.ListenableFuture
import java.util.concurrent.Executor
import java.util.concurrent.TimeUnit

class CameraController(
    private val context: Context,
    private val activity: LifecycleOwner,
) {
    companion object {
        private const val TAG = "CameraController"
    }

    var onFrame: ((Bitmap, Int, Boolean) -> Unit)? = null
    var onError: ((String) -> Unit)? = null

    private var cameraProvider: ProcessCameraProvider? = null
    private var imageAnalyzer: ImageAnalysis? = null

    private var analyzerExecutor: Executor? = null

    fun setAnalyzerExecutor(executor: Executor) {
        analyzerExecutor = executor
    }

    fun start() {
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            try {
                cameraProvider = future.get()
                bindUseCases()
            } catch (e: Exception) {
                Log.e(TAG, "Camera provider init failed", e)
                onError?.invoke("Camera provider init failed: ${e.message}")
            }
        }, ContextCompat.getMainExecutor(context))
    }

    fun stop() {
        try {
            cameraProvider?.unbindAll()
        } catch (e: Exception) {
            Log.w(TAG, "unbindAll failed", e)
        }
        cameraProvider = null
        imageAnalyzer = null
    }

    // ---------------------------------------------------------------- private

    private fun bindUseCases() {
        val provider = cameraProvider ?: return
        val selector = CameraSelector.Builder()
            .requireLensFacing(CameraSelector.LENS_FACING_BACK)
            .build()
        val resolutionSelector = ResolutionSelector.Builder()
            .setResolutionStrategy(
                ResolutionStrategy(
                    Size(640, 480),
                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                ),
            )
            .setAspectRatioStrategy(AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY)
            .build()

        imageAnalyzer = ImageAnalysis.Builder()
            .setResolutionSelector(resolutionSelector)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build()
            .also {
                val exec = analyzerExecutor
                if (exec != null) {
                    it.setAnalyzer(exec) { image -> analyzeFrame(image) }
                } else {
                    Log.w(TAG, "No analyzer executor set; analyzer not bound.")
                }
            }

        try {
            provider.unbindAll()
            // CHỈ bind ImageAnalysis — không cần Preview vì ta render ra SurfaceView riêng.
            provider.bindToLifecycle(activity, selector, imageAnalyzer!!)
            Log.i(TAG, "Camera bound to lifecycle (ImageAnalysis 640x480 only)")
        } catch (e: Exception) {
            Log.e(TAG, "bindToLifecycle failed", e)
            onError?.invoke("bindToLifecycle failed: ${e.message}")
        }
    }

    private fun analyzeFrame(imageProxy: ImageProxy) {
        try {
            val buffer = imageProxy.planes[0].buffer
            val expectedSize = imageProxy.width * imageProxy.height * 4
            if (buffer.remaining() < expectedSize) {
                Log.w(TAG, "skip frame: remaining=${buffer.remaining()} expected=$expectedSize")
                return
            }
            val rawBitmap = Bitmap.createBitmap(
                imageProxy.width,
                imageProxy.height,
                Bitmap.Config.ARGB_8888,
            )
            rawBitmap.copyPixelsFromBuffer(buffer)

            val rotation = imageProxy.imageInfo.rotationDegrees
            val isFront = false // TODO: cho phép switch camera khi cần
            val finalBitmap = rotateAndFlip(rawBitmap, rotation, isFront)
            if (finalBitmap !== rawBitmap) rawBitmap.recycle()
            onFrame?.invoke(finalBitmap, rotation, isFront)
        } catch (e: Exception) {
            Log.w(TAG, "analyzeFrame failed: ${e.message}", e)
        } finally {
            imageProxy.close()
        }
    }

    private fun rotateAndFlip(bitmap: Bitmap, rotation: Int, isFront: Boolean): Bitmap {
        if (rotation == 0 && !isFront) return bitmap
        val matrix = Matrix().apply {
            postRotate(rotation.toFloat())
            if (isFront) postScale(-1f, 1f, bitmap.width.toFloat(), bitmap.height.toFloat())
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }
}

/**
 * Marker type alias để giữ tên cũ ở call sites; ContextCompat.getMainExecutor
 * đã được import trực tiếp trong file này.
 */
@Suppress("unused")
private typealias ContextCompat_MainExecutor = androidx.core.content.ContextCompat