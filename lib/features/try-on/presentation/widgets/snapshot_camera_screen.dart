import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Màn hình Camera chuyên dụng cho Snapshot Try-On sử dụng chính xác
/// hình ảnh khung định vị bàn tay (hand_camera_guide.png), cố định tĩnh ở trung tâm, không nhấp nháy.
class SnapshotCameraScreen extends StatefulWidget {
  const SnapshotCameraScreen({super.key});

  static Future<File?> open(BuildContext context) async {
    return Navigator.of(context).push<File?>(
      MaterialPageRoute(
        builder: (context) => const SnapshotCameraScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<SnapshotCameraScreen> createState() => _SnapshotCameraScreenState();
}

class _SnapshotCameraScreenState extends State<SnapshotCameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isCapturing = false;
  int _selectedCameraIdx = 0;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _onCameraSelected(cameraController.description);
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _isInitializing = false);
        return;
      }

      int backIdx = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _selectedCameraIdx = backIdx != -1 ? backIdx : 0;
      await _onCameraSelected(_cameras[_selectedCameraIdx]);
    } catch (e) {
      debugPrint("⚠️ Lỗi khởi tạo Camera: $e");
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _onCameraSelected(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    final newController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = newController;

    try {
      await newController.initialize();
      await newController.setFlashMode(_flashMode);
      if (mounted) setState(() => _isInitializing = false);
    } catch (e) {
      debugPrint("⚠️ Lỗi khởi tạo CameraController: $e");
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.off:
        nextMode = FlashMode.torch;
        break;
      case FlashMode.torch:
        nextMode = FlashMode.auto;
        break;
      default:
        nextMode = FlashMode.off;
        break;
    }

    try {
      await _controller!.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
    } catch (e) {
      debugPrint("⚠️ Lỗi đổi Flash: $e");
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    try {
      setState(() => _isCapturing = true);
      final XFile photo = await _controller!.takePicture();
      if (mounted) {
        Navigator.of(context).pop(File(photo.path));
      }
    } catch (e) {
      debugPrint("⚠️ Lỗi chụp ảnh: $e");
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi chụp ảnh: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final guideCenterY = screenHeight * 0.42;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview Viewport
          if (!_isInitializing &&
              _controller != null &&
              _controller!.value.isInitialized)
            Center(
              child: CameraPreview(_controller!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),

          // 2. Corner Brackets Framing (4 góc định vị)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CornerBracketsPainter(centerY: guideCenterY),
              ),
            ),
          ),

          // 3. Hình ảnh bàn tay tĩnh, sắc nét ngay chính giữa khung ngắm (hand_camera_guide.png)
          Positioned(
            top: guideCenterY - 144,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Image.asset(
                  'assets/images/hand_camera_guide.png',
                  width: 240,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // 4. Top Navigation Bar: Back & Flash Buttons
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGlassCircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    _buildGlassCircleButton(
                      icon: _flashMode == FlashMode.torch
                          ? Icons.flash_on_rounded
                          : (_flashMode == FlashMode.auto
                              ? Icons.flash_auto_rounded
                              : Icons.flash_off_rounded),
                      iconColor: _flashMode != FlashMode.off
                          ? const Color(0xFFFFD54F)
                          : Colors.white,
                      onTap: _toggleFlash,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Bottom Shutter Bar & Branding
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.only(bottom: 24, top: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Large White Shutter Button
                    GestureDetector(
                      onTap: _isCapturing ? null : _capturePhoto,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                            width: 4.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: _isCapturing
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 30,
                                  color: AppColors.primaryDark,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Branding Text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Powered by ',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'NAILIFY AI',
                          style: TextStyle(
                            color: const Color(0xFFFF66C4),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            shadows: [
                              Shadow(
                                color: AppColors.primary.withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCircleButton({
    required IconData icon,
    Color iconColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }
}

/// Painter vẽ khung 4 góc định vị (Corner Brackets) căn chuẩn theo vị trí trung tâm
class _CornerBracketsPainter extends CustomPainter {
  final double centerY;

  _CornerBracketsPainter({required this.centerY});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = centerY;

    final double boxWidth = size.width * 0.78;
    final double boxHeight = 330.0;

    final double left = cx - boxWidth / 2;
    final double right = cx + boxWidth / 2;
    final double top = cy - boxHeight / 2;
    final double bottom = cy + boxHeight / 2;

    final bracketPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..strokeWidth = 3.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double cornerLen = 34.0;

    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(left, top + cornerLen)
        ..lineTo(left, top)
        ..lineTo(left + cornerLen, top),
      bracketPaint,
    );

    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(right - cornerLen, top)
        ..lineTo(right, top)
        ..lineTo(right, top + cornerLen),
      bracketPaint,
    );

    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(left, bottom - cornerLen)
        ..lineTo(left, bottom)
        ..lineTo(left + cornerLen, bottom),
      bracketPaint,
    );

    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(right - cornerLen, bottom)
        ..lineTo(right, bottom)
        ..lineTo(right, bottom - cornerLen),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) =>
      oldDelegate.centerY != centerY;
}
