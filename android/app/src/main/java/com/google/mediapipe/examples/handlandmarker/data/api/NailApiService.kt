package com.google.mediapipe.examples.handlandmarker.data.api

import com.google.mediapipe.examples.handlandmarker.model.NailSetConfig
import com.google.mediapipe.examples.handlandmarker.model.NailSet
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

interface NailApiService {
    @GET("/api/nailsets")
    suspend fun getNailSets(): ApiResponse<List<NailSet>>

    @GET("/api/nailsets/{id}")
    suspend fun getNailSet(@Path("id") id: String): ApiResponse<NailSet>

    @GET("/api/nailsets/{id}/components")
    suspend fun loadSettings(@Path("id") id: Int): NailSetConfig

    @GET("/api/nailsets/{id}/components")
    suspend fun getNailSetComponents(@Path("id") id: String): ApiResponse<NailSetConfig?>

    @POST("/api/nailsets/{id}/components")
    suspend fun saveSettings(
        @Path("id") id: Int,
        @Body config: NailSetConfig
    )
}
