package com.google.mediapipe.examples.handlandmarker.fragment

import android.annotation.SuppressLint
import android.content.ContentValues
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Bundle
import android.provider.MediaStore
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.core.AspectRatio
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import androidx.navigation.Navigation
import android.util.Size
import com.google.mediapipe.examples.handlandmarker.HandLandmarkerHelper
import com.google.mediapipe.examples.handlandmarker.MainViewModel
import com.google.mediapipe.examples.handlandmarker.NailLogger
import com.google.mediapipe.examples.handlandmarker.R
import com.google.mediapipe.examples.handlandmarker.databinding.FragmentCameraBinding
import com.google.mediapipe.tasks.vision.core.RunningMode
import java.nio.ByteBuffer
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.Date

class CameraFragment : Fragment(), HandLandmarkerHelper.LandmarkerListener {

    companion object {
        private const val TAG = "Hand Landmarker"
        private const val FILENAME_FORMAT = "yyyy-MM-dd-HH-mm-ss-SSS"
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

    /** Current hand detection result for snapshot capture */
    @Volatile
    private var currentResultBundle: HandLandmarkerHelper.ResultBundle? = null

    /** Flag to pause live rendering during snapshot processing */
    @Volatile
    private var isCapturing = false

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
        currentResultBundle = null
        if(this::handLandmarkerHelper.isInitialized) {
            viewModel.setMaxHands(handLandmarkerHelper.maxNumHands)
            viewModel.setMinHandDetectionConfidence(handLandmarkerHelper.minHandDetectionConfidence)
            viewModel.setMinHandTrackingConfidence(handLandmarkerHelper.minHandTrackingConfidence)
            viewModel.setMinHandPresenceConfidence(handLandmarkerHelper.minHandPresenceConfidence)
            viewModel.setDelegate(handLandmarkerHelper.currentDelegate)
            backgroundExecutor.execute { handLandmarkerHelper.clearHandLandmarker() }
        }
    }

    override fun onDestroyView() {
        currentResultBundle = null
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
            NailLogger.i(NailLogger.Component.CAMERA_FRAGMENT, "hand_landmarker_init", mapOf(
                "runningMode" to "LIVE_STREAM",
                "minHandDetectionConfidence" to viewModel.currentMinHandDetectionConfidence,
                "minHandTrackingConfidence" to viewModel.currentMinHandTrackingConfidence,
                "minHandPresenceConfidence" to viewModel.currentMinHandPresenceConfidence,
                "maxNumHands" to viewModel.currentMaxHands,
                "delegate" to viewModel.currentDelegate
            ))
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

        // FIX: Thêm listener cho nút chụp ảnh
        fragmentCameraBinding.fabCapture.setOnClickListener {
            captureSnapshot()
        }

        initBottomSheetControls()
    }

