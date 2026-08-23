package com.nailify.nailify_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * MainActivity cho Flutter app.
 *
 * MethodChannel "com.nailify.ar/tryon" + EventChannel "com.nailify.ar/tryon/events"
 * + SurfaceView factory "nail_plugin/surface_view" đều do NailTryOnPlugin
 * đăng ký trong onAttachedToEngine. KHÔNG khai báo handler cũ tại đây nữa
 * (trước kia mở HandLandmarkerActivity của MediaPipe — đã được chuyển sang
 * plugin mới ở refactor `Refactor AR Try-On sang Native Plugin`).
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // NailTryOnPlugin tự register MethodChannel + EventChannel + SurfaceView factory.
        flutterEngine.plugins.add(
            com.nailify.nail_plugin.NailTryOnPlugin()
        )
    }
}