# Nail AR Integration

## What Flutter Already Sends

The Flutter side calls:

```dart
const MethodChannel('com.nailify.ar/tryon').invokeMethod('launch', {
  'config': nailSetConfigMap,
  'mode': 'live', // or 'photo'
});
```

The Android host serializes that map to JSON and passes it as:

```kotlin
intent.putExtra("nail_set_config_json", configJson)
intent.putExtra("try_on_entry", mode)
intent.putExtra("auto_open_picker", mode == "photo")
```

Flutter can check whether the native AR activity has been copied into the app before showing the try-on action:

```dart
final available = await const MethodChannel('com.nailify.ar/tryon')
    .invokeMethod<bool>('isAvailable');
```

## Minimal Kotlin Change In The Existing AR Activity

In the old AR app, `MainActivity` owns the shared `MainViewModel`. Add this to `onCreate` after `setContentView(...)`:

```kotlin
private val gson = com.google.gson.Gson()

override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    activityMainBinding = ActivityMainBinding.inflate(layoutInflater)
    setContentView(activityMainBinding.root)

    intent.getStringExtra("nail_set_config_json")
        ?.takeIf { it.isNotBlank() }
        ?.let { configJson ->
            runCatching {
                gson.fromJson(
                    configJson,
                    com.google.mediapipe.examples.handlandmarker.model.NailSetConfig::class.java
                )
            }.onSuccess { config ->
                viewModel.applyNailSetConfig(config)
            }
        }
}
```

This keeps the hand landmarker and `OverlayView` unchanged. Flutter only launches the activity and passes data.

To route straight to the requested try-on surface, read the entry extra after applying config:

```kotlin
when (intent.getStringExtra("try_on_entry")) {
    "photo" -> {
        val args = Bundle().apply {
            putBoolean(
                com.google.mediapipe.examples.handlandmarker.fragment.GalleryFragment.ARG_AUTO_OPEN_PICKER,
                intent.getBooleanExtra("auto_open_picker", true)
            )
        }
        navController.navigate(R.id.gallery_fragment, args)
    }
    else -> navController.navigate(R.id.camera_fragment)
}
```

Use your actual navigation destination ids if they differ. In the Android source this matches the existing detail behavior: live try-on opens `CameraFragment`; photo try-on opens `GalleryFragment` and auto-opens the picker.

## AndroidManifest Entry After Copying The AR Module

Register the copied AR activity in the Flutter app manifest:

```xml
<activity
    android:name="com.google.mediapipe.examples.handlandmarker.MainActivity"
    android:exported="false"
    android:screenOrientation="portrait" />
```

If you rename the AR activity to `HandLandmarkerActivity`, use:

```xml
<activity
    android:name="com.google.mediapipe.examples.handlandmarker.HandLandmarkerActivity"
    android:exported="false"
    android:screenOrientation="portrait" />
```

## Permissions

Keep the AR module camera permission:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

## Data Format Expected By AR

```json
{
  "shape": "ballerina",
  "length": 1.0,
  "material": "standard",
  "gradient": {
    "enabled": false,
    "type": "linear",
    "stops": ["#FF4081", "#FFFFFF", "#000000"],
    "stopCount": 2
  },
  "nails": [
    {
      "color": "#FF4081",
      "customShapeSrc": null,
      "gradient": null,
      "decorations": [
        {
          "id": "1",
          "type": "gem",
          "componentId": "5",
          "imageSrc": "https://...",
          "x": 0.1,
          "y": -0.2,
          "scale": 0.2,
          "rotation": 0
        }
      ]
    }
  ]
}
```

## Answers To The Integration Questions

Do you need to modify Kotlin code? Yes, minimally: accept the intent extra and apply it to `MainViewModel`.

Will Flutter break the hand landmarker? No. The native activity still owns CameraX, MediaPipe, and rendering.

Performance impact? Low. Flutter passes data once; the native screen runs at native Android speed.

How to pass data? Use `MethodChannel` for JSON config. Use `FileProvider` only when sending local image files; remote component images can stay as URLs.