    /**
     * FIX: Chụp ảnh ngay lập tức khi bấm nút
     * Không cần chờ người dùng giữ tay - capture frame hiện tại
     */
    @SuppressLint("UnsafeOptInUsageError")
    private fun captureSnapshot() {
        if (isCapturing) return
        isCapturing = true

        NailLogger.i(NailLogger.Component.CAMERA_FRAGMENT, NailLogger.Stage.SNAPSHOT_CAPTURE, mapOf(
            "isCapturing" to true,
            "hasCurrentResult" to (currentResultBundle != null),
            "numHandsInCurrentResult" to (currentResultBundle?.results?.size ?: 0)
        ))

        // Hiển thị progress
        activity?.runOnUiThread {
            fragmentCameraBinding.fabCapture.visibility = View.GONE
            fragmentCameraBinding.progressCapture.visibility = View.VISIBLE
        }

        // Lấy current result đã detect được
        val resultBundle = currentResultBundle
        if (resultBundle == null || resultBundle.results.isEmpty()) {
            NailLogger.w(NailLogger.Component.CAMERA_FRAGMENT, NailLogger.Stage.SNAPSHOT_CAPTURE, mapOf(
                "reason" to "NO_HAND_DETECTED",
                "result" to "ABORTED"
            ))
            Toast.makeText(requireContext(), "Vui lòng đưa tay vào camera trước khi chụp", Toast.LENGTH_SHORT).show()
            resetCaptureUI()
            return
        }

        // Chụp bitmap từ frame hiện tại
        imageAnalyzer?.setAnalyzer(backgroundExecutor) { imageProxy ->
            try {
                val captureStart = System.currentTimeMillis()
                val bitmap = imageProxyToBitmap(imageProxy)
                imageProxy.close()

                if (bitmap != null) {
                    NailLogger.d(
                        NailLogger.Component.CAMERA_FRAGMENT,
                        NailLogger.Stage.SNAPSHOT_CAPTURE,
                        mapOf(
                            "bitmapCaptureTime" to (System.currentTimeMillis() - captureStart),
                            "bitmapWidth" to bitmap.width,
                            "bitmapHeight" to bitmap.height,
                            "numHands" to resultBundle.results.size
                        )
                    )
                    processSnapshot(bitmap, resultBundle)
                } else {
                    NailLogger.e(NailLogger.Component.CAMERA_FRAGMENT, NailLogger.Stage.SNAPSHOT_CAPTURE, "Bitmap is null", null)
                    activity?.runOnUiThread {
                        Toast.makeText(requireContext(), "Không thể chụp ảnh", Toast.LENGTH_SHORT).show()
                    }
                    resetCaptureUI()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error capturing snapshot: ${e.message}")
                NailLogger.e(NailLogger.Component.CAMERA_FRAGMENT, NailLogger.Stage.SNAPSHOT_CAPTURE, "Exception during capture", e)
                imageProxy.close()
                resetCaptureUI()
            }
        }
    }

    /**
     * FIX: Chuyển ImageProxy thành Bitmap
     */
    private fun imageProxyToBitmap(imageProxy: ImageProxy): Bitmap? {
        return try {
            val buffer: ByteBuffer = imageProxy.planes[0].buffer
            val bytes = ByteArray(buffer.remaining())
            buffer.get(bytes)

            val bitmap = android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)

            // Xoay bitmap theo rotation của image
            val matrix = Matrix().apply {
                postRotate(imageProxy.imageInfo.rotationDegrees.toFloat())
                if (cameraFacing == CameraSelector.LENS_FACING_FRONT) {
                    postScale(-1f, 1f)
                }
            }

            Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        } catch (e: Exception) {
            Log.e(TAG, "Error converting image to bitmap: ${e.message}")
            null
        }
    }

