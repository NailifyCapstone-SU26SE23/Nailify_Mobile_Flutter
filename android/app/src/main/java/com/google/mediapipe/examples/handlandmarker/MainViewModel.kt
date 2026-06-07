package com.google.mediapipe.examples.handlandmarker

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
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

}
