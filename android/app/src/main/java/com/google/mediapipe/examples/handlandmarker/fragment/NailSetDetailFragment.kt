package com.google.mediapipe.examples.handlandmarker.fragment

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.fragment.findNavController
import com.bumptech.glide.Glide
import com.google.gson.Gson
import com.google.gson.JsonSyntaxException
import com.google.mediapipe.examples.handlandmarker.MainViewModel
import com.google.mediapipe.examples.handlandmarker.NailSetDetailViewModel
import com.google.mediapipe.examples.handlandmarker.R
import com.google.mediapipe.examples.handlandmarker.data.repository.NailRepository
import com.google.mediapipe.examples.handlandmarker.databinding.FragmentNailSetDetailBinding
import com.google.mediapipe.examples.handlandmarker.model.FingerNailDesign
import com.google.mediapipe.examples.handlandmarker.model.GradientConfig
import com.google.mediapipe.examples.handlandmarker.model.NailSet
import com.google.mediapipe.examples.handlandmarker.model.NailSetConfig
import com.google.mediapipe.examples.handlandmarker.model.NailDecoration
import java.text.NumberFormat
import java.util.Locale
import kotlinx.coroutines.launch

class NailSetDetailFragment : Fragment() {
    private var _binding: FragmentNailSetDetailBinding? = null
    private val binding get() = _binding!!
    private val viewModel: NailSetDetailViewModel by viewModels()
    private val mainViewModel: MainViewModel by activityViewModels()
    private val gson = Gson()
    private lateinit var nailRepository: NailRepository

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentNailSetDetailBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        nailRepository = NailRepository.create(requireContext())

