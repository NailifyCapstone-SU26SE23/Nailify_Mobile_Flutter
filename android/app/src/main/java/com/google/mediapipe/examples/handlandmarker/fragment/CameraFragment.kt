package com.google.mediapipe.examples.handlandmarker.fragment

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import java.util.concurrent.ExecutionException
import androidx.camera.core.Preview
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Camera
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import androidx.navigation.Navigation
import android.util.Size
import com.google.mediapipe.examples.handlandmarker.HandLandmarkerHelper
import com.google.mediapipe.examples.handlandmarker.MainViewModel
import com.google.mediapipe.examples.handlandmarker.R
import com.google.mediapipe.examples.handlandmarker.databinding.FragmentCameraBinding
import com.google.mediapipe.tasks.vision.core.RunningMode
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import kotlin.math.atan2
import kotlin.math.hypot
import kotlinx.coroutines.launch

class CameraFragment : Fragment(), HandLandmarkerHelper.LandmarkerListener {

    companion object {
        private const val TAG = "NailifyCamera"

        /** Log verbose khi debug pipeline. Đặt = false trong release. */
        private const val DEBUG_LOG = true

        /** Key để Flutter nhận biết đây là yêu cầu Snapshot mode */
        const val EXTRA_MODE = "camera_mode"
        const val MODE_SNAPSHOT = "snapshot"
        const val MODE_LIVE = "live"

        /** Keys cho Intent kết quả trả về Flutter */
        const val RESULT_IMAGE_PATH = "snapshot_image_path"
        const val RESULT_LANDMARKS_JSON = "snapshot_landmarks_json"
    }

    private var _fragmentCameraBinding: FragmentCameraBinding? = null
    private val fragmentCameraBinding get() = _fragmentCameraBinding!!

    private lateinit var handLandmarkerHelper: HandLandmarkerHelper
    private val viewModel: MainViewModel by activityViewModels()
    private var preview: Preview? = null
    private var imageAnalyzer: ImageAnalysis? = null
    private var imageCapture: ImageCapture? = null
    private var camera: Camera? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var cameraFacing = CameraSelector.LENS_FACING_BACK

    /** true khi Activity được mở ở chế độ Snapshot (không có Live Overlay) */
    private var isSnapshotMode = false

    private lateinit var backgroundExecutor: ExecutorService

    override fun onResume() {
        super.onResume()
        if (!PermissionsFragment.hasPermissions(requireContext())) {
            Navigation.findNavController(
                requireActivity(), R.id.fragment_container
            ).navigate(R.id.action_camera_to_permissions)
        }
        backgroundExecutor.execute {
            if (handLandmarkerHelper.isClose()) {
                handLandmarkerHelper.setupHandLandmarker()
            }
        }
    }

    override fun onPause() {
        super.onPause()
        if (this::handLandmarkerHelper.isInitialized) {
            viewModel.setMaxHands(handLandmarkerHelper.maxNumHands)
            viewModel.setMinHandDetectionConfidence(handLandmarkerHelper.minHandDetectionConfidence)
            viewModel.setMinHandTrackingConfidence(handLandmarkerHelper.minHandTrackingConfidence)
            viewModel.setMinHandPresenceConfidence(handLandmarkerHelper.minHandPresenceConfidence)
            viewModel.setDelegate(handLandmarkerHelper.currentDelegate)
            backgroundExecutor.execute { handLandmarkerHelper.clearHandLandmarker() }
        }
    }

    override fun onDestroyView() {
        _fragmentCameraBinding = null
        super.onDestroyView()
        backgroundExecutor.shutdown()
        if (!backgroundExecutor.awaitTermination(1000, TimeUnit.MILLISECONDS)) {
            backgroundExecutor.shutdownNow()
        }
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _fragmentCameraBinding = FragmentCameraBinding.inflate(inflater, container, false)
        return fragmentCameraBinding.root
    }

    @SuppressLint("MissingPermission")
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Xác định mode từ Intent của Activity
        isSnapshotMode = requireActivity().intent.getStringExtra(EXTRA_MODE) == MODE_SNAPSHOT

        backgroundExecutor = Executors.newSingleThreadExecutor()

