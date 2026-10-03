package com.google.mediapipe.examples.handlandmarker.fragment

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.LinearLayoutManager
import com.google.android.material.tabs.TabLayout
import com.google.mediapipe.examples.handlandmarker.R
import com.google.mediapipe.examples.handlandmarker.NailSetListViewModel
import com.google.mediapipe.examples.handlandmarker.databinding.FragmentNailSetListBinding
import kotlinx.coroutines.launch

class NailSetListFragment : Fragment() {
    private var _binding: FragmentNailSetListBinding? = null
    private val binding get() = _binding!!
    private val viewModel: NailSetListViewModel by viewModels()
    private val nailSetAdapter = NailSetAdapter { nailSet ->
        val args = Bundle().apply {
            putString(NailSetDetailFragment.ARG_NAIL_SET_ID, nailSet.id)
        }
        findNavController().navigate(R.id.action_nail_set_list_to_detail, args)
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentNailSetListBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding.nailSetTabs.addTab(binding.nailSetTabs.newTab().setText("Nail Sets"))
        binding.nailSetTabs.addTab(binding.nailSetTabs.newTab().setText("Nail Components"))
        binding.nailSetTabs.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab) {
                binding.comingSoonText.visibility = if (tab.position == 0) View.GONE else View.VISIBLE
                binding.nailSetRecycler.visibility = if (tab.position == 0) View.VISIBLE else View.GONE
            }

            override fun onTabUnselected(tab: TabLayout.Tab) = Unit

            override fun onTabReselected(tab: TabLayout.Tab) = Unit
        })

        binding.nailSetRecycler.layoutManager = LinearLayoutManager(requireContext())
        binding.nailSetRecycler.adapter = nailSetAdapter
        binding.refreshButton.setOnClickListener { viewModel.fetchNailSets() }

        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { state ->
                    binding.loadingProgress.visibility = if (state.isLoading) View.VISIBLE else View.GONE
                    binding.emptyText.visibility =
                        if (!state.isLoading && state.nailSets.isEmpty()) View.VISIBLE else View.GONE
                    nailSetAdapter.submitList(state.nailSets)

                    state.errorMessage?.let { message ->
                        Toast.makeText(requireContext(), message, Toast.LENGTH_LONG).show()
                        viewModel.clearError()
                    }
                }
            }
        }

        if (savedInstanceState == null) {
            viewModel.fetchNailSets()
        }
    }

    override fun onDestroyView() {
        binding.nailSetRecycler.adapter = null
        _binding = null
        super.onDestroyView()
    }
}
