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
        private const val TAG = "Hand Landmarker"

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
        val bitmap = fragmentCameraBinding.viewFinder.bitmap
        if (bitmap == null) {
            Toast.makeText(requireContext(), "Camera chưa sẵn sàng", Toast.LENGTH_SHORT).show()
            return
        }

        fragmentCameraBinding.btnTakePhoto.isEnabled = false
        Toast.makeText(requireContext(), "Đang xử lý hình ảnh…", Toast.LENGTH_SHORT).show()

        // Chuẩn bị bitmap mutable ARGB_8888 để vẽ lên
        val mutableBitmap = if (bitmap.config == Bitmap.Config.ARGB_8888&& bitmap.isMutable) {
            bitmap
        } else {
            bitmap.copy(Bitmap.Config.ARGB_8888, true)
        }

        // Bước 1: Chạy MediaPipe ở background thread (không block main thread)
        backgroundExecutor.execute {
            try {
                val imageHelper = HandLandmarkerHelper(
                    context = requireContext(),
                    runningMode = RunningMode.IMAGE,
                    minHandDetectionConfidence = 0.3f,
                    minHandTrackingConfidence  = 0.3f,
                    minHandPresenceConfidence  = 0.3f,
                    maxNumHands = 1,
                    currentDelegate = HandLandmarkerHelper.DELEGATE_CPU
                )
                val resultBundle = imageHelper.detectImage(mutableBitmap)
                imageHelper.clearHandLandmarker()

                // Bước 2: Switch về main thread để render AR lên bitmap
                // (renderOnBitmap() là Canvas operation — phải chạy trên main thread)
                activity?.runOnUiThread {
                    try {
                        val hasHand = resultBundle != null &&
                                resultBundle.results.isNotEmpty() &&
                                resultBundle.results.first().landmarks().isNotEmpty()

                        if (hasHand) {
                            // Đảm bảo config móng đã được set đúng trên OverlayView
                            val currentConfig = viewModel.nailSetConfig.value
                            fragmentCameraBinding.overlay.setFullDesign(currentConfig)

                            // Gọi renderOnBitmap() — dùng chung thuật toán với Live mode
                            fragmentCameraBinding.overlay.renderOnBitmap(
                                targetBitmap = mutableBitmap,
                                result  = resultBundle!!.results.first(),
                                imgW    = mutableBitmap.width,
                                imgH    = mutableBitmap.height
                            )
                        }

                        // Bước 3: Lưu ảnh (có hoặc không có móng) vào cache
                        backgroundExecutor.execute {
                            try {
                                val cacheDir = requireContext().cacheDir
                                cacheDir.listFiles { _, name -> name.startsWith("hand_snapshot_") }
                                    ?.forEach { it.delete() }

                                val cacheFile = File(cacheDir, "hand_snapshot_${System.currentTimeMillis()}.jpg")
                                FileOutputStream(cacheFile).use { out ->
                                    mutableBitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
                                }

                                // Bước 4: Trả kết quả về Flutter
                                val landmarksJson = if (hasHand) "[{\"finger\":\"detected\"}]" else "[]"

                                activity?.runOnUiThread {
                                    val resultIntent = Intent().apply {
                                        putExtra(RESULT_IMAGE_PATH, cacheFile.absolutePath)
                                        putExtra(RESULT_LANDMARKS_JSON, landmarksJson)
                                    }
                                    requireActivity().setResult(Activity.RESULT_OK, resultIntent)
                                    requireActivity().finish()
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "Save snapshot failed", e)
                                activity?.runOnUiThread {
                                    fragmentCameraBinding.btnTakePhoto.isEnabled = true
                                    Toast.makeText(requireContext(), "Lỗi lưu ảnh: ${e.message}", Toast.LENGTH_SHORT).show()
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Render snapshot failed", e)
                        fragmentCameraBinding.btnTakePhoto.isEnabled = true
                        Toast.makeText(requireContext(), "Lỗi vẽ móng: ${e.message}", Toast.LENGTH_SHORT).show()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "MediaPipe snapshot failed", e)
                activity?.runOnUiThread {
                    fragmentCameraBinding.btnTakePhoto.isEnabled = true
                    Toast.makeText(requireContext(), "Lỗi phân tích bàn tay: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            }
        }
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

    private fun captureAndSaveToGallery() {
        val previewBitmap = fragmentCameraBinding.viewFinder.bitmap ?: run {
            Toast.makeText(requireContext(), "Camera chưa sẵn sàng", Toast.LENGTH_SHORT).show()
            return
        }

        val result = Bitmap.createBitmap(previewBitmap.width, previewBitmap.height, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(result)
        canvas.drawBitmap(previewBitmap, 0f, 0f, null)
        fragmentCameraBinding.overlay.draw(canvas)

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
                Toast.makeText(requireContext(), "Đã lưu ảnh vào thư viện!", Toast.LENGTH_SHORT).show()
            } catch (e: Exception) {
                Log.e(TAG, "Error saving image", e)
                Toast.makeText(requireContext(), "Lỗi khi lưu ảnh", Toast.LENGTH_SHORT).show()
            }
        } else {
            Toast.makeText(requireContext(), "Không thể tạo file ảnh", Toast.LENGTH_SHORT).show()
        }
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
        } else {
            // Snapshot mode: không cần live stream phân tích realtime
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
        activity?.runOnUiThread {
            Toast.makeText(requireContext(), error, Toast.LENGTH_SHORT).show()
        }
    }
}
