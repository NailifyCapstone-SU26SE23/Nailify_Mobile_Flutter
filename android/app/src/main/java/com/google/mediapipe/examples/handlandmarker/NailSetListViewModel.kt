package com.google.mediapipe.examples.handlandmarker

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.google.mediapipe.examples.handlandmarker.data.repository.NailRepository
import com.google.mediapipe.examples.handlandmarker.model.NailSet
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class NailSetListUiState(
    val nailSets: List<NailSet> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null
)

class NailSetListViewModel(application: Application) : AndroidViewModel(application) {
    private val nailRepository = NailRepository.create(application)

    private val _uiState = MutableStateFlow(NailSetListUiState())
    val uiState: StateFlow<NailSetListUiState> = _uiState.asStateFlow()

    fun fetchNailSets() {
        _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val nailSets = nailRepository.getNailSets()
                _uiState.value = NailSetListUiState(nailSets = nailSets)
            } catch (error: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = error.message ?: "Unable to load nail sets."
                )
            }
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }
}
