package com.google.mediapipe.examples.handlandmarker.fragment

import android.graphics.Color
import android.graphics.PorterDuff
import android.net.Uri
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.activity.result.contract.ActivityResultContracts
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.fragment.findNavController
import com.google.mediapipe.examples.handlandmarker.MainViewModel
import com.google.mediapipe.examples.handlandmarker.R
import com.google.mediapipe.examples.handlandmarker.databinding.FragmentNailBuilderBinding
import com.google.mediapipe.examples.handlandmarker.model.NailDecoration
import com.google.mediapipe.examples.handlandmarker.model.NailSetConfig
import kotlinx.coroutines.launch

class NailBuilderFragment : Fragment() {

    private var _binding: FragmentNailBuilderBinding? = null
    private val binding get() = _binding!!
    private val viewModel: MainViewModel by activityViewModels()

    private var currentShape = "ballerina"
    private var currentColor = "#FF4081"
    private var currentLength = 1.3f // Default to Medium
    private var patternUri: String? = null
    private var surfaceUri: String? = null
    private var gemUri: String? = null
    private var allFingersMode = true
    private var isSyncingFromState = false
    private var nailSetId = DEFAULT_NAIL_SET_ID

    private val pickPatternLauncher = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let {
            patternUri = it.toString()
            updateCurrentDecoration(NailDecoration.TYPE_PATTERN, patternUri)
        }
    }
    private val pickSurfaceLauncher = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let {
            surfaceUri = it.toString()
            updateDesignState()
        }
    }
    private val pickGemLauncher = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let {
            gemUri = it.toString()
            updateCurrentDecoration(NailDecoration.TYPE_GEM, gemUri)
        }
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentNailBuilderBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        nailSetId = arguments?.getInt(ARG_NAIL_SET_ID) ?: DEFAULT_NAIL_SET_ID

        // Initialize state from ViewModel if available
        currentShape = viewModel.selectedShape
        currentColor = viewModel.selectedColor
        currentLength = viewModel.selectedLength
        patternUri = viewModel.selectedPattern
        surfaceUri = viewModel.selectedSurface
        gemUri = viewModel.selectedGem

        setupSelectors()
        setupFingerChips()
        observeNailSetConfig()

        // Set initial checked state for length group
        binding.lengthGroup.check(when (currentLength) {
            1.0f -> R.id.lengthShort
            1.5f -> R.id.lengthLong
            else -> R.id.lengthMedium
        })

        updatePreview()

        binding.btnArTryOn.setOnClickListener {
            saveDesignToViewModel()
            findNavController().navigate(R.id.action_builder_to_camera)
        }

        binding.btnImageTryOn.setOnClickListener {
            saveDesignToViewModel()
            findNavController().navigate(R.id.action_builder_to_gallery)
        }

        binding.btnUploadNailImage.setOnClickListener {
            findNavController().navigate(R.id.action_builder_to_preview)
        }

        binding.btnSaveDesign.setOnClickListener {
            saveDesignToViewModel()
            viewModel.saveToApi(nailSetId)
        }
    }

    private fun saveDesignToViewModel() {
        viewModel.setNailDesign(
            shape = currentShape,
            color = currentColor,
            pattern = patternUri, 
            surface = surfaceUri, 
            gem = gemUri,
            length = currentLength
        )
    }

    private fun setupSelectors() {
        // Shapes
        binding.shapeBallerina.setOnClickListener {
            currentShape = NailSetConfig.SHAPE_BALLERINA
            updateDesignState()
        }
        binding.shapeSquoval.setOnClickListener {
            currentShape = NailSetConfig.SHAPE_SQUOVAL
            updateDesignState()
        }
        binding.shapeStiletto.setOnClickListener {
            currentShape = NailSetConfig.SHAPE_STILETTO
            updateDesignState()
        }

        // Lengths
        binding.lengthGroup.setOnCheckedChangeListener { _, checkedId ->
            if (isSyncingFromState) return@setOnCheckedChangeListener
            currentLength = when (checkedId) {
                R.id.lengthShort -> 1.0f
                R.id.lengthMedium -> 1.3f
                R.id.lengthLong -> 1.5f
                else -> 1.3f
            }
            updateDesignState()
        }

        // Colors
        binding.colorRed.setOnClickListener { updateColor("#FF0000") }
        binding.colorBlue.setOnClickListener { updateColor("#0000FF") }
        binding.colorNude.setOnClickListener { updateColor("#F5CBA7") }
        binding.colorPink.setOnClickListener { updateColor("#FF4081") }

        // Uploads
        binding.btnUploadPattern.setOnClickListener { pickPatternLauncher.launch("image/*") }
        binding.btnUploadSurface.setOnClickListener { pickSurfaceLauncher.launch("image/*") }
        binding.btnUploadGem.setOnClickListener { pickGemLauncher.launch("image/*") }
    }

    private fun setupFingerChips() {
        binding.fingerChipGroup.setOnCheckedStateChangeListener { _, checkedIds ->
            when (checkedIds.firstOrNull()) {
                R.id.chipAllFingers, null -> {
                    allFingersMode = true
                    viewModel.selectFinger(0)
                }
                R.id.chipThumb -> selectSingleFinger(0)
                R.id.chipIndex -> selectSingleFinger(1)
                R.id.chipMiddle -> selectSingleFinger(2)
                R.id.chipRing -> selectSingleFinger(3)
                R.id.chipPinky -> selectSingleFinger(4)
            }
            updateControlVisibility()
            syncLocalStateFromConfig(viewModel.nailSetConfig.value)
        }
    }

    private fun selectSingleFinger(index: Int) {
        allFingersMode = false
        viewModel.selectFinger(index)
    }

    private fun observeNailSetConfig() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.nailSetConfig.collect { config ->
                    syncLocalStateFromConfig(config)
                }
            }
        }
    }

    private fun syncLocalStateFromConfig(config: NailSetConfig) {
        val fingerDesign = config.nails.getOrNull(viewModel.selectedFingerIndex.value)
            ?: config.nails.firstOrNull()
        currentShape = config.shape
        currentColor = fingerDesign?.color ?: currentColor
        currentLength = config.length
        surfaceUri = config.material.takeIf { it != NailSetConfig.MATERIAL_STANDARD }
        patternUri = fingerDesign?.decorations
            ?.firstOrNull { it.type == NailDecoration.TYPE_PATTERN }
            ?.imageSrc
        gemUri = fingerDesign?.decorations
            ?.firstOrNull { it.type == NailDecoration.TYPE_GEM }
            ?.imageSrc

        isSyncingFromState = true
        binding.lengthGroup.check(when (currentLength) {
            1.0f -> R.id.lengthShort
            1.5f -> R.id.lengthLong
            else -> R.id.lengthMedium
        })
        isSyncingFromState = false
        updateControlVisibility()
        updatePreview()
    }

    private fun updateControlVisibility() {
        binding.globalControls.visibility = if (allFingersMode) View.VISIBLE else View.GONE
        binding.fingerControls.visibility = if (allFingersMode) View.GONE else View.VISIBLE
    }

    private fun updateColor(color: String) {
        currentColor = color
        viewModel.updateCurrentFingerColor(color)
        if (allFingersMode) {
            viewModel.applyToAllFingers()
        }
        updatePreview()
    }

    private fun updateCurrentDecoration(type: String, imageUri: String?) {
        val uri = imageUri ?: return
        viewModel.updateCurrentFingerDecoration(
            NailDecoration(
                id = "${type}_${System.currentTimeMillis()}",
                type = type,
                imageSrc = uri,
                scale = if (type == NailDecoration.TYPE_GEM) {
                    NailDecoration.DEFAULT_GEM_SCALE
                } else {
                    NailDecoration.DEFAULT_PATTERN_SCALE
                }
            )
        )
        if (allFingersMode) {
            viewModel.applyToAllFingers()
        }
        updatePreview()
    }

    private fun updateDesignState() {
        if (isSyncingFromState) return
        saveDesignToViewModel()
        if (allFingersMode) {
            viewModel.applyToAllFingers()
        }
        updatePreview()
    }

    private fun updatePreview() {
        // Update Shape & Color
        val shapeRes = when (currentShape) {
            "squoval" -> R.drawable.squoval
            "stiletto" -> R.drawable.stiletto
            else -> R.drawable.ballerina
        }
        binding.previewShape.setImageResource(shapeRes)
        binding.previewShape.setColorFilter(Color.parseColor(currentColor), PorterDuff.Mode.SRC_IN)
        binding.previewShape.scaleY = currentLength // Scale height based on length

        // Update Extras Visibility and Image with Scaling
        binding.previewPattern.visibility = if (patternUri != null) View.VISIBLE else View.GONE
        binding.previewPattern.scaleX = 0.35f
        binding.previewPattern.scaleY = 0.35f
        patternUri?.let { binding.previewPattern.setImageURI(Uri.parse(it)) }

        binding.previewSurface.visibility = if (surfaceUri != null) View.VISIBLE else View.GONE
        surfaceUri?.let { binding.previewSurface.setImageURI(Uri.parse(it)) }

        binding.previewGem.visibility = if (gemUri != null) View.VISIBLE else View.GONE
        binding.previewGem.scaleX = 0.2f
        binding.previewGem.scaleY = 0.2f
        gemUri?.let { binding.previewGem.setImageURI(Uri.parse(it)) }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }

    private companion object {
        const val ARG_NAIL_SET_ID = "nailSetId"
        const val DEFAULT_NAIL_SET_ID = 1
    }
}
