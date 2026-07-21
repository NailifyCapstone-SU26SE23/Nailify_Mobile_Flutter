package com.google.mediapipe.examples.handlandmarker.fragment

import android.net.Uri
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.activity.result.contract.ActivityResultContracts
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import androidx.navigation.fragment.findNavController
import com.google.mediapipe.examples.handlandmarker.MainViewModel
import com.google.mediapipe.examples.handlandmarker.R
import com.google.mediapipe.examples.handlandmarker.databinding.FragmentDesignPreviewBinding

class DesignPreviewFragment : Fragment() {

    private var _binding: FragmentDesignPreviewBinding? = null
    private val binding get() = _binding!!
    private val viewModel: MainViewModel by activityViewModels()
    private var selectedUri: Uri? = null

    private val pickImageLauncher = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let {
            selectedUri = it
            binding.imgPreview.setImageURI(it)
            binding.btnTryOnAR.visibility = View.VISIBLE
            binding.btnTryOnImage.visibility = View.VISIBLE
        }
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentDesignPreviewBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding.btnPickImage.setOnClickListener {
            pickImageLauncher.launch("image/*")
        }

        binding.btnTryOnAR.setOnClickListener {
            selectedUri?.let {
                // Set the custom shape in the ViewModel while preserving other elements
                viewModel.setNailDesign(
                    shape = "custom",
                    color = viewModel.selectedColor,
                    pattern = viewModel.selectedPattern,
                    surface = viewModel.selectedSurface,
                    gem = viewModel.selectedGem,
                    length = viewModel.selectedLength,
                    customShape = it.toString()
                )
                findNavController().navigate(R.id.action_preview_to_camera)
            }
        }

        binding.btnTryOnImage.setOnClickListener {
            selectedUri?.let {
                viewModel.setNailDesign(
                    shape = "custom",
                    color = viewModel.selectedColor,
                    pattern = viewModel.selectedPattern,
                    surface = viewModel.selectedSurface,
                    gem = viewModel.selectedGem,
                    length = viewModel.selectedLength,
                    customShape = it.toString()
                )
                findNavController().navigate(R.id.action_preview_to_gallery)
            }
        }

        binding.btnBack.setOnClickListener {
            findNavController().navigateUp()
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
