package com.google.mediapipe.examples.handlandmarker.fragment

import android.annotation.SuppressLint
import android.content.Context
import android.content.res.Configuration
import android.os.Bundle
import android.util.Log
import android.util.Size
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.camera.core.Preview
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Camera
import androidx.camera.core.AspectRatio
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import androidx.navigation.Navigation
import com.google.mediapipe.examples.handlandmarker.HandLandmarkerHelper
import com.google.mediapipe.examples.handlandmarker.MainViewModel
import com.google.mediapipe.examples.handlandmarker.R
import com.google.mediapipe.examples.handlandmarker.databinding.FragmentCameraBinding
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.vision.core.RunningMode
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.acos
import kotlin.math.sqrt

class CameraFragment : Fragment(), HandLandmarkerHelper.LandmarkerListener {

    companion object {
        private const val TAG = "Hand Landmarker"
        const val RESULT_IMAGE_PATH = "imagePath"
        const val RESULT_LANDMARKS_JSON = "landmarksJson"
        private const val LIVE_ANALYSIS_WIDTH = 640
        private const val LIVE_ANALYSIS_HEIGHT = 480
        private const val NAIL_VISIBILITY_MODEL_ASSET = "nail_visibility_model.json"
        private const val NAIL_VISIBILITY_FALSE_CONFIRMATION_MS = 3_000L
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
    private var nailVisibilityModel: NailVisibilityModel? = null
    private var nailVisibilityFalseStartMs: Long? = null

    /** Blocking ML operations are performed using this executor */
    private lateinit var backgroundExecutor: ExecutorService

    override fun onResume() {
        super.onResume()
        val context = context ?: return
        val activity = activity ?: return

        // Make sure that all permissions are still present, since the
        // user could have removed them while the app was in paused state.
        if (!PermissionsFragment.hasPermissions(context)) {
            Navigation.findNavController(
                activity, R.id.fragment_container
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
        if (this::handLandmarkerHelper.isInitialized) {
            handLandmarkerHelper.close()
        }
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
        val appContext = view.context.applicationContext
        nailVisibilityModel = loadNailVisibilityModel(appContext)

        // Wait for the views to be properly laid out
        fragmentCameraBinding.viewFinder.post {
            if (_fragmentCameraBinding == null || !isAdded) return@post
            // Set up the camera and its use cases
            setUpCamera()
        }

        // Create the HandLandmarkerHelper that will handle the inference
        backgroundExecutor.execute {
            handLandmarkerHelper = HandLandmarkerHelper(
                context = appContext,
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
            activity?.finish()
        }

    }

    // Initialize CameraX, and prepare to bind the camera use cases
    private fun setUpCamera() {
        val context = context ?: return
        val cameraProviderFuture =
            ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener(
            {
                if (_fragmentCameraBinding == null || !isAdded) return@addListener
                // CameraProvider
                cameraProvider = cameraProviderFuture.get()

                // Build and bind the camera use cases
                bindCameraUseCases()
            }, ContextCompat.getMainExecutor(context)
        )
    }

    // Declare and bind preview, capture and analysis use cases
    @SuppressLint("UnsafeOptInUsageError")
    private fun bindCameraUseCases() {
        val binding = _fragmentCameraBinding ?: return
        if (!isAdded) return

        // CameraProvider
        val cameraProvider = cameraProvider
            ?: throw IllegalStateException("Camera initialization failed.")

        val cameraSelector =
            CameraSelector.Builder().requireLensFacing(cameraFacing).build()

        // Preview. Only using the 4:3 ratio because this is the closest to our models
        preview = Preview.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3)
            .setTargetRotation(binding.viewFinder.display.rotation)
            .build()

        // ImageAnalysis. Using RGBA 8888 to match how our models work
        imageAnalyzer =
            ImageAnalysis.Builder()
                .setTargetResolution(Size(LIVE_ANALYSIS_WIDTH, LIVE_ANALYSIS_HEIGHT))
                .setTargetRotation(binding.viewFinder.display.rotation)
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
            preview?.setSurfaceProvider(binding.viewFinder.surfaceProvider)
        } catch (exc: Exception) {
            Log.e(TAG, "Use case binding failed", exc)
        }
    }

    private fun detectHand(imageProxy: ImageProxy) {
        if (!this::handLandmarkerHelper.isInitialized || handLandmarkerHelper.isClose()) {
            imageProxy.close()
            return
        }
        handLandmarkerHelper.detectLiveStream(
            imageProxy = imageProxy,
            isFrontCamera = cameraFacing == CameraSelector.LENS_FACING_FRONT
        )
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        val binding = _fragmentCameraBinding ?: return
        imageAnalyzer?.targetRotation =
            binding.viewFinder.display.rotation
    }

    // Update UI after hand have been detected. Extracts original
    // image height/width to scale and place the landmarks properly through
    // OverlayView
    override fun onResults(
        resultBundle: HandLandmarkerHelper.ResultBundle
    ) {
        activity?.runOnUiThread {
            val binding = _fragmentCameraBinding ?: return@runOnUiThread

            val result = resultBundle.results.first()
            val nailsVisible = isNailVisible(result.landmarks().firstOrNull())
            val shouldShowOverlay = shouldShowOverlay(nailsVisible)
            binding.nailVisibilityPrompt.visibility =
                if (shouldShowOverlay) View.GONE else View.VISIBLE
            binding.overlay.visibility =
                if (shouldShowOverlay) View.VISIBLE else View.GONE

            if (shouldShowOverlay) {
                // Pass necessary information to OverlayView for drawing on the canvas
                binding.overlay.setFullDesign(viewModel.nailSetConfig.value)

                binding.overlay.setResults(
                    result,
                    resultBundle.inputImageHeight,
                    resultBundle.inputImageWidth,
                    RunningMode.LIVE_STREAM
                )
            } else {
                binding.overlay.clear()
            }

            // Force a redraw
            binding.overlay.invalidate()
        }
    }

    private fun shouldShowOverlay(nailsVisible: Boolean): Boolean {
        if (nailsVisible) {
            nailVisibilityFalseStartMs = null
            return true
        }

        val now = System.currentTimeMillis()
        val falseStartMs = nailVisibilityFalseStartMs ?: now.also {
            nailVisibilityFalseStartMs = it
        }
        return now - falseStartMs < NAIL_VISIBILITY_FALSE_CONFIRMATION_MS
    }

    private fun loadNailVisibilityModel(context: Context): NailVisibilityModel? {
        return try {
            val json = context.assets.open(NAIL_VISIBILITY_MODEL_ASSET)
                .bufferedReader()
                .use { it.readText() }
            NailVisibilityModel.fromJson(JSONObject(json))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load nail visibility model.", e)
            null
        }
    }

    private fun isNailVisible(landmarks: List<NormalizedLandmark>?): Boolean {
        if (landmarks == null || landmarks.size <= 20) return false
        val model = nailVisibilityModel ?: return true
        return model.isNailVisible(extractNailVisibilityFeatures(landmarks))
    }

    private fun extractNailVisibilityFeatures(landmarks: List<NormalizedLandmark>): DoubleArray {
        val features = mutableListOf<Double>()
        listOf(8 to 6, 12 to 10, 16 to 14, 20 to 18).forEach { (tipIndex, pipIndex) ->
            features += landmarks[tipIndex].z().toDouble() - landmarks[pipIndex].z().toDouble()
        }
        listOf(
            Triple(8, 6, 5),
            Triple(12, 10, 9),
            Triple(16, 14, 13),
            Triple(20, 18, 17)
        ).forEach { (tipIndex, pipIndex, mcpIndex) ->
            features += calculateFingerAngle(landmarks, tipIndex, pipIndex, mcpIndex)
        }

        val wrist = landmarks[0]
        val avgDepth = listOf(4, 8, 12, 16, 20)
            .sumOf { landmarks[it].z().toDouble() - wrist.z().toDouble() } / 5.0
        features += avgDepth

        val indexTip = landmarks[8]
        val pinkyTip = landmarks[20]
        val xDiff = indexTip.x().toDouble() - pinkyTip.x().toDouble()
        val yDiff = indexTip.y().toDouble() - pinkyTip.y().toDouble()
        features += sqrt(xDiff * xDiff + yDiff * yDiff)

        return features.toDoubleArray()
    }

    private fun calculateFingerAngle(
        landmarks: List<NormalizedLandmark>,
        tipIndex: Int,
        pipIndex: Int,
        mcpIndex: Int
    ): Double {
        val tip = landmarks[tipIndex]
        val pip = landmarks[pipIndex]
        val mcp = landmarks[mcpIndex]

        val v1 = doubleArrayOf(
            pip.x().toDouble() - mcp.x().toDouble(),
            pip.y().toDouble() - mcp.y().toDouble(),
            pip.z().toDouble() - mcp.z().toDouble()
        )
        val v2 = doubleArrayOf(
            tip.x().toDouble() - pip.x().toDouble(),
            tip.y().toDouble() - pip.y().toDouble(),
            tip.z().toDouble() - pip.z().toDouble()
        )

        val v1Norm = sqrt(v1.sumOf { it * it })
        val v2Norm = sqrt(v2.sumOf { it * it })
        if (v1Norm == 0.0 || v2Norm == 0.0) return 0.0

        val dot = v1.indices.sumOf { v1[it] * v2[it] }
        val cosine = (dot / (v1Norm * v2Norm)).coerceIn(-1.0, 1.0)
        return Math.toDegrees(acos(cosine))
    }

    private class NailVisibilityModel(
        private val threshold: Double,
        private val trees: List<Tree>
    ) {
        fun isNailVisible(features: DoubleArray): Boolean {
            if (trees.isEmpty()) return false
            return trees.sumOf { it.predict(features) } / trees.size > threshold
        }

        private class Tree(
            private val childrenLeft: IntArray,
            private val childrenRight: IntArray,
            private val feature: IntArray,
            private val threshold: DoubleArray,
            private val classOneValues: DoubleArray
        ) {
            fun predict(features: DoubleArray): Double {
                var node = 0
                while (childrenLeft[node] != -1 && childrenRight[node] != -1) {
                    node = if (features[feature[node]] <= threshold[node]) {
                        childrenLeft[node]
                    } else {
                        childrenRight[node]
                    }
                }
                return classOneValues[node]
            }
        }

        companion object {
            fun fromJson(json: JSONObject): NailVisibilityModel {
                val treesJson = json.getJSONArray("trees")
                val trees = List(treesJson.length()) { index ->
                    val treeJson = treesJson.getJSONObject(index)
                    Tree(
                        childrenLeft = treeJson.getJSONArray("children_left").toIntArray(),
                        childrenRight = treeJson.getJSONArray("children_right").toIntArray(),
                        feature = treeJson.getJSONArray("feature").toIntArray(),
                        threshold = treeJson.getJSONArray("threshold").toDoubleArray(),
                        classOneValues = treeJson.getJSONArray("value").toClassOneValueArray()
                    )
                }
                return NailVisibilityModel(
                    threshold = json.getDouble("threshold"),
                    trees = trees
                )
            }

            private fun JSONArray.toIntArray(): IntArray =
                IntArray(length()) { index -> getInt(index) }

            private fun JSONArray.toDoubleArray(): DoubleArray =
                DoubleArray(length()) { index -> getDouble(index) }

            private fun JSONArray.toClassOneValueArray(): DoubleArray =
                DoubleArray(length()) { index ->
                    getJSONArray(index).getJSONArray(0).getDouble(1)
                }
        }
    }

    override fun onError(error: String, errorCode: Int) {
        activity?.runOnUiThread {
            val context = context ?: return@runOnUiThread
            val binding = _fragmentCameraBinding ?: return@runOnUiThread

            Toast.makeText(context, error, Toast.LENGTH_SHORT).show()
        }
    }
}
