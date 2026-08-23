package com.google.mediapipe.examples.handlandmarker

import android.app.Application
import android.graphics.PointF
import kotlin.math.sqrt
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.google.mediapipe.examples.handlandmarker.ai.FINGER_CLASS_NAMES
import com.google.mediapipe.examples.handlandmarker.ai.NailAiEngine
import com.google.mediapipe.examples.handlandmarker.ai.NailDetection
import com.google.mediapipe.examples.handlandmarker.ai.NailDesignLoader
import com.google.mediapipe.examples.handlandmarker.ai.NailGeometryEngine
import com.google.mediapipe.examples.handlandmarker.ai.NailOverlayEngine
import com.google.mediapipe.examples.handlandmarker.ai.LoadedDesign
import com.google.mediapipe.examples.handlandmarker.ai.PolygonTracker
import com.google.mediapipe.examples.handlandmarker.data.repository.NailRepository
import com.google.mediapipe.examples.handlandmarker.model.FingerNailDesign
import com.google.mediapipe.examples.handlandmarker.model.NailDecoration
import com.google.mediapipe.examples.handlandmarker.model.NailSetConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class MainViewModel(application: Application) : AndroidViewModel(application) {

    private var _delegate: Int = HandLandmarkerHelper.DELEGATE_CPU
    private var _minHandDetectionConfidence: Float =
        HandLandmarkerHelper.DEFAULT_HAND_DETECTION_CONFIDENCE
    private var _minHandTrackingConfidence: Float = HandLandmarkerHelper
        .DEFAULT_HAND_TRACKING_CONFIDENCE
    private var _minHandPresenceConfidence: Float = HandLandmarkerHelper
        .DEFAULT_HAND_PRESENCE_CONFIDENCE
    private var _maxHands: Int = HandLandmarkerHelper.DEFAULT_NUM_HANDS

    val currentDelegate: Int get() = _delegate
    val currentMinHandDetectionConfidence: Float
        get() =
            _minHandDetectionConfidence
    val currentMinHandTrackingConfidence: Float
        get() =
            _minHandTrackingConfidence
    val currentMinHandPresenceConfidence: Float
        get() =
            _minHandPresenceConfidence
    val currentMaxHands: Int get() = _maxHands

    fun setDelegate(delegate: Int) {
        _delegate = delegate
    }

    fun setMinHandDetectionConfidence(confidence: Float) {
        _minHandDetectionConfidence = confidence
    }
    fun setMinHandTrackingConfidence(confidence: Float) {
        _minHandTrackingConfidence = confidence
    }
    fun setMinHandPresenceConfidence(confidence: Float) {
        _minHandPresenceConfidence = confidence
    }

    fun setMaxHands(maxResults: Int) {
        _maxHands = maxResults
    }

    private val nailRepository = NailRepository.create(application)

    // Nail Design State
    private val _nailSetConfig = MutableStateFlow(NailSetConfig.default())
    val nailSetConfig: StateFlow<NailSetConfig> = _nailSetConfig.asStateFlow()

    // Manual overlay offsets — giá trị bù trừ thủ công từ Flutter D-Pad.
    data class ManualOffsetConfig(
        val offsetX: Float = 0f,
        val offsetY: Float = 0f,
        val scale: Float = 1f,
        val rotation: Float = 0f
    )
    private val _manualOffset = MutableStateFlow(ManualOffsetConfig())
    val manualOffset: StateFlow<ManualOffsetConfig> = _manualOffset.asStateFlow()

    /** Gọi bởi MainActivity khi Flutter gửi config mới qua intent / MethodChannel. */
    fun updateManualOffsets(offsetX: Float, offsetY: Float, scale: Float, rotation: Float) {
        _manualOffset.value = ManualOffsetConfig(offsetX, offsetY, scale, rotation)
    }

    private val _selectedFingerIndex = MutableStateFlow(0)
    val selectedFingerIndex: StateFlow<Int> = _selectedFingerIndex.asStateFlow()

    val selectedShape: String get() = _nailSetConfig.value.shape
    val selectedColor: String get() = currentFinger().color
    val selectedPattern: String?
        get() = currentFinger().decorations.firstOrNull {
            it.type == NailDecoration.TYPE_PATTERN
        }?.imageSrc
    val selectedSurface: String? get() = _nailSetConfig.value.material
    val selectedGem: String?
        get() = currentFinger().decorations.firstOrNull {
            it.type == NailDecoration.TYPE_GEM
        }?.imageSrc
    val selectedLength: Float get() = _nailSetConfig.value.length
    val customShapeUri: String? get() = currentFinger().customShapeSrc

    fun selectFinger(index: Int) {
        _selectedFingerIndex.value = index.coerceIn(0, NailSetConfig.FINGER_COUNT - 1)
    }

    fun updateCurrentFingerColor(color: String) {
        updateCurrentFinger { it.copy(color = color) }
    }

    fun updateCurrentFingerDecoration(decoration: NailDecoration) {
        updateCurrentFinger { current ->
            current.copy(decorations = current.decorations + decoration)
        }
    }

    fun applyToAllFingers() {
        val selectedDesign = currentFinger()
        _nailSetConfig.value = _nailSetConfig.value.copy(
            nails = List(NailSetConfig.FINGER_COUNT) { selectedDesign }
        )
    }

    fun saveToApi(nailSetId: Int) {
        viewModelScope.launch(Dispatchers.IO) {
            nailRepository.saveConfig(nailSetId, _nailSetConfig.value)
        }
    }

    fun loadFromRepository(nailSetId: Int) {
        viewModelScope.launch(Dispatchers.IO) {
            _nailSetConfig.value = nailRepository.loadConfig(nailSetId)
        }
    }

    fun applyNailSetConfig(config: NailSetConfig) {
        _nailSetConfig.value = config
        _selectedFingerIndex.value = 0
    }

    fun setNailDesign(
        shape: String,
        color: String,
        pattern: String? = null,
        surface: String? = null,
        gem: String? = null,
        length: Float = 1.0f,
        customShape: String? = null
    ) {
        val decorations = listOfNotNull(
            pattern?.let {
                NailDecoration(
                    id = "pattern",
                    type = NailDecoration.TYPE_PATTERN,
                    imageSrc = it,
                    scale = NailDecoration.DEFAULT_PATTERN_SCALE
                )
            },
            gem?.let {
                NailDecoration(
                    id = "gem",
                    type = NailDecoration.TYPE_GEM,
                    imageSrc = it,
                    scale = NailDecoration.DEFAULT_GEM_SCALE
                )
            }
        )
        val currentNails = _nailSetConfig.value.nails
        val selectedIndex = _selectedFingerIndex.value
        val updatedNails = currentNails.mapIndexed { index, existingDesign ->
            if (index == selectedIndex) {
                FingerNailDesign(
                    color = color,
                    decorations = decorations,
                    customShapeSrc = customShape,
                    gradient = existingDesign.gradient
                )
            } else {
                existingDesign
            }
        }
        _nailSetConfig.value = _nailSetConfig.value.copy(
            shape = shape,
            length = length,
            material = surface ?: NailSetConfig.MATERIAL_STANDARD,
            nails = updatedNails
        )
    }

    private fun currentFinger(): FingerNailDesign {
        return _nailSetConfig.value.nails.getOrElse(_selectedFingerIndex.value) {
            FingerNailDesign()
        }
    }

    private fun updateCurrentFinger(transform: (FingerNailDesign) -> FingerNailDesign) {
        val selectedIndex = _selectedFingerIndex.value
        val updatedNails = _nailSetConfig.value.nails.mapIndexed { index, design ->
            if (index == selectedIndex) transform(design) else design
        }
        _nailSetConfig.value = _nailSetConfig.value.copy(nails = updatedNails)
    }

    // -------------------------------------------------------------------------
    // YOLO-Seg + Geometry + Overlay engines
    // -------------------------------------------------------------------------

    /**
     * ONNX YOLO-Seg 5-class nail detector. Loaded lazily from
     * `assets/nail_seg_5class.onnx`. Lifecycle: created once on first access;
     * `close()` should be called from `onCleared()` (AndroidViewModel handles
     * that automatically).
     */
    val nailAiEngine: NailAiEngine by lazy {
        NailAiEngine(
            context = application,
            perClassThresholds = PER_CLASS_CONF_THRESHOLD,
        )
    }

    /** Pure-math geometry helpers (PCA + nail bed slice). */
    val nailGeometryEngine: NailGeometryEngine = NailGeometryEngine

    /** Homography overlay renderer. */
    val nailOverlayEngine: NailOverlayEngine = NailOverlayEngine

    /**
     * Temporal smoothing tracker (EMA + hysteresis + cls_id-aware matching).
     * Mirrors nail_desktop_app/smoothing.py PolygonTracker. Created once on
     * first access; call [resetPolygonTracker] when changing camera/scene.
     */
    val polygonTracker: PolygonTracker by lazy {
        PolygonTracker(
            alpha = SMOOTHING_ALPHA,
            distThreshold = SMOOTHING_DIST_THRESHOLD,
            minConfirmFrames = 1,
            hysteresisFrames = SMOOTHING_HYSTERESIS_FRAMES,
            reattachDistMultiplier = 1.5f,
        )
    }

    /** Reset the tracker. Call from CameraFragment.onPause() / onSceneChange. */
    fun resetPolygonTracker() {
        polygonTracker.reset()
    }

    // Latest YOLO-Seg detection results (image-space polygons).
    var currentDetections: List<NailDetection> = emptyList()

    // Latest per-finger forward unit vectors from MediaPipe (clsId -> PointF).
    var currentFingerVectors: Map<Int, PointF> = emptyMap()

    // Cached design PNG (loaded on demand).
    @Volatile var currentDesign: LoadedDesign? = null

    /** Path (relative to `assets/`) or URL of the design PNG currently in use. */
    @Volatile var currentDesignPath: String? = null

    /**
     * Per-finger design cache. Key = asset path or URL,
     * value = loaded design. Cleared automatically when assets change.
     */
    private val designCache = java.util.concurrent.ConcurrentHashMap<String, LoadedDesign>()

    /** Snapshot of all currently loaded designs (used by NailOverlayEngine). */
    val currentDesigns: Map<String, LoadedDesign> get() = designCache.toMap()

    /**
     * Load a design from assets if not already cached. Safe to call repeatedly.
     * Supports both local asset paths and remote URLs (http/https).
     */
    fun ensureDesignLoaded(assetPath: String): LoadedDesign? {
        designCache[assetPath]?.let { return it }
        val app = getApplication<Application>()
        val loaded = NailDesignLoader.loadDesign(
            app,
            assetPath,
            cacheDir = app.cacheDir,
        )
        if (loaded != null) {
            designCache[assetPath] = loaded
            currentDesign = loaded
            currentDesignPath = assetPath
        }
        return loaded
    }

    /**
     * Resolve the design asset path for a given finger slot. Priority:
     *   1. `customShapeSrc` on the finger design (per-finger image override)
     *   2. `shapeImageSrc` on the global shape config (fallback shape asset)
     *   3. null (caller falls back to default).
     */
    private fun resolveDesignAsset(
        config: NailSetConfig,
        fingerIndex: Int,
    ): String? {
        if (fingerIndex in 0 until config.nails.size) {
            val finger = config.nails[fingerIndex]
            finger.customShapeSrc?.takeIf { it.isNotBlank() }?.let { return it }
        }
        return config.shapeImageSrc?.takeIf { it.isNotBlank() }
    }

    /**
     * Process the raw YOLO-Seg detections into nail-bed-clipped NailDetections
     * (matching the desktop `_render_seg_5class_overlay` path). Updates
     * [currentDetections] in place and returns the updated list.
     *
     * Each detection is matched to a finger through YOLO class id →
     * FingerNailDesign lookup, with MediaPipe TIP-position proximity as a
     * fallback when class ids are ambiguous. The corresponding design asset
     * path is attached so the overlay engine can render the right PNG per nail.
     *
     * @param rawDetections   Output of [NailAiEngine.run].
     * @param fingerVectors   Per-finger MediaPipe forward vectors.
     * @param tipPositions    Per-finger MediaPipe TIP positions in image pixels.
     * @param config          Active [NailSetConfig] from Flutter.
     */
    fun processDetections(
        rawDetections: List<NailDetection>,
        fingerVectors: Map<Int, PointF>,
        tipPositions: Map<Int, PointF> = emptyMap(),
        config: NailSetConfig = nailSetConfig.value,
    ): List<NailDetection> {
        // Derive frame dimensions from tipPositions to scale MediaPipe vectors to pixel space.
        // MediaPipe landmarks are in [0,1] normalized coords; polygon points are in pixels.
        // Without this scaling, NailOverlayEngine projection math produces near-zero values.
        // Guard against empty map (no landmarks at all → use safe defaults).
        val frameW = tipPositions.values.maxOfOrNull { it.x }?.coerceAtLeast(1f) ?: 640f
        val frameH = tipPositions.values.maxOfOrNull { it.y }?.coerceAtLeast(1f) ?: 480f
        val frameDiagonal = sqrt(frameW * frameW + frameH * frameH).coerceAtLeast(1f)

        val processed = rawDetections.map { det ->
            val rawHint = fingerVectors[det.clsId]
            // Scale [0,1] unit vector to pixel-space unit vector (same direction, pixel-scale magnitude).
            val scaledHint = rawHint?.let {
                PointF(it.x * frameDiagonal, it.y * frameDiagonal)
            }
            // PCA direction is the spatial anchor (from YOLO polygon).
            // scaledHint (MediaPipe) is passed as a 180° disambiguation hint only;
            // it must never override the polygon-derived direction.
            val direction = nailGeometryEngine.getDirectionFromPolygonPca(det.polygon, scaledHint, det.clsId)
            val nailBed = nailGeometryEngine.cutPolygonAtRatio(det.polygon, direction, 0.75f)

            // Match this detection to a finger: prefer YOLO clsId, fall back
            // to nearest MediaPipe TIP position by centroid proximity.
            val fingerName = clsIdToFingerName(det.clsId)
            val matchedFingerIdx = det.clsId.coerceIn(0, NailSetConfig.FINGER_COUNT - 1)
            val designAsset = resolveDesignAsset(config, matchedFingerIdx)

            // forwardVector  = MediaPipe rotation hint (used by overlay to flip
            //                   PCA 180° ambiguity, if needed)
            // pcaDirection   = Spatial anchor from polygon (the overlay never
            //                   moves this)
            det.copy(
                forwardVector = scaledHint ?: det.forwardVector,
                pcaDirection = direction,
                nailBedPolygon = if (nailBed.size >= 3) nailBed else det.polygon,
                fingerName = fingerName,
                designAssetPath = designAsset,
            )
        }
        // Temporal smoothing (EMA + hysteresis + cls_id-aware matching).
        // The tracker mutates each detection in-place (polygon, confidence,
        // trackId) and returns the subset that has been confirmed (either
        // via the debounce window or via hysteresis re-attach).
        val confirmed = polygonTracker.update(processed)

        currentDetections = confirmed
        currentFingerVectors = fingerVectors
        return confirmed
    }

    /**
     * Map YOLO class id to a finger name. Mirrors the dataset label order
     * (index/middle/pinky/ring/thumb) used by `FINGER_CLASS_NAMES`.
     */
    private fun clsIdToFingerName(clsId: Int): String =
        FINGER_CLASS_NAMES.getOrElse(clsId) { "" }

    override fun onCleared() {
        try { nailAiEngine.close() } catch (_: Exception) {}
        super.onCleared()
    }

    companion object {
        // ---- Per-class confidence thresholds (mirrors config.py) ----
        // Each finger has its own recall profile at oblique angles — using
        // a single 0.25 threshold drops too many thumbs/pinkies during
        // rotation. Tightening the less-confident fingers slightly while
        // keeping thumb/index aggressive matches the desktop behaviour.
        val PER_CLASS_CONF_THRESHOLD: Map<String, Float> = mapOf(
            "thumb" to 0.40f,
            "index" to 0.35f,
            "middle" to 0.30f,
            "ring" to 0.35f,
            "pinky" to 0.40f,
        )

        // ---- PolygonTracker tuning (mirrors config.SMOOTHING_*) ----
        const val SMOOTHING_ALPHA: Float = 0.5f
        const val SMOOTHING_DIST_THRESHOLD: Float = 150f
        const val SMOOTHING_HYSTERESIS_FRAMES: Int = 8

        // ---- NailAiEngine geometric filter (mirrors config.MIN_/MAX_BBOX_*) ----
        const val MIN_BBOX_W: Float = 20f
        const val MAX_BBOX_W: Float = 100f
        const val MIN_BBOX_H: Float = 9f
        const val MAX_BBOX_H: Float = 60f
        const val MAX_ASPECT_RATIO: Float = 5.0f
    }
}
