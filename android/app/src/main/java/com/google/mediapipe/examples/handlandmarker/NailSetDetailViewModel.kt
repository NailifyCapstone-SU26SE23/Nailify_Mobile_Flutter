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

data class NailSetDetailUiState(
    val nailSet: NailSet? = null,
    val isLoading: Boolean = false,
    val errorMessage: String? = null
)

class NailSetDetailViewModel(application: Application) : AndroidViewModel(application) {
    private val nailRepository = NailRepository.create(application)

    private val _uiState = MutableStateFlow(NailSetDetailUiState())
    val uiState: StateFlow<NailSetDetailUiState> = _uiState.asStateFlow()

    fun fetchNailSet(id: String) {
        _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)

        viewModelScope.launch(Dispatchers.IO) {
            try {
                _uiState.value = NailSetDetailUiState(nailSet = nailRepository.getNailSet(id))
            } catch (error: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = error.message ?: "Unable to load nail set details."
                )
            }
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }
}