    /**
     * FIX: Xử lý snapshot - render nails lên bitmap và lưu
     */
    private fun processSnapshot(bitmap: Bitmap, resultBundle: HandLandmarkerHelper.ResultBundle) {
        backgroundExecutor.execute {
            try {
                NailLogger.i(NailLogger.Component.CAMERA_FRAGMENT, NailLogger.Stage.SNAPSHOT_PROCESS, mapOf(
                    "bitmapWidth" to bitmap.width,
                    "bitmapHeight" to bitmap.height,
                    "numHands" to resultBundle.results.size,
                    "nailDesignName" to (viewModel.nailSetConfig.value?.name ?: "null"),
                    "numNails" to (viewModel.nailSetConfig.value?.nails?.size ?: 0)
                ))

                // Tạo bitmap có thể modify
                val mutableBitmap = bitmap.copy(Bitmap.Config.ARGB_8888, true)

                // Tạo temporary OverlayView để render
                val tempOverlay = object : com.google.mediapipe.examples.handlandmarker.OverlayView(requireContext(), null) {
                    override fun onDraw(canvas: android.graphics.Canvas) {
                        // Override để không vẽ gì - chúng ta sẽ gọi draw() thủ công
                    }
                }

                // Setup overlay với nail design và results
                tempOverlay.setFullDesign(viewModel.nailSetConfig.value)
                tempOverlay.setResults(
                    resultBundle.results.first(),
                    resultBundle.inputImageHeight,
                    resultBundle.inputImageWidth,
                    RunningMode.IMAGE
                )

                // Vẽ nails lên bitmap
                val canvas = android.graphics.Canvas(mutableBitmap)
                val renderStart = System.currentTimeMillis()
                tempOverlay.draw(canvas)
                NailLogger.d(NailLogger.Component.CAMERA_FRAGMENT, NailLogger.Stage.NAIL_RENDER, mapOf(
                    "overlayRenderTimeMs" to (System.currentTimeMillis() - renderStart)
                ))

                // Lưu bitmap vào gallery
                val saveStart = System.currentTimeMillis()
                val savedUri = saveBitmapToGallery(mutableBitmap)

                activity?.runOnUiThread {
                    if (savedUri != null) {
                        NailLogger.i(NailLogger.Component.CAMERA_FRAGMENT, NailLogger.Stage.BITMAP_SAVE, mapOf(
                            "saveTimeMs" to (System.currentTimeMillis() - saveStart),
                            "savedUri" to (savedUri.path ?: "unknown")
                        ))
                        Toast.makeText(
                            requireContext(),
                            "Đã lưu ảnh: ${savedUri.path}",
                            Toast.LENGTH_LONG
                        ).show()
                    } else {
                        Toast.makeText(
                            requireContext(),
                            "Đã chụp ảnh thành công!",
                            Toast.LENGTH_SHORT
                        ).show()
                    }
                    resetCaptureUI()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error processing snapshot: ${e.message}")
                NailLogger.e(NailLogger.Component.CAMERA_FRAGMENT, NailLogger.Stage.SNAPSHOT_PROCESS, "Error processing snapshot", e)
                activity?.runOnUiThread {
                    Toast.makeText(requireContext(), "Lỗi xử lý ảnh: ${e.message}", Toast.LENGTH_SHORT).show()
                    resetCaptureUI()
                }
            }
        }
    }

    /**
     * FIX: Lưu bitmap vào gallery
     */
    private fun saveBitmapToGallery(bitmap: Bitmap): android.net.Uri? {
        val timestamp = SimpleDateFormat(FILENAME_FORMAT, Locale.US).format(Date())
        val filename = "Nailify_$timestamp.jpg"

        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/Nailify")
        }

        val resolver = requireContext().contentResolver
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)

