/*
 * native_try_on_screen.dart — Màn hình AR Try-On mới sử dụng plugin Native.
 *
 * Thay thế luồng cũ:
 *   - Cũ: ArTryOnService.launch*() → MainActivity MethodChannel.launch() →
 *         startActivity(HandLandmarkerActivity) → CameraFragment YOLO/MediaPipe.
 *   - Mới: Navigate đến NativeTryOnScreen → embed NativeCameraView (AndroidView
 *         SurfaceView native) → gọi NailTryOnClient.startSession() để bắt đầu
 *         pipeline AI trên MainActivity hiện tại.
 *
 * Cấu trúc:
 *   - Truyền config (shape/length/nails/...) từ caller vào NativeCameraView.
 *   - Callback onCapture trả path ảnh đã chụp về caller.
 *   - Nút đóng: Navigator.pop().
 */
import 'dart:io';

import 'package:flutter/material.dart';

import '../../nails/widgets/native_camera_view.dart';
import '../../nails/services/nail_try_on_client.dart';

import 'package:permission_handler/permission_handler.dart';

class NativeTryOnScreen extends StatefulWidget {
  /// Config được convert từ NailVariantModel / CustomerNailModel.
  final Map<String, dynamic> config;

  /// Mode: 'live' | 'photo' (hiện tại UI chỉ dùng live; photo dùng snapshot riêng).
  final String mode;

  /// Callback khi user chụp ảnh. Nếu null, chỉ back về màn trước.
  final ValueChanged<String>? onCapture;

  /// Trả về CustomerNailModel đã cập nhật offset nếu caller cần (snapshot mode).
  const NativeTryOnScreen({
    super.key,
    required this.config,
    this.mode = 'live',
    this.onCapture,
  });

  @override
  State<NativeTryOnScreen> createState() => _NativeTryOnScreenState();
}

class _NativeTryOnScreenState extends State<NativeTryOnScreen> {
  bool _hasPermission = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
        _isChecking = false;
      });
    }
  }

  @override
  void dispose() {
    // stopSession sẽ được gọi từ NativeCameraView.dispose. Đặt guard ở đây
    // (no-op nếu session đã null).
    NailTryOnClient.instance.stopSession();
    super.dispose();
  }

  Future<void> _onClose() async {
    try {
      await NailTryOnClient.instance.stopSession();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  void _onCapture(String path) {
    widget.onCapture?.call(path);
    _onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (!Platform.isAndroid) {
      return _ErrorView(
        message: 'Native AR Try-On chỉ hỗ trợ Android.',
        onClose: _onClose,
      );
    }
    if (_isChecking) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (!_hasPermission) {
      return _ErrorView(
        message: 'Bạn cần cấp quyền Camera để sử dụng AR Try-On.',
        onClose: _onClose,
      );
    }
    return NativeCameraView(
      config: widget.config,
      onCapture: _onCapture,
      onClose: _onClose,
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onClose;
  const _ErrorView({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Center(child: CircularProgressIndicator(color: Colors.white)),
        Positioned(
          top: 24,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
        ),
      ],
    );
  }
}
