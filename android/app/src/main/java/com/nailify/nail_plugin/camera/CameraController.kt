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
import android.graphics.Canvas
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
import com.nailify.nail_plugin.util.BitmapPool
import java.util.concurrent.Executor
import java.util.concurrent.TimeUnit

class CameraController(
    private val context: Context,
    private val activity: LifecycleOwner,
) {
    companion object {
        private const val TAG = "CameraController"
    }

    var onFrame: ((Bitmap, Int, Boolean, BitmapPool?) -> Unit)? = null
    var onError: ((String) -> Unit)? = null

    private var cameraProvider: ProcessCameraProvider? = null
    private var imageAnalyzer: ImageAnalysis? = null

    private var analyzerExecutor: Executor? = null
    
    private var rawBitmapPool: BitmapPool? = null
    private var rotatedBitmapPool: BitmapPool? = null
    private val rotateMatrix = Matrix()

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
        rawBitmapPool?.clear()
        rawBitmapPool = null
        rotatedBitmapPool?.clear()
        rotatedBitmapPool = null
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

        // Dummy Preview: Ép camera hardware bật màn trập bằng cách tạo một Preview ảo.
        val preview = androidx.camera.core.Preview.Builder()
            .setResolutionSelector(resolutionSelector)
            .build()
        preview.setSurfaceProvider { request ->
            val surfaceTexture = android.graphics.SurfaceTexture(0)
            surfaceTexture.setDefaultBufferSize(request.resolution.width, request.resolution.height)
            val surface = android.view.Surface(surfaceTexture)
            request.provideSurface(surface, ContextCompat.getMainExecutor(context)) {
                surface.release()
                surfaceTexture.release()
            }
        }

        try {
            provider.unbindAll()
            // Bind CẢ Preview ảo VÀ ImageAnalysis.
            provider.bindToLifecycle(activity, selector, preview, imageAnalyzer!!)
            Log.i(TAG, "Camera bound to lifecycle (ImageAnalysis + Dummy Preview)")
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
            
            // 1. Allocate / Reuse Raw Bitmap
            var rawPool = rawBitmapPool
            if (rawPool == null) {
                rawPool = BitmapPool(imageProxy.width, imageProxy.height)
                rawBitmapPool = rawPool
            }
            val rawBitmap = rawPool.obtain()
            buffer.rewind()
            rawBitmap.copyPixelsFromBuffer(buffer)

            val rotation = imageProxy.imageInfo.rotationDegrees
            val isFront = false
            
            Log.d(TAG, "analyzeFrame: proxy=${imageProxy.width}x${imageProxy.height} rot=$rotation rawBmp=${rawBitmap.width}x${rawBitmap.height}")
            
            if (rotation == 0 && !isFront) {
                // Không cần xoay
                onFrame?.invoke(rawBitmap, 0, isFront, rawPool)
                return
            }

            // 2. Allocate / Reuse Rotated Bitmap
            val isRotated = (rotation == 90 || rotation == 270)
            val rotW = if (isRotated) imageProxy.height else imageProxy.width
            val rotH = if (isRotated) imageProxy.width else imageProxy.height
            
            var rotPool = rotatedBitmapPool
            if (rotPool == null) {
                rotPool = BitmapPool(rotW, rotH)
                rotatedBitmapPool = rotPool
            }
            val rotatedBitmap = rotPool.obtain()
            
            // 3. Zero-Allocation Canvas Rotation
            val canvas = Canvas(rotatedBitmap)
            rotateMatrix.reset()
            rotateMatrix.postRotate(rotation.toFloat())
            if (rotation == 90) {
                rotateMatrix.postTranslate(rotW.toFloat(), 0f)
            } else if (rotation == 180) {
                rotateMatrix.postTranslate(rotW.toFloat(), rotH.toFloat())
            } else if (rotation == 270) {
                rotateMatrix.postTranslate(0f, rotH.toFloat())
            }
            
            if (isFront) {
                rotateMatrix.postScale(-1f, 1f, rotW / 2f, rotH / 2f)
            }
            
            canvas.drawBitmap(rawBitmap, rotateMatrix, null)
            
            Log.d(TAG, "analyzeFrame: rotated=${rotatedBitmap.width}x${rotatedBitmap.height} from ${rawBitmap.width}x${rawBitmap.height} rot=$rotation")
            
            // Xong với rawBitmap, trả về pool ngay lập tức
            rawPool.recycle(rawBitmap)
            
            // 4. Gửi rotatedBitmap cho pipeline, Pipeline sẽ chịu trách nhiệm recycle rotatedBitmap
            onFrame?.invoke(rotatedBitmap, 0, isFront, rotPool)
        } catch (e: Exception) {
            Log.w(TAG, "analyzeFrame failed: ${e.message}", e)
        } finally {
            imageProxy.close()
        }
    }}