        binding.backButton.setOnClickListener { findNavController().navigateUp() }

        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { state ->
                    binding.detailProgress.visibility = if (state.isLoading) View.VISIBLE else View.GONE
                    state.nailSet?.let(::renderNailSet)

                    state.errorMessage?.let { message ->
                        Toast.makeText(requireContext(), message, Toast.LENGTH_LONG).show()
                        viewModel.clearError()
                    }
                }
            }
        }

        val nailSetId = requireArguments().getString(ARG_NAIL_SET_ID)
        if (savedInstanceState == null && nailSetId != null) {
            viewModel.fetchNailSet(nailSetId)
        }
    }

    private fun renderNailSet(nailSet: NailSet) {
        Glide.with(binding.detailImage)
            .load(nailSet.imageUrl)
            .placeholder(R.drawable.ic_baseline_photo_library_24)
            .error(R.drawable.ic_baseline_photo_library_24)
            .centerCrop()
            .into(binding.detailImage)

        binding.detailName.text = nailSet.name
        binding.detailStatus.text = if (nailSet.isActive) "Active" else "Inactive"
        binding.detailDescription.text = nailSet.description ?: "No description provided."
        binding.detailPrice.text = formatCurrency(nailSet.price)
        binding.detailItems.text = resources.getQuantityString(
            R.plurals.nail_set_item_count,
            nailSet.items.size,
            nailSet.items.size
        )
        binding.detailTags.text = resources.getQuantityString(
            R.plurals.nail_set_tag_count,
            nailSet.tags.size,
            nailSet.tags.size
        )
        binding.detailShape.text = nailSet.shape ?: "No default shape"
        binding.detailLength.text = nailSet.length?.toString() ?: "-"
        binding.detailMaterial.text = nailSet.material ?: "-"
        binding.detailGradient.text = if (nailSet.gradientEnabled) {
            listOfNotNull(nailSet.gradientType, nailSet.gradientStopCount?.let { "$it stops" }).joinToString(" / ")
        } else {
            "Disabled"
        }
        binding.detailCreatedAt.text = nailSet.createdAt
        binding.detailTagList.text = if (nailSet.tags.isEmpty()) "-" else nailSet.tags.joinToString(", ")
        binding.detailItemList.text = if (nailSet.items.isEmpty()) {
            "No components."
        } else {
            nailSet.items.joinToString("\n") { item ->
                "${item.position}. ${item.nailComponentName}"
            }
        }
        binding.arTryOnButton.setOnClickListener {
            openTryOn(nailSet, R.id.action_nail_set_detail_to_camera)
        }
        binding.imageTryOnButton.setOnClickListener {
            openTryOn(
                nailSet,
                R.id.action_nail_set_detail_to_gallery,
                Bundle().apply { putBoolean(GalleryFragment.ARG_AUTO_OPEN_PICKER, true) }
            )
        }
    }

    private fun openTryOn(nailSet: NailSet, actionId: Int, args: Bundle? = null) {
        viewLifecycleOwner.lifecycleScope.launch {
            val config = nailRepository.loadComponentsConfig(nailSet.id)
                ?: parseSavedConfig(nailSet)
                ?: buildDefaultConfigFromNailSet(nailSet)

            mainViewModel.applyNailSetConfig(config)
            findNavController().navigate(actionId, args)
        }
    }

    private fun parseSavedConfig(nailSet: NailSet): NailSetConfig? {
        val configJson = nailSet.tryOnConfigJson ?: return null
        return try {
            gson.fromJson(configJson, NailSetConfig::class.java)
        } catch (error: JsonSyntaxException) {
            null
        }
    }

    private fun buildDefaultConfigFromNailSet(nailSet: NailSet): NailSetConfig {
        val defaultGradient = GradientConfig(
            enabled = nailSet.gradientEnabled,
            type = nailSet.gradientType ?: GradientConfig.TYPE_LINEAR,
            stops = parseGradientStops(nailSet.gradientStopsJson),
            stopCount = nailSet.gradientStopCount ?: 2
        )
        val itemsByPosition = nailSet.items.associateBy { it.position }

        return NailSetConfig(
            shape = normalizeShape(nailSet.shape),
            length = nailSet.length?.toFloat() ?: 1.0f,
            material = normalizeMaterial(nailSet.material),
            gradient = defaultGradient,
            nails = List(NailSetConfig.FINGER_COUNT) { index ->
                val item = itemsByPosition[index] ?: itemsByPosition[index + 1]
                val itemGradient = if (item?.gradientEnabled == true) {
                    defaultGradient.copy(type = item.gradientType ?: defaultGradient.type)
                } else {
                    null
                }

                FingerNailDesign(
                    color = item?.colorHex ?: FingerNailDesign.DEFAULT_COLOR,
                    decorations = listOfNotNull(
                        item?.nailComponentImageUrl?.let { imageUrl ->
                            NailDecoration(
                                id = item.nailComponentId ?: "component_${item.id}",
                                type = when (item.componentType?.lowercase(Locale.US)) {
                                    NailDecoration.TYPE_GEM, "1" -> NailDecoration.TYPE_GEM
                                    else -> NailDecoration.TYPE_PATTERN
                                },
                                componentId = item.nailComponentId,
                                imageSrc = imageUrl,
                                scale = if (item.componentType?.lowercase(Locale.US) == NailDecoration.TYPE_GEM || item.componentType == "1") {
                                    NailDecoration.DEFAULT_GEM_SCALE
                                } else {
                                    NailDecoration.DEFAULT_PATTERN_SCALE
                                }
                            )
                        }
                    ),
                    customShapeSrc = item?.customShapeImageUrl,
                    gradient = itemGradient
                )
            }
        )
    }

    private fun parseGradientStops(stopsJson: String?): List<String> {
        if (stopsJson.isNullOrBlank()) return GradientConfig.DEFAULT_STOPS
        return try {
            val parsed = gson.fromJson(stopsJson, Array<String>::class.java).toList()
            if (parsed.size >= 2) parsed else GradientConfig.DEFAULT_STOPS
        } catch (_: Exception) {
            GradientConfig.DEFAULT_STOPS
        }
    }

    private fun normalizeShape(shape: String?): String {
        return when (shape) {
            NailSetConfig.SHAPE_BALLERINA,
            NailSetConfig.SHAPE_STILETTO,
            NailSetConfig.SHAPE_SQUOVAL -> shape
            "round", "almond" -> shape
            else -> NailSetConfig.SHAPE_BALLERINA
        }
    }

    private fun normalizeMaterial(material: String?): String {
        return when (material) {
            NailSetConfig.MATERIAL_METALLIC,
            NailSetConfig.MATERIAL_IRIDESCENT,
            NailSetConfig.MATERIAL_MATTE -> material
            else -> NailSetConfig.MATERIAL_STANDARD
        }
    }

    private fun formatCurrency(value: Double): String {
        return NumberFormat.getCurrencyInstance(Locale.US).format(value)
    }

    override fun onDestroyView() {
        _binding = null
        super.onDestroyView()
    }

    companion object {
        const val ARG_NAIL_SET_ID = "nailSetId"
    }
}
