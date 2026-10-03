package com.google.mediapipe.examples.handlandmarker.model

data class NailSet(
    val id: String,
    val name: String,
    val description: String? = null,
    val imageUrl: String? = null,
    val price: Double,
    val isActive: Boolean,
    val createdAt: String,
    val shape: String? = null,
    val length: Double? = null,
    val material: String? = null,
    val gradientEnabled: Boolean = false,
    val gradientType: String? = null,
    val gradientStopsJson: String? = null,
    val gradientStopCount: Int? = null,
    val tryOnConfigJson: String? = null,
    val items: List<NailSetItem> = emptyList(),
    val tags: List<String> = emptyList()
)

data class NailSetItem(
    val id: String,
    val nailComponentId: String? = null,
    val nailComponentName: String,
    val nailComponentImageUrl: String? = null,
    val componentType: String? = null,
    val position: Int,
    val shape: String? = null,
    val length: Double? = null,
    val material: String? = null,
    val colorHex: String? = null,
    val gradientEnabled: Boolean? = null,
    val gradientType: String? = null,
    val customShapeImageUrl: String? = null
)
