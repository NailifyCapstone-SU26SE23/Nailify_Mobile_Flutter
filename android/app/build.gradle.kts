plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.google.mediapipe.examples.handlandmarker"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nailify.nailify_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // KHÔNG dùng ndk.abiFilters ở đây vì nó áp dụng cho TẤT CẢ native libs,
        // bao gồm libflutter.so của Flutter engine (mặc định build cho x86_64).
        // Dùng splits.abis (bên dưới) để lọc ABI trong packaging step thay thế.
    }

    buildFeatures {
        viewBinding = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            // pickFirst cho cả 3 lib ONNX — đề phòng nhiều dependency mang
            // cùng .so nhưng version khác nhau (gây lỗi "OrtGetApiBase symbol not found"
            // khi libonnxruntime4j_jni.so link tới libonnxruntime.so sai phiên bản).
            pickFirsts.add("**/libonnxruntime4j_jni.so")
            pickFirsts.add("**/libonnxruntime.so")
            pickFirsts.add("**/libonnxruntime_extensions.so")
            // Exclude x86 (32-bit, không còn thiết bị/emulator) để giảm APK size.
            // Giữ x86_64 cho emulator dev. KHÔNG dùng ndk.abiFilters ở defaultConfig
            // vì nó chặn luôn libflutter.so của Flutter engine.
            excludes.add("lib/x86/**")
        }
    }

    splits {
        // Loại bỏ x86/x86_64 cũ (32-bit, không còn thiết bị thật).
        // Vẫn giữ x86_64 vì một số emulator dev cần nó.
        // Kết hợp với packaging.excludes ở trên, kết quả APK cuối cùng
        // có arm64-v8a + armeabi-v7a + x86_64.
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a", "x86_64")
            isUniversalApk = true
        }
    }

    androidResources {
        noCompress += listOf("onnx", "pt", "task", "tflite", "json")
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.fragment:fragment-ktx:1.5.4")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.5.1")

    val navVersion = "2.5.3"
    implementation("androidx.navigation:navigation-fragment-ktx:$navVersion")
    implementation("androidx.navigation:navigation-ui-ktx:$navVersion")
    implementation("org.tensorflow:tensorflow-lite:2.16.1")
    val cameraXVersion = "1.4.2"
    implementation("androidx.camera:camera-core:$cameraXVersion")
    implementation("androidx.camera:camera-camera2:$cameraXVersion")
    implementation("androidx.camera:camera-lifecycle:$cameraXVersion")
    implementation("androidx.camera:camera-view:$cameraXVersion")

    implementation("androidx.window:window:1.1.0-alpha03")
    implementation("com.google.mediapipe:tasks-vision:0.10.29")
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.20.0")
    implementation("com.google.code.gson:gson:2.11.0")
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("androidx.recyclerview:recyclerview:1.3.2")
    implementation("com.github.bumptech.glide:glide:4.16.0")
    implementation(platform("com.google.firebase:firebase-bom:34.15.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
}
