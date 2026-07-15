/*
 * Copyright 2022 The TensorFlow Authors. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *             http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.google.mediapipe.examples.handlandmarker

import android.os.Bundle
import androidx.activity.viewModels
import androidx.appcompat.app.AppCompatActivity
import androidx.navigation.fragment.NavHostFragment
import com.google.gson.Gson
import com.google.gson.JsonSyntaxException
import com.google.mediapipe.examples.handlandmarker.databinding.ActivityMainBinding
import com.google.mediapipe.examples.handlandmarker.fragment.GalleryFragment
import com.google.mediapipe.examples.handlandmarker.model.NailSetConfig

class MainActivity : AppCompatActivity() {
    private lateinit var activityMainBinding: ActivityMainBinding
    private val viewModel : MainViewModel by viewModels()
    private val gson = Gson()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        activityMainBinding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(activityMainBinding.root)

        intent.getStringExtra("nail_set_config_json")
            ?.takeIf { it.isNotBlank() }
            ?.let(::applyNailSetConfig)

        if (savedInstanceState == null && intent.hasExtra("try_on_entry")) {
            openRequestedTryOn()
        }
    }

    private fun applyNailSetConfig(configJson: String) {
        try {
            val config = gson.fromJson(configJson, NailSetConfig::class.java)
            viewModel.applyNailSetConfig(config)

            // Parse manual offsets ngoài NailSetConfig (Flutter gửi kèm trong cùng payload).
            // Dùng JSONObject để tránh phụ thuộc vào data class chính.
            val json = org.json.JSONObject(configJson)
            viewModel.updateManualOffsets(
                offsetX  = json.optDouble("manualOffsetX",  0.0).toFloat(),
                offsetY  = json.optDouble("manualOffsetY",  0.0).toFloat(),
                scale    = json.optDouble("manualScale",    1.0).toFloat(),
                rotation = json.optDouble("manualRotation", 0.0).toFloat()
            )
        } catch (_: JsonSyntaxException) {
            viewModel.applyNailSetConfig(NailSetConfig.default())
        }
    }

    private fun openRequestedTryOn() {
        val navHost = supportFragmentManager
            .findFragmentById(R.id.fragment_container) as? NavHostFragment
            ?: return
        val navController = navHost.navController
        when (intent.getStringExtra("try_on_entry")) {
            "photo" -> {
                val args = Bundle().apply {
                    putBoolean(
                        GalleryFragment.ARG_AUTO_OPEN_PICKER,
                        intent.getBooleanExtra("auto_open_picker", true)
                    )
                }
                navController.navigate(R.id.gallery_fragment, args)
            }
            else -> navController.navigate(R.id.camera_fragment)
        }
    }

    override fun onBackPressed() {
       finish()
    }
}
