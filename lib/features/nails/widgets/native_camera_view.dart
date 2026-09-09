/*
 * native_camera_view.dart — Widget hiển thị camera + overlay qua native plugin.
 *
 * Gồm:
 *   - AndroidView (viewType: 'nail_plugin/surface_view') — hiển thị frame + bbox.
 *   - Stats overlay (FPS, detection count) — subscribe từ NailTryOnClient.stats.
 *   - Back/Capture buttons.
 *
 * Sử dụng:
 *   final view = NativeCameraView(
 *     config: { shape: 'ballerina', length: 1.0, nails: [...] },
 *     onCapture: (path) => ...,
 *   );
 */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/nail_try_on_client.dart';

class NativeCameraView extends StatefulWidget {
  final Map<String, dynamic> config;
  final ValueChanged<String>? onCapture;
  final VoidCallback? onClose;

  const NativeCameraView({
    super.key,
    required this.config,
    this.onCapture,
    this.onClose,
  });

  @override
  State<NativeCameraView> createState() => _NativeCameraViewState();
}

class _NativeCameraViewState extends State<NativeCameraView> {
  StreamSubscription<NailTryOnStats>? _statsSub;
  NailTryOnStats? _lastStats;

  bool _showFps = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _statsSub = NailTryOnClient.instance.stats.listen((s) {
      if (!mounted) return;
      setState(() => _lastStats = s);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await NailTryOnClient.instance.setDebugFlags(
          showSkeleton: false,
          showBbox: false,
          showFps: _showFps,
          showAnchorCompare: false,
          showUBoundary: false,
        );
        await NailTryOnClient.instance.startSession(
          config: widget.config,
          mode: 'live',
        );
      } on NailTryOnInitException catch (e) {
        // Native side báo init fail (ONNX Runtime loadLibrary thất bại,
        // MediaPipe native lỗi, ABI mismatch). Hiển thị fallback UI thay
        // vì để exception bubble lên Flutter framework.
        debugPrint('[NativeCameraView] AR init failed: ${e.message}');
        if (mounted) {
          setState(() => _initError = e.message);
        }
      } on PlatformException catch (e) {
        debugPrint('[NativeCameraView] startSession failed: ${e.message}');
        if (mounted) {
          setState(() => _initError = e.message ?? 'Platform error');
        }
      } catch (e, st) {
        // Catch-all: bất kỳ exception nào khác (vd: missing plugin registration
        // trên iOS, JS engine error) cũng không được để crash app.
        debugPrint('[NativeCameraView] unexpected error: $e\n$st');
        if (mounted) {
          setState(() => _initError = e.toString());
        }
      }
    });
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    NailTryOnClient.instance.stopSession();
    super.dispose();
  }

  Future<void> _onCapture() async {
    try {
      final path = await NailTryOnClient.instance.captureSnapshot();
      if (path != null) widget.onCapture?.call(path);
    } catch (e) {
      debugPrint('[NativeCameraView] capture failed: $e');
    }
  }

  Future<void> _toggleFps() async {
    setState(() => _showFps = !_showFps);
    try {
      await NailTryOnClient.instance.setDebugFlags(
        showSkeleton: false,
        showBbox: false,
        showFps: _showFps,
        showAnchorCompare: false,
        showUBoundary: false,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Camera fills ~95% of the screen height so users get a wide view of their hand.
    final media = MediaQuery.of(context);
    final cameraHeight = media.size.height * 0.95;

    // Fallback UI khi native AR init thất bại (vd: ONNX Runtime loadLibrary
    // fail, ABI mismatch, MediaPipe lỗi). Hiển thị thông báo + nút đóng
    // thay vì để _NativeSurface (AndroidView) trống hoặc crash.
    if (_initError != null) {
      return SizedBox(
        height: cameraHeight,
        width: double.infinity,
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                size: 64,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              const Text(
                'AR Try-On không khả dụng',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _initError!,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, color: Colors.white),
                label: const Text(
                  'Đóng',
                  style: TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: cameraHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _NativeSurface(),
          Positioned(top: 12, left: 12, child: _StatsCard(stats: _lastStats)),
          Positioned(
            top: 12,
            right: 12,
            child: _DebugToggleButton(
              label: 'FPS',
              on: _showFps,
              onTap: _toggleFps,
            ),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 48,
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                const SizedBox(width: 32),
                ElevatedButton(
                  onPressed: _onCapture,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(20),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: const Icon(Icons.camera_alt, size: 36),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NativeSurface extends StatelessWidget {
  const _NativeSurface();
  @override
  Widget build(BuildContext context) {
    const viewType = 'nail_plugin/surface_view';
    const creationParams = <String, dynamic>{};
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const ColoredBox(color: Colors.black);
    }
    return AndroidView(
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final NailTryOnStats? stats;
  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final text = s == null
        ? 'init...'
        : 'YOLO ${s.yoloDetections} (${s.yoloInferenceMs}ms)\n'
              'MP ${s.mediapipeHand ? "${s.mediapipeFingers}f" : "-"} (${s.mediapipeMs}ms)\n'
              'tracks ${s.trackerConfirmed}\n'
              'total ${s.totalMs}ms';
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DebugToggleButton extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _DebugToggleButton({
    required this.label,
    required this.on,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: on ? Colors.green : Colors.black54,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}
