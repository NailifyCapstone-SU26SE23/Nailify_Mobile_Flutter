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
import android.widget.AdapterView
import android.widget.Toast
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.core.AspectRatio
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import androidx.navigation.Navigation
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

    private val fragmentCameraBinding
        get() = _fragmentCameraBinding!!

    private lateinit var handLandmarkerHelper: HandLandmarkerHelper
    private val viewModel: MainViewModel by activityViewModels()
    private var preview: Preview? = null
    private var imageAnalyzer: ImageAnalysis? = null
    private var camera: Camera? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var cameraFacing = CameraSelector.LENS_FACING_BACK

    /** Blocking ML operations are performed using this executor */
    private lateinit var backgroundExecutor: ExecutorService

    /** Current hand detection result for snapshot capture */
    @Volatile
    private var currentResultBundle: HandLandmarkerHelper.ResultBundle? = null

    /** Flag to pause live rendering during snapshot processing */
    @Volatile
    private var isCapturing = false

    override fun onResume() {
        super.onResume()
        // Make sure that all permissions are still present, since the
        // user could have removed them while the app was in paused state.
        if (!PermissionsFragment.hasPermissions(requireContext())) {
            Navigation.findNavController(
                requireActivity(), R.id.fragment_container
            ).navigate(R.id.action_camera_to_permissions)
        }

        // Start the HandLandmarkerHelper again when users come back
        // to the foreground.
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

            // Close the HandLandmarkerHelper and release resources
            backgroundExecutor.execute { handLandmarkerHelper.clearHandLandmarker() }
        }
    }

    override fun onDestroyView() {
        currentResultBundle = null
        _fragmentCameraBinding = null
        super.onDestroyView()

        // Shut down our background executor
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
        _fragmentCameraBinding =
            FragmentCameraBinding.inflate(inflater, container, false)

        return fragmentCameraBinding.root
    }

    @SuppressLint("MissingPermission")
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Initialize our background executor
        backgroundExecutor = Executors.newSingleThreadExecutor()

        // Wait for the views to be properly laid out
        fragmentCameraBinding.viewFinder.post {
            // Set up the camera and its use cases
            setUpCamera()
        }

        // Create the HandLandmarkerHelper that will handle the inference
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

        // Attach listeners to UI control widgets
        fragmentCameraBinding.btnBack.setOnClickListener {
            requireActivity().finish()
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

        // When clicked, lower hand detection score threshold floor
        fragmentCameraBinding.bottomSheetLayout.detectionThresholdMinus.setOnClickListener {
            if (handLandmarkerHelper.minHandDetectionConfidence >= 0.2) {
                handLandmarkerHelper.minHandDetectionConfidence -= 0.1f
                updateControlsUi()
            }
        }

        // When clicked, raise hand detection score threshold floor
        fragmentCameraBinding.bottomSheetLayout.detectionThresholdPlus.setOnClickListener {
            if (handLandmarkerHelper.minHandDetectionConfidence <= 0.8) {
                handLandmarkerHelper.minHandDetectionConfidence += 0.1f
                updateControlsUi()
            }
        }

        // When clicked, lower hand tracking score threshold floor
        fragmentCameraBinding.bottomSheetLayout.trackingThresholdMinus.setOnClickListener {
            if (handLandmarkerHelper.minHandTrackingConfidence >= 0.2) {
                handLandmarkerHelper.minHandTrackingConfidence -= 0.1f
                updateControlsUi()
            }
        }

        // When clicked, raise hand tracking score threshold floor
        fragmentCameraBinding.bottomSheetLayout.trackingThresholdPlus.setOnClickListener {
            if (handLandmarkerHelper.minHandTrackingConfidence <= 0.8) {
                handLandmarkerHelper.minHandTrackingConfidence += 0.1f
                updateControlsUi()
            }
        }

        // When clicked, lower hand presence score threshold floor
        fragmentCameraBinding.bottomSheetLayout.presenceThresholdMinus.setOnClickListener {
            if (handLandmarkerHelper.minHandPresenceConfidence >= 0.2) {
                handLandmarkerHelper.minHandPresenceConfidence -= 0.1f
                updateControlsUi()
            }
        }

        // When clicked, raise hand presence score threshold floor
        fragmentCameraBinding.bottomSheetLayout.presenceThresholdPlus.setOnClickListener {
            if (handLandmarkerHelper.minHandPresenceConfidence <= 0.8) {
                handLandmarkerHelper.minHandPresenceConfidence += 0.1f
                updateControlsUi()
            }
        }

        // When clicked, reduce the number of hands that can be detected at a
        // time
        fragmentCameraBinding.bottomSheetLayout.maxHandsMinus.setOnClickListener {
            if (handLandmarkerHelper.maxNumHands > 1) {
                handLandmarkerHelper.maxNumHands--
                updateControlsUi()
            }
        }

        // When clicked, increase the number of hands that can be detected
        // at a time
        fragmentCameraBinding.bottomSheetLayout.maxHandsPlus.setOnClickListener {
            if (handLandmarkerHelper.maxNumHands < 2) {
                handLandmarkerHelper.maxNumHands++
                updateControlsUi()
            }
        }

        // When clicked, change the underlying hardware used for inference.
        // Current options are CPU and GPU
        fragmentCameraBinding.bottomSheetLayout.spinnerDelegate.setSelection(
            viewModel.currentDelegate, false
        )
        fragmentCameraBinding.bottomSheetLayout.spinnerDelegate.onItemSelectedListener =
            object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(
                    p0: AdapterView<*>?, p1: View?, p2: Int, p3: Long
                ) {
                    try {
                        handLandmarkerHelper.currentDelegate = p2
                        updateControlsUi()
                    } catch(e: UninitializedPropertyAccessException) {
                        Log.e(TAG, "HandLandmarkerHelper has not been initialized yet.")
                    }
                }

                override fun onNothingSelected(p0: AdapterView<*>?) {
                    /* no op */
                }
            }
    }

    // Update the values displayed in the bottom sheet. Reset Handlandmarker
    // helper.
    private fun updateControlsUi() {
        fragmentCameraBinding.bottomSheetLayout.maxHandsValue.text =
            handLandmarkerHelper.maxNumHands.toString()
        fragmentCameraBinding.bottomSheetLayout.detectionThresholdValue.text =
            String.format(
                Locale.US,
                "%.2f",
                handLandmarkerHelper.minHandDetectionConfidence
            )
        fragmentCameraBinding.bottomSheetLayout.trackingThresholdValue.text =
            String.format(
                Locale.US,
                "%.2f",
                handLandmarkerHelper.minHandTrackingConfidence
            )
        fragmentCameraBinding.bottomSheetLayout.presenceThresholdValue.text =
            String.format(
                Locale.US,
                "%.2f",
                handLandmarkerHelper.minHandPresenceConfidence
            )

        // Needs to be cleared instead of reinitialized because the GPU
        // delegate needs to be initialized on the thread using it when applicable
        backgroundExecutor.execute {
            handLandmarkerHelper.clearHandLandmarker()
            handLandmarkerHelper.setupHandLandmarker()
        }
        fragmentCameraBinding.overlay.clear()
    }

    // Initialize CameraX, and prepare to bind the camera use cases
    private fun setUpCamera() {
        val cameraProviderFuture =
            ProcessCameraProvider.getInstance(requireContext())
        cameraProviderFuture.addListener(
            {
                // CameraProvider
                cameraProvider = cameraProviderFuture.get()

                // Build and bind the camera use cases
                bindCameraUseCases()
            }, ContextCompat.getMainExecutor(requireContext())
        )
    }

    // Declare and bind preview, capture and analysis use cases
    @SuppressLint("UnsafeOptInUsageError")
    private fun bindCameraUseCases() {

        // CameraProvider
        val cameraProvider = cameraProvider
            ?: throw IllegalStateException("Camera initialization failed.")

        val cameraSelector =
            CameraSelector.Builder().requireLensFacing(cameraFacing).build()

        // Preview. Only using the 4:3 ratio because this is the closest to our models
        preview = Preview.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3)
            .setTargetRotation(fragmentCameraBinding.viewFinder.display.rotation)
            .build()

        // ImageAnalysis. Using RGBA 8888 to match how our models work
        imageAnalyzer =
            ImageAnalysis.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3)
                .setTargetRotation(fragmentCameraBinding.viewFinder.display.rotation)
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .build()
                // The analyzer can then be assigned to the instance
                .also {
                    it.setAnalyzer(backgroundExecutor) { image ->
                        detectHand(image)
                    }
                }

        // Must unbind the use-cases before rebinding them
        cameraProvider.unbindAll()

        try {
            // A variable number of use-cases can be passed here -
            // camera provides access to CameraControl & CameraInfo
            camera = cameraProvider.bindToLifecycle(
                this, cameraSelector, preview, imageAnalyzer
            )

            // Attach the viewfinder's surface provider to preview use case
            preview?.setSurfaceProvider(fragmentCameraBinding.viewFinder.surfaceProvider)
        } catch (exc: Exception) {
            Log.e(TAG, "Use case binding failed", exc)
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
        imageAnalyzer?.targetRotation =
            fragmentCameraBinding.viewFinder.display.rotation
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
            if (errorCode == HandLandmarkerHelper.GPU_ERROR) {
                fragmentCameraBinding.bottomSheetLayout.spinnerDelegate.setSelection(
                    HandLandmarkerHelper.DELEGATE_CPU, false
                )
            }
        }
    }
}