        return uri?.also { imageUri ->
            resolver.openOutputStream(imageUri)?.use { outputStream ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 95, outputStream)
            }
        }
    }

    private fun resetCaptureUI() {
        isCapturing = false
        activity?.runOnUiThread {
            fragmentCameraBinding.fabCapture.visibility = View.VISIBLE
            fragmentCameraBinding.progressCapture.visibility = View.GONE
        }
    }

    private fun initBottomSheetControls() {
        // init bottom sheet settings
        fragmentCameraBinding.bottomSheetLayout.maxHandsValue.text =
            viewModel.currentMaxHands.toString()
        fragmentCameraBinding.bottomSheetLayout.detectionThresholdValue.text =
            String.format(
                Locale.US, "%.2f", viewModel.currentMinHandDetectionConfidence
            )
        fragmentCameraBinding.bottomSheetLayout.trackingThresholdValue.text =
            String.format(
                Locale.US, "%.2f", viewModel.currentMinHandTrackingConfidence
            )
        fragmentCameraBinding.bottomSheetLayout.presenceThresholdValue.text =
            String.format(
                Locale.US, "%.2f", viewModel.currentMinHandPresenceConfidence
            )

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
        // ── BƯỚC 0: BẮT NGAY BITMAP NGAY KHI NÚT ĐƯỢC BẤM ──────────────────────
        // viewFinder.bitmap lấy frame hiện tại (synchronous) — PHẢI gọi trên main thread.
        val bitmap = fragmentCameraBinding.viewFinder.bitmap
        if (bitmap == null) {
            Toast.makeText(requireContext(), "Camera chưa sẵn sàng", Toast.LENGTH_SHORT).show()
            return
        }

        // Chuẩn bị bitmap mutable ARGB_8888 để vẽ lên (làm ngay trước khi hiệu ứng)
        val mutableBitmap = if (bitmap.config == Bitmap.Config.ARGB_8888 && bitmap.isMutable) {
            bitmap
        } else {
            bitmap.copy(Bitmap.Config.ARGB_8888, true)
        }

        // ── BƯỚC 1: PHẢN HỒI TRỰC QUAN NGAY LẬP TỨC ────────────────────────────
        // Người dùng thấy ảnh "đông cứng" → biết đã chụp xong → có thể thả tay.
        fragmentCameraBinding.btnTakePhoto.isEnabled = false

        // Hiện freeze frame đè lên camera preview
        fragmentCameraBinding.imgFreezeFrame.apply {
            setImageBitmap(mutableBitmap)
            visibility = android.view.View.VISIBLE
        }

        // Flash shutter: hiện overlay trắng → fade out trong 150ms
        fragmentCameraBinding.viewShutterFlash.apply {
            visibility = android.view.View.VISIBLE
            alpha = 1f
            animate()
                .alpha(0f)
                .setDuration(150)
                .withEndAction { visibility = android.view.View.GONE }
                .start()
        }

        // Bước 1: Chạy MediaPipe ở background thread (không block main thread)
        backgroundExecutor.execute {
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

                // ── MULTI-ATTEMPT DETECTION ──────────────────────────────────────────
                // Thử nhiều mức tăng cường ảnh khác nhau, dừng khi tìm thấy bàn tay.
                // CHỈ dùng ảnh gốc (không xoay) — nếu xoay, toạ độ landmark sẽ bị lệch!
                data class Attempt(val contrastScale: Float, val brightAdd: Float)
                val attempts = listOf(
                    Attempt(1.0f,  0f),   // Ảnh gốc
                    Attempt(1.35f, 25f),  // Tăng nhẹ
                    Attempt(1.7f,  50f),  // Tăng vừa
                    Attempt(2.0f,  70f),  // Tăng mạnh
                )

                var resultBundle: HandLandmarkerHelper.ResultBundle? = null

                for (attempt in attempts) {
                    val candidate = enhanceBitmapWithParams(mutableBitmap, attempt.contrastScale, attempt.brightAdd)
                    val bundle = imageHelper.detectImage(candidate)
                    val found  = bundle != null &&
                            bundle.results.isNotEmpty() &&
                            bundle.results.first().landmarks().isNotEmpty()
                    if (found) {
                        resultBundle = bundle
                        Log.d(TAG, "Hand detected: contrast=${attempt.contrastScale} bright=${attempt.brightAdd}")
                        break
                    }
                }
                imageHelper.clearHandLandmarker()

                val hasHand = resultBundle != null


                // Bước 2: Chuẩn bị config + preload bitmaps TRÊN BACKGROUND THREAD
                // (network I/O không được phép chạy trên main thread)
                val currentConfig = viewModel.nailSetConfig.value
                if (hasHand) {
                    fragmentCameraBinding.overlay.preloadAllBitmapsForSnapshot(currentConfig)
                }

                // Bước 3: Switch về main thread để render AR lên bitmap
                // Lúc này TẤT CẢ bitmaps đã sẵn sàng trong cache → vẽ ngay không chờ
                activity?.runOnUiThread {
                    try {
                        if (hasHand) {
                            fragmentCameraBinding.overlay.setFullDesign(currentConfig)

                            // Render móng lên ảnh gốc (luôn dùng kích thước gốc — không xoay)
                            fragmentCameraBinding.overlay.renderOnBitmap(
                                targetBitmap = mutableBitmap,
                                result  = resultBundle!!.results.first(),
                                imgW    = mutableBitmap.width,
                                imgH    = mutableBitmap.height
                            )
                        }

                        // Bước 4: Lưu ảnh (có hoặc không có móng) vào cache
                        backgroundExecutor.execute {
                            try {
                                val cacheDir = requireContext().cacheDir
                                cacheDir.listFiles { _, name -> name.startsWith("hand_snapshot_") }
                                    ?.forEach { it.delete() }

                                val cacheFile = File(cacheDir, "hand_snapshot_${System.currentTimeMillis()}.jpg")
                                FileOutputStream(cacheFile).use { out ->
                                    mutableBitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
                                }

                                // Bước 5: Trả kết quả về Flutter (Activity finish → freeze frame tự dismiss)
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
                                    hideFreezeFrame()
                                    fragmentCameraBinding.btnTakePhoto.isEnabled = true
                                    Toast.makeText(requireContext(), "Lỗi lưu ảnh: ${e.message}", Toast.LENGTH_SHORT).show()
                                }
                            }
                        }
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
        }
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
        val startTime = System.currentTimeMillis()
        handLandmarkerHelper.detectLiveStream(
            imageProxy = imageProxy,
            isFrontCamera = cameraFacing == CameraSelector.LENS_FACING_FRONT
        )
        NailLogger.d(
            NailLogger.Component.CAMERA_FRAGMENT,
            NailLogger.Stage.HAND_DETECT,
            mapOf(
                "frameProcessingTime" to (System.currentTimeMillis() - startTime),
                "isFrontCamera" to (cameraFacing == CameraSelector.LENS_FACING_FRONT),
                "imageWidth" to imageProxy.width,
                "imageHeight" to imageProxy.height,
                "rotationDegrees" to imageProxy.imageInfo.rotationDegrees
            )
        )
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        imageAnalyzer?.targetRotation = fragmentCameraBinding.viewFinder.display.rotation
    }

    // Update UI after hand have been detected. Extracts original
    // image height/width to scale and place the landmarks properly through
    // OverlayView
    override fun onResults(
        resultBundle: HandLandmarkerHelper.ResultBundle
    ) {
        // Lưu kết quả hiện tại để dùng khi capture snapshot
        currentResultBundle = resultBundle

        // Log hand detection results
        val numHands = resultBundle.results.size
        val numLandmarks = if (numHands > 0) resultBundle.results.first().landmarks().size else 0
        NailLogger.d(
            NailLogger.Component.CAMERA_FRAGMENT,
            NailLogger.Stage.LANDMARK_EXTRACT,
            mapOf(
                "numHands" to numHands,
                "numLandmarksPerHand" to numLandmarks,
                "inferenceTime" to resultBundle.inferenceTime,
                "inputImageWidth" to resultBundle.inputImageWidth,
                "inputImageHeight" to resultBundle.inputImageHeight
            )
        )

        activity?.runOnUiThread {
            if (_fragmentCameraBinding != null) {
                fragmentCameraBinding.bottomSheetLayout.inferenceTimeVal.text =
                    String.format("%d ms", resultBundle.inferenceTime)

                // Chỉ render nếu không đang capture
                if (!isCapturing) {
                    // Pass necessary information to OverlayView for drawing on the canvas
                    fragmentCameraBinding.overlay.setFullDesign(viewModel.nailSetConfig.value)

                    fragmentCameraBinding.overlay.setResults(
                        resultBundle.results.first(),
                        resultBundle.inputImageHeight,
                        resultBundle.inputImageWidth,
                        RunningMode.LIVE_STREAM
                    )

                    NailLogger.d(
                        NailLogger.Component.CAMERA_FRAGMENT,
                        "live_render_triggered",
                        mapOf(
                            "numHands" to numHands,
                            "nailDesign" to viewModel.nailSetConfig.value?.name,
                            "numNails" to viewModel.nailSetConfig.value?.nails?.size
                        )
                    )

                    // Force a redraw
                    fragmentCameraBinding.overlay.invalidate()
                } else {
                    NailLogger.d(
                        NailLogger.Component.CAMERA_FRAGMENT,
                        "live_render_skipped",
                        mapOf("reason" to "isCapturing=true")
                    )
                }
            }
        }
    }

    override fun onError(error: String, errorCode: Int) {
        activity?.runOnUiThread {
            Toast.makeText(requireContext(), error, Toast.LENGTH_SHORT).show()
        }
    }
}
