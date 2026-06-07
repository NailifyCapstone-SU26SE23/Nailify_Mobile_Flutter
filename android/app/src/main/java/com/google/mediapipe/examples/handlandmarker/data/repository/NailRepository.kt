package com.google.mediapipe.examples.handlandmarker.data.repository

import android.content.Context
import com.google.gson.Gson
import com.google.mediapipe.examples.handlandmarker.data.api.NailApiService
import com.google.mediapipe.examples.handlandmarker.data.local.NailConfigDatabaseHelper
import com.google.mediapipe.examples.handlandmarker.model.NailSet
import com.google.mediapipe.examples.handlandmarker.model.NailSetConfig
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory

class NailRepository(
    private val apiService: NailApiService,
    private val localStore: NailConfigDatabaseHelper
) {
    suspend fun getNailSets(): List<NailSet> =
        apiService.getNailSets().data ?: error("Nail sets response did not include data.")

    suspend fun getNailSet(id: String): NailSet =
        apiService.getNailSet(id).data ?: error("Nail set response did not include data.")

    suspend fun loadComponentsConfig(nailSetId: String): NailSetConfig? {
        return try {
            apiService.getNailSetComponents(nailSetId).data
        } catch (_: Exception) {
            null
        }
    }

    suspend fun loadConfig(id: Int): NailSetConfig {
        return try {
            apiService.loadSettings(id).also { config ->
                localStore.saveConfig(id, config)
            }
        } catch (apiError: Exception) {
            localStore.loadConfig(id) ?: throw apiError
        }
    }

    suspend fun saveConfig(id: Int, config: NailSetConfig) {
        try {
            apiService.saveSettings(id, config)
        } finally {
            localStore.saveConfig(id, config)
        }
    }

    companion object {
        private const val DEFAULT_BASE_URL = "http://10.0.2.2:5299/"

        fun create(
            context: Context,
            baseUrl: String = DEFAULT_BASE_URL,
            gson: Gson = Gson()
        ): NailRepository {
            val apiService = Retrofit.Builder()
                .baseUrl(baseUrl)
                .addConverterFactory(GsonConverterFactory.create(gson))
                .build()
                .create(NailApiService::class.java)

            return NailRepository(
                apiService = apiService,
                localStore = NailConfigDatabaseHelper(context.applicationContext, gson)
            )
        }
    }
}