        fragmentCameraBinding.viewFinder.implementationMode =
            androidx.camera.view.PreviewView.ImplementationMode.COMPATIBLE

        // Cấu hình UI theo mode
        applyModeUi()

        fragmentCameraBinding.viewFinder.post { setUpCamera() }

        // HandLandmarkerHelper cho Live mode (LIVE_STREAM)
        backgroundExecutor.execute {
            handLandmarkerHelper = HandLandmarkerHelper(
                context = requireContext(),
                runningMode = RunningMode.LIVE_STREAM,
                minHandDetectionConfidence = viewModel.currentMinHandDetectionConfidence,
                minHandTrackingConfidence = viewModel.currentMinHandTrackingConfidence,
                minHandPresenceConfidence = viewModel.currentMinHandPresenceConfidence,
                maxNumHands = viewModel.currentMaxHands,
                currentDelegate = viewModel.currentDelegate,
                handLandmarkerHelperListener = this
            )
        }

        // Observe manual offsets (chỉ áp dụng cho Live mode)
        if (!isSnapshotMode) {
            viewLifecycleOwner.lifecycleScope.launch {
                viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                    viewModel.manualOffset.collect { offset ->
                        fragmentCameraBinding.overlay.updateManualOffsets(
                            offsetX  = offset.offsetX,
                            offsetY  = offset.offsetY,
                            scale    = offset.scale,
                            rotation = offset.rotation
                        )
                    }
                }
            }
        }

        // ----- Listeners -----

        fragmentCameraBinding.btnBack.setOnClickListener {
            requireActivity().setResult(Activity.RESULT_CANCELED)
            requireActivity().finish()
        }

        fragmentCameraBinding.btnZoomIn.setOnClickListener {
            camera?.let {
                val zoomState = it.cameraInfo.zoomState.value ?: return@let
                val newRatio = (zoomState.zoomRatio + 0.5f).coerceAtMost(zoomState.maxZoomRatio)
                it.cameraControl.setZoomRatio(newRatio)
            }
        }

        fragmentCameraBinding.btnZoomOut.setOnClickListener {
            camera?.let {
                val zoomState = it.cameraInfo.zoomState.value ?: return@let
                val newRatio = (zoomState.zoomRatio - 0.5f).coerceAtLeast(zoomState.minZoomRatio)
                it.cameraControl.setZoomRatio(newRatio)
            }
        }

        // Nút chụp Live (lưu thư viện)
        fragmentCameraBinding.btnCapture.setOnClickListener {
            captureAndSaveToGallery()
        }

        // Nút chụp Snapshot (phân tích AI rồi trả về Flutter)
        fragmentCameraBinding.btnTakePhoto.setOnClickListener {
            takeSnapshotAndAnalyze()
        }
    }

    // -------------------------------------------------------------------------
    // UI helpers
    // -------------------------------------------------------------------------

    private fun applyModeUi() {
        if (isSnapshotMode) {
            // Snapshot mode: ẩn live overlay & nút live, hiện nút snapshot + hand guide
            fragmentCameraBinding.overlay.visibility = View.INVISIBLE
            fragmentCameraBinding.cardCapture.visibility = View.GONE
            fragmentCameraBinding.imgHandGuide.visibility = View.VISIBLE
            fragmentCameraBinding.cardTakePhoto.visibility = View.VISIBLE
        } else {
            // Live mode: hiện live overlay & nút live, ẩn snapshot elements
            fragmentCameraBinding.overlay.visibility = View.VISIBLE
            fragmentCameraBinding.cardCapture.visibility = View.VISIBLE
            fragmentCameraBinding.imgHandGuide.visibility = View.GONE
            fragmentCameraBinding.cardTakePhoto.visibility = View.GONE
        }
    }

    // -------------------------------------------------------------------------
    // SNAPSHOT MODE: Chụp ảnh → MediaPipe IMAGE → trả JSON về Flutter
    // -------------------------------------------------------------------------

    private fun takeSnapshotAndAnalyze() {
        if (DEBUG_LOG) Log.d(TAG, "takeSnapshotAndAnalyze: START — btnTakePhoto pressed")

        // ── BƯỚC 0: Kiểm tra ImageCapture sẵn sàng ─────────────────────────────
        val capture = imageCapture
        if (capture == null) {
            Toast.makeText(requireContext(), "Camera chưa sẵn sàng", Toast.LENGTH_SHORT).show()
            if (DEBUG_LOG) Log.e(TAG, "takeSnapshotAndAnalyze: imageCapture is NULL")
            return
        }

        // Phản hồi trực quan ngay lập tức — người dùng thấy nút disable + flash
        fragmentCameraBinding.btnTakePhoto.isEnabled = false
        fragmentCameraBinding.viewShutterFlash.apply {
            visibility = android.view.View.VISIBLE
            alpha = 1f
            animate()
                .alpha(0f)
                .setDuration(150)
                .withEndAction { visibility = android.view.View.GONE }
                .start()
        }

        // Chụp qua ImageCapture — KHÔNG dùng viewFinder.bitmap
        // viewFinder.bitmap gọi SurfaceTexture.detachFromGLContext() → camera đóng lại
        capture.takePicture(
            ContextCompat.getMainExecutor(requireContext()),
            object : ImageCapture.OnImageCapturedCallback() {
                @SuppressLint("UnsafeOptInUsageError")
                override fun onCaptureSuccess(imageProxy: ImageProxy) {
                    if (DEBUG_LOG) Log.v(TAG, "takeSnapshotAndAnalyze: ImageProxy received ${imageProxy.width}x${imageProxy.height}")

                    backgroundExecutor.execute {
                        try {
                            val bitmap = imageProxyToBitmap(imageProxy)
                            imageProxy.close()

                            if (bitmap == null) {
                                if (DEBUG_LOG) Log.e(TAG, "takeSnapshotAndAnalyze: ImageProxy→Bitmap failed")
                                activity?.runOnUiThread {
                                    Toast.makeText(requireContext(), "Lỗi chụp ảnh", Toast.LENGTH_SHORT).show()
                                    fragmentCameraBinding.btnTakePhoto.isEnabled = true
                                }
                                return@execute
                            }

                            if (DEBUG_LOG) Log.v(TAG, "takeSnapshotAndAnalyze: bitmap=${bitmap.width}x${bitmap.height}")

                            // Chuẩn bị bitmap mutable ARGB_8888 để vẽ lên
                            val mutableBitmap = if (bitmap.config == Bitmap.Config.ARGB_8888 && bitmap.isMutable) {
                                bitmap
                            } else {
                                bitmap.copy(Bitmap.Config.ARGB_8888, true).also { bitmap.recycle() }
                            }

                            // Hiện freeze frame đè lên camera preview
                            activity?.runOnUiThread {
                                fragmentCameraBinding.imgFreezeFrame.apply {
                                    setImageBitmap(mutableBitmap)
                                    visibility = android.view.View.VISIBLE
                                }
                            }

                            // Bước 1: Chạy MediaPipe ở background thread
                            if (DEBUG_LOG) Log.d(TAG, "Snapshot pipeline: [1/5] MediaPipe IMAGE mode starting...")

                            try {
                                val imageHelper = HandLandmarkerHelper(
                                    context = requireContext(),
                                    runningMode = RunningMode.IMAGE,
                                    minHandDetectionConfidence = 0.15f,
                                    minHandTrackingConfidence  = 0.15f,
                                    minHandPresenceConfidence  = 0.15f,
                                    maxNumHands = 2,
                                    currentDelegate = HandLandmarkerHelper.DELEGATE_CPU
                                )

                                if (DEBUG_LOG) Log.v(TAG, "Snapshot pipeline: HandLandmarkerHelper created (IMAGE mode, CPU)")

                                // ── MULTI-ATTEMPT DETECTION ────────────────────────────────
                                data class Attempt(val contrastScale: Float, val brightAdd: Float)
                                val attempts = listOf(
                                    Attempt(1.0f,  0f),
                                    Attempt(1.35f, 25f),
                                    Attempt(1.7f,  50f),
                                    Attempt(2.0f,  70f),
                                )

                                var resultBundle: HandLandmarkerHelper.ResultBundle? = null
                                var usedAttempt: Attempt? = null

                                for (attempt in attempts) {
                                    if (DEBUG_LOG) Log.v(TAG, "Snapshot pipeline: trying detection contrast=${attempt.contrastScale} bright=${attempt.brightAdd}")
                                    val candidate = enhanceBitmapWithParams(mutableBitmap, attempt.contrastScale, attempt.brightAdd)
                                    val bundle = imageHelper.detectImage(candidate)
                                    val found = bundle != null && bundle.results.isNotEmpty() && bundle.results.first().landmarks().isNotEmpty()
                                    if (found) {
                                        resultBundle = bundle
                                        usedAttempt = attempt
                                        if (DEBUG_LOG) Log.i(TAG, "Snapshot pipeline: Hand DETECTED with contrast=${attempt.contrastScale} bright=${attempt.brightAdd}")
                                        break
                                    }
                                }

                                imageHelper.clearHandLandmarker()

                                val hasHand = resultBundle != null
                                if (DEBUG_LOG) Log.v(TAG, "Snapshot pipeline: [1/5] MediaPipe done: hasHand=$hasHand")

                                // Bước 2: Preload bitmaps trên background thread
                                if (hasHand) {
                                    if (DEBUG_LOG) Log.d(TAG, "Snapshot pipeline: [2/5] Preloading bitmaps for config...")
                                    fragmentCameraBinding.overlay.preloadAllBitmapsForSnapshot(viewModel.nailSetConfig.value)
                                    if (DEBUG_LOG) Log.v(TAG, "Snapshot pipeline: [2/5] Bitmaps preloaded")
                                } else {
                                    if (DEBUG_LOG) Log.w(TAG, "Snapshot pipeline: [2/5] SKIPPED — no hand detected, no bitmap needed")
                                }

                                // Bước 3: Render AR lên bitmap trên main thread
                                activity?.runOnUiThread {
                                    try {
                                        if (hasHand) {
                                            if (DEBUG_LOG) Log.d(TAG, "Snapshot pipeline: [3/5] Rendering nails on bitmap...")

                                            fragmentCameraBinding.overlay.setFullDesign(viewModel.nailSetConfig.value)
                                            fragmentCameraBinding.overlay.renderOnBitmap(
                                                targetBitmap = mutableBitmap,
                                                result  = resultBundle!!.results.first(),
                                                imgW    = mutableBitmap.width,
                                                imgH    = mutableBitmap.height
                                            )

                                            if (DEBUG_LOG) Log.i(TAG, "Snapshot pipeline: [3/5] Nail rendering done")
                                        } else {
                                            if (DEBUG_LOG) Log.w(TAG, "Snapshot pipeline: [3/5] SKIPPED — no hand, bitmap unchanged")
                                        }

                                        // Bước 4: Lưu ảnh vào cache
                                        if (DEBUG_LOG) Log.d(TAG, "Snapshot pipeline: [4/5] Saving bitmap to cache...")
                                        val cacheDir = requireContext().cacheDir
                                        cacheDir.listFiles { _, name -> name.startsWith("hand_snapshot_") }
                                            ?.forEach { it.delete() }

                                        val cacheFile = File(cacheDir, "hand_snapshot_${System.currentTimeMillis()}.jpg")
                                        FileOutputStream(cacheFile).use { out ->
                                            mutableBitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
                                        }

                                        // Bước 5: Trả kết quả về Flutter
                                        val landmarksJson = if (hasHand) "[{\"finger\":\"detected\"}]" else "[]"
                                        if (DEBUG_LOG) Log.i(TAG, "Snapshot pipeline: [5/5] Returning to Flutter — imagePath=$cacheFile")

                                        val resultIntent = Intent().apply {
                                            putExtra(RESULT_IMAGE_PATH, cacheFile.absolutePath)
                                            putExtra(RESULT_LANDMARKS_JSON, landmarksJson)
                                        }
                                        requireActivity().setResult(Activity.RESULT_OK, resultIntent)
                                        requireActivity().finish()

                                    } catch (e: Exception) {
                                        Log.e(TAG, "Render snapshot failed", e)
                                        hideFreezeFrame()
                                        fragmentCameraBinding.btnTakePhoto.isEnabled = true
                                        Toast.makeText(requireContext(), "Lỗi vẽ móng: ${e.message}", Toast.LENGTH_SHORT).show()
                                    }
                                }

                            } catch (e: Exception) {
                                Log.e(TAG, "MediaPipe snapshot failed", e)
                                activity?.runOnUiThread {
                                    hideFreezeFrame()
                                    fragmentCameraBinding.btnTakePhoto.isEnabled = true
                                    Toast.makeText(requireContext(), "Lỗi phân tích bàn tay: ${e.message}", Toast.LENGTH_SHORT).show()
                                }
                            }

                        } catch (e: Exception) {
                            Log.e(TAG, "takeSnapshotAndAnalyze: processing failed", e)
                            activity?.runOnUiThread {
                                hideFreezeFrame()
                                fragmentCameraBinding.btnTakePhoto.isEnabled = true
                                Toast.makeText(requireContext(), "Lỗi xử lý ảnh: ${e.message}", Toast.LENGTH_SHORT).show()
                            }
                        }
                    }
                }

                override fun onError(exception: ImageCaptureException) {
                    Log.e(TAG, "takeSnapshotAndAnalyze: ImageCapture failed", exception)
                    activity?.runOnUiThread {
                        hideFreezeFrame()
                        fragmentCameraBinding.btnTakePhoto.isEnabled = true
                        Toast.makeText(requireContext(), "Lỗi chụp ảnh: ${exception.message}", Toast.LENGTH_SHORT).show()
                    }
                }
            }
        )
    }

    /** Ẩn freeze frame và trả lại camera preview cho người dùng. */
    private fun hideFreezeFrame() {
        fragmentCameraBinding.imgFreezeFrame.apply {
            visibility = android.view.View.GONE
            setImageBitmap(null)
        }
    }

    /**
     * Tăng cường ảnh với các tham số tuỳ chỉnh (dùng cho multi-attempt detection).
     *
     * @param src            Bitmap gốc (không bị sửa)
     * @param contrastScale  Hệ số contrast (1.0 = giữ nguyên, 1.5 = tăng 50%)
     * @param brightAdd      Cộng sáng (0–255 scale, 0 = giữ nguyên, 30 = tăng nhẹ)
     */
    private fun enhanceBitmapWithParams(src: Bitmap, contrastScale: Float, brightAdd: Float): Bitmap {
        if (contrastScale == 1.0f && brightAdd == 0f) return src  // Không cần xử lý, trả luôn
        val enhanced = src.copy(Bitmap.Config.ARGB_8888, true)
        val canvas   = android.graphics.Canvas(enhanced)
        val paint    = android.graphics.Paint()
        val translate = (-(contrastScale - 1) * 128 + brightAdd)
        val cm = android.graphics.ColorMatrix(floatArrayOf(
            contrastScale, 0f,            0f,            0f, translate,
            0f,            contrastScale, 0f,            0f, translate,
            0f,            0f,            contrastScale, 0f, translate,
            0f,            0f,            0f,            1f, 0f
        ))
        paint.colorFilter = android.graphics.ColorMatrixColorFilter(cm)
        canvas.drawBitmap(src, 0f, 0f, paint)
        return enhanced
    }

    /**
     * Xoay bitmap theo số độ (0, 90, 180, 270).
     * Trả bitmap gốc nếu rotDeg == 0.
     *
     * LưU Ý: không dùng hàm này trong Snapshot detection — xoay sẽ làm lệch
     * toạ độ landmark của MediaPipe so với ảnh gốc.
     */
    @Suppress("unused")
    private fun rotateBitmap(src: Bitmap, rotDeg: Int): Bitmap {
        if (rotDeg == 0) return src
        val matrix = android.graphics.Matrix().apply { postRotate(rotDeg.toFloat()) }
        return Bitmap.createBitmap(src, 0, 0, src.width, src.height, matrix, true)
    }


    /**
     * Chuyển đổi ResultBundle từ MediaPipe IMAGE mode thành chuỗi JSON.
     *
     * Với mỗi ngón tay (thumb=4, index=8, middle=12, ring=16, pinky=20):
     *   - tip  = landmark đầu ngón (tipIndex)
     *   - joint = landmark đốt ngay dưới tip (tipIndex - 1)
     *   - baseX/baseY = tọa độ pixel trên ảnh (chưa scale, để Flutter tự scale)
     *   - baseRotation (rad) = atan2(tip - joint) = hướng ngón tay
     *   - baseScale = khoảng cách tip↔joint (đơn vị pixel), dùng để size móng
     *
     * Flutter sẽ dùng các giá trị này làm "base" và cộng manualOffset lên.
     */
    private fun buildLandmarksJson(
        bundle: HandLandmarkerHelper.ResultBundle?,
        imageWidth: Int,
        imageHeight: Int
    ): String {
        val fingerNames = listOf("thumb", "index", "middle", "ring", "pinky")
        val tipIndices  = listOf(4, 8, 12, 16, 20)
        val arr = JSONArray()

        val landmarks = bundle?.results?.firstOrNull()?.landmarks()?.firstOrNull()
        if (landmarks != null) {
            for ((i, tipIndex) in tipIndices.withIndex()) {
                val tip   = landmarks[tipIndex]
                val joint = landmarks[tipIndex - 1]

                val tipX   = tip.x()   * imageWidth
                val tipY   = tip.y()   * imageHeight
                val jointX = joint.x() * imageWidth
                val jointY = joint.y() * imageHeight

                // Góc ngón tay (radian), dương = chiều kim đồng hồ
                val baseRotation = atan2((tipY - jointY).toDouble(), (tipX - jointX).toDouble())
                // Độ dài đốt xương (pixel) — dùng để tính kích thước móng
                val baseScale = hypot((tipX - jointX).toDouble(), (tipY - jointY).toDouble())

                arr.put(JSONObject().apply {
                    put("finger",       fingerNames[i])
                    put("fingerIndex",  i)              // 0=thumb … 4=pinky
                    put("baseX",        tipX)
                    put("baseY",        tipY)
                    put("baseRotation", baseRotation)
                    put("baseScale",    baseScale)
                    put("imageWidth",   imageWidth)
                    put("imageHeight",  imageHeight)
                })
            }
        }
        // Trả JSON rỗng nếu không detect được tay → Flutter sẽ báo lỗi
        return arr.toString()
    }

    // -------------------------------------------------------------------------
    // LIVE MODE: Chụp ảnh ghép overlay rồi lưu thư viện
    // -------------------------------------------------------------------------

    /**
     * Chụp ảnh bằng ImageCapture API (CameraX) thay vì viewFinder.bitmap.
     *
     * ⚠️ KHÔNG dùng viewFinder.bitmap — nó gọi SurfaceTexture.detachFromGLContext()
     * giải phóng SurfaceTexture ngay lập tức → TextureView mất Surface →
     * Camera nhận Surface gone signal → CameraDevice.close() → crash.
     *
     * ImageCapture.takePicture dùng internal ImageReader, không ảnh hưởng TextureView.
     */
    private fun captureAndSaveToGallery() {
        if (DEBUG_LOG) Log.d(TAG, "captureAndSaveToGallery: START")
        val capture = imageCapture ?: run {
            Toast.makeText(requireContext(), "Camera chưa sẵn sàng", Toast.LENGTH_SHORT).show()
            if (DEBUG_LOG) Log.e(TAG, "captureAndSaveToGallery: imageCapture is NULL")
            return
        }

        if (DEBUG_LOG) Log.v(TAG, "captureAndSaveToGallery: taking picture via ImageCapture")

        // Disable nút để tránh double-tap
        fragmentCameraBinding.btnCapture.isEnabled = false

        capture.takePicture(
            ContextCompat.getMainExecutor(requireContext()),
            object : ImageCapture.OnImageCapturedCallback() {
                @SuppressLint("UnsafeOptInUsageError")
                override fun onCaptureSuccess(imageProxy: ImageProxy) {
                    if (DEBUG_LOG) Log.v(TAG, "captureAndSaveToGallery: ImageProxy received ${imageProxy.width}x${imageProxy.height}")

                    // Chuyển ImageProxy → Bitmap trên background thread
                    backgroundExecutor.execute {
                        try {
                            val bitmap = imageProxyToBitmap(imageProxy)
                            imageProxy.close()

                            if (bitmap == null) {
                                if (DEBUG_LOG) Log.e(TAG, "captureAndSaveToGallery: ImageProxy→Bitmap failed")
                                activity?.runOnUiThread {
                                    Toast.makeText(requireContext(), "Lỗi chụp ảnh", Toast.LENGTH_SHORT).show()
                                    fragmentCameraBinding.btnCapture.isEnabled = true
                                }
                                return@execute
                            }

                            if (DEBUG_LOG) Log.v(TAG, "captureAndSaveToGallery: bitmap=${bitmap.width}x${bitmap.height}")

                            // Vẽ overlay AR lên bitmap
                            val result = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
                            val canvas = android.graphics.Canvas(result)
                            canvas.drawBitmap(bitmap, 0f, 0f, null)

                            fragmentCameraBinding.overlay.draw(canvas)

                            // Lưu vào MediaStore
                            val filename = "Nailify_${System.currentTimeMillis()}.png"
                            val values = android.content.ContentValues().apply {
                                put(android.provider.MediaStore.Images.Media.DISPLAY_NAME, filename)
                                put(android.provider.MediaStore.Images.Media.MIME_TYPE, "image/png")
                                put(android.provider.MediaStore.Images.Media.RELATIVE_PATH,
                                    android.os.Environment.DIRECTORY_PICTURES + "/Nailify")
                            }
                            val resolver = requireContext().contentResolver
                            val uri = resolver.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)

                            if (uri != null) {
                                try {
                                    resolver.openOutputStream(uri)?.use { out ->
                                        result.compress(Bitmap.CompressFormat.PNG, 100, out)
                                    }
                                    if (DEBUG_LOG) Log.i(TAG, "captureAndSaveToGallery: saved to $uri")
                                    activity?.runOnUiThread {
                                        Toast.makeText(requireContext(), "Đã lưu ảnh vào thư viện!", Toast.LENGTH_SHORT).show()
                                        fragmentCameraBinding.btnCapture.isEnabled = true
                                    }
                                } catch (e: Exception) {
                                    Log.e(TAG, "Error saving image", e)
                                    activity?.runOnUiThread {
                                        Toast.makeText(requireContext(), "Lỗi khi lưu ảnh", Toast.LENGTH_SHORT).show()
                                        fragmentCameraBinding.btnCapture.isEnabled = true
                                    }
                                }
                            } else {
                                if (DEBUG_LOG) Log.e(TAG, "captureAndSaveToGallery: MediaStore insert failed")
                                activity?.runOnUiThread {
                                    Toast.makeText(requireContext(), "Không thể tạo file ảnh", Toast.LENGTH_SHORT).show()
                                    fragmentCameraBinding.btnCapture.isEnabled = true
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "captureAndSaveToGallery: processing failed", e)
                            imageProxy.close()
                            activity?.runOnUiThread {
                                Toast.makeText(requireContext(), "Lỗi xử lý ảnh", Toast.LENGTH_SHORT).show()
                                fragmentCameraBinding.btnCapture.isEnabled = true
                            }
                        }
                    }
                }

                override fun onError(exception: ImageCaptureException) {
                    Log.e(TAG, "captureAndSaveToGallery: ImageCapture failed", exception)
                    activity?.runOnUiThread {
                        Toast.makeText(requireContext(), "Lỗi chụp ảnh: ${exception.message}", Toast.LENGTH_SHORT).show()
                        fragmentCameraBinding.btnCapture.isEnabled = true
                    }
                }
            }
        )
    }

    /**
     * Chuyển ImageProxy (CameraX) thành Bitmap (ARGB_8888).
     * ImageProxy.toBitmap() tự động xử lý mọi format (JPEG, YUV_420_888, ...).
     * Sau khi convert, bitmap được xoay đúng theo rotation.
     */
    @SuppressLint("UnsafeOptInUsageError")
    private fun imageProxyToBitmap(imageProxy: ImageProxy): Bitmap? {
        val rotation = imageProxy.imageInfo.rotationDegrees
        var bitmap = imageProxy.toBitmap()

        if (rotation != 0) {
            val matrix = android.graphics.Matrix().apply { postRotate(rotation.toFloat()) }
            val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (rotated != bitmap) {
                bitmap.recycle()
                bitmap = rotated
            }
        }
        return bitmap
    }

    // -------------------------------------------------------------------------
    // Camera setup
    // -------------------------------------------------------------------------

    private fun setUpCamera() {
        val future = ProcessCameraProvider.getInstance(requireContext())
        future.addListener({
            try {
                cameraProvider = future.get()
                bindCameraUseCases()
            } catch (e: ExecutionException) {
                Log.e(TAG, "Camera provider init failed", e)
                activity?.runOnUiThread {
                    Toast.makeText(requireContext(),
                        "Camera không khả dụng trên thiết bị này.",
                        Toast.LENGTH_LONG).show()
                    requireActivity().finish()
                }
            } catch (e: InterruptedException) {
                Log.e(TAG, "Camera provider interrupted", e)
                Thread.currentThread().interrupt()
            }
        }, ContextCompat.getMainExecutor(requireContext()))
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun bindCameraUseCases() {
        val provider = cameraProvider ?: run {
            Log.e(TAG, "cameraProvider is null")
            return
        }

        val selector = CameraSelector.Builder().requireLensFacing(cameraFacing).build()
        val targetResolution = Size(640, 480)

        preview = Preview.Builder()
            .setTargetResolution(targetResolution)
            .setTargetRotation(fragmentCameraBinding.viewFinder.display.rotation)
            .build()
        preview?.setSurfaceProvider(fragmentCameraBinding.viewFinder.surfaceProvider)

        imageAnalyzer = ImageAnalysis.Builder()
            .setTargetResolution(targetResolution)
            .setTargetRotation(fragmentCameraBinding.viewFinder.display.rotation)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build()
            .also {
                it.setAnalyzer(backgroundExecutor) { image -> detectHand(image) }
            }

        provider.unbindAll()
        try {
            camera = provider.bindToLifecycle(this, selector, preview, imageAnalyzer)
            // Bind ImageCapture sau — không dùng viewFinder.bitmap ( gây crash TextureView)
            if (imageCapture == null) {
                imageCapture = ImageCapture.Builder()
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                    .setTargetResolution(targetResolution)
                    .build()
                provider.bindToLifecycle(this, selector, preview, imageAnalyzer, imageCapture)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Use case binding failed", e)
        }
    }

    private fun detectHand(imageProxy: ImageProxy) {
        if (!this::handLandmarkerHelper.isInitialized || handLandmarkerHelper.isClose()) {
            imageProxy.close()
            return
        }
        if (!isSnapshotMode) {
            handLandmarkerHelper.detectLiveStream(
                imageProxy = imageProxy,
                isFrontCamera = cameraFacing == CameraSelector.LENS_FACING_FRONT
            )
            if (DEBUG_LOG) Log.v(TAG, "detectHand: sent frame to MediaPipe (Live mode)")
        } else {
            // Snapshot mode: không cần live stream
            imageProxy.close()
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        imageAnalyzer?.targetRotation = fragmentCameraBinding.viewFinder.display.rotation
    }

    // -------------------------------------------------------------------------
    // LandmarkerListener (chỉ được gọi ở Live mode)
    // -------------------------------------------------------------------------

    override fun onResults(resultBundle: HandLandmarkerHelper.ResultBundle) {
        if (isSnapshotMode) return
        activity?.runOnUiThread {
            if (_fragmentCameraBinding != null) {
                if (DEBUG_LOG) {
                    Log.v(TAG, "onResults (Live): inputImage=${resultBundle.inputImageWidth}x${resultBundle.inputImageHeight} " +
                        "hands=${resultBundle.results.size} " +
                        "config=shape(${viewModel.nailSetConfig.value.shape}) nails(${viewModel.nailSetConfig.value.nails.size})")
                }
                fragmentCameraBinding.overlay.setFullDesign(viewModel.nailSetConfig.value)
                fragmentCameraBinding.overlay.setResults(
                    resultBundle.results.first(),
                    resultBundle.inputImageHeight,
                    resultBundle.inputImageWidth,
                    RunningMode.LIVE_STREAM
                )
                fragmentCameraBinding.overlay.invalidate()
            }
        }
    }

    override fun onError(error: String, errorCode: Int) {
        if (DEBUG_LOG) Log.e(TAG, "onError: error=\"$error\" code=$errorCode")
        activity?.runOnUiThread {
            Toast.makeText(requireContext(), error, Toast.LENGTH_SHORT).show()
        }
    }
}
