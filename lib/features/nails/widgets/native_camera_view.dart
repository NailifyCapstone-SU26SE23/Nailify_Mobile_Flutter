/*
 * native_camera_view.dart — Widget hiển thị camera + overlay qua native plugin.
 *
 * Gồm:
 *   - AndroidView (viewType: 'nail_plugin/surface_view') — hiển thị frame + bbox.
 *   - Stats overlay (FPS, detection count) — subscribe từ NailTryOnClient.stats.
 *   - Back/Snapshot/Offset buttons.
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

  // Manual offset controls (giống D-Pad cũ).
  double _offsetX = 0;
  double _offsetY = 0;
  double _scale = 1.0;
  double _rotation = 0;

  bool _showSkeleton = true;
  bool _showBbox = true;
  bool _showFps = true;

  @override
  void initState() {
    super.initState();
    _statsSub = NailTryOnClient.instance.stats.listen((s) {
      if (!mounted) return;
      setState(() => _lastStats = s);
    });
    // Khởi động session sau khi widget mount (delay 1 frame để surface sẵn sàng).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await NailTryOnClient.instance.setDebugFlags(
          showSkeleton: _showSkeleton,
          showBbox: _showBbox,
          showFps: _showFps,
        );
        await NailTryOnClient.instance.startSession(
          config: widget.config,
          mode: 'live',
        );
      } on PlatformException catch (e) {
        debugPrint('[NativeCameraView] startSession failed: ${e.message}');
      }
    });
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    NailTryOnClient.instance.stopSession();
    super.dispose();
  }

  Future<void> _onManualOffsetChanged() async {
    try {
      await NailTryOnClient.instance.updateManualOffset(
        offsetX: _offsetX,
        offsetY: _offsetY,
        scale: _scale,
        rotation: _rotation,
      );
    } catch (_) {}
  }

  Future<void> _onCapture() async {
    try {
      final path = await NailTryOnClient.instance.captureSnapshot();
      if (path != null) widget.onCapture?.call(path);
    } catch (e) {
      debugPrint('[NativeCameraView] capture failed: $e');
    }
  }

  Future<void> _onToggleDebug(int flag) async {
    bool changed = false;
    if (flag == 0 && _showSkeleton != !_showSkeleton) {
      _showSkeleton = !_showSkeleton; changed = true;
    } else if (flag == 1 && _showBbox != !_showBbox) {
      _showBbox = !_showBbox; changed = true;
    } else if (flag == 2 && _showFps != !_showFps) {
      _showFps = !_showFps; changed = true;
    }
    if (changed) {
      try {
        await NailTryOnClient.instance.setDebugFlags(
          showSkeleton: _showSkeleton,
          showBbox: _showBbox,
          showFps: _showFps,
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Native SurfaceView.
        const _NativeSurface(),
        // Stats overlay.
        Positioned(
          top: 12,
          left: 12,
          child: _StatsCard(stats: _lastStats),
        ),
        // Debug toggles.
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              _DebugToggleButton(label: 'SK', on: _showSkeleton, onTap: () => setState(() => _onToggleDebug(0))),
              const SizedBox(height: 6),
              _DebugToggleButton(label: 'BX', on: _showBbox, onTap: () => setState(() => _onToggleDebug(1))),
              const SizedBox(height: 6),
              _DebugToggleButton(label: 'FPS', on: _showFps, onTap: () => setState(() => _onToggleDebug(2))),
            ],
          ),
        ),
        // Manual offset controls (D-Pad).
        Positioned(
          left: 12,
          right: 12,
          bottom: 100,
          child: _ManualOffsetPanel(
            offsetX: _offsetX,
            offsetY: _offsetY,
            scale: _scale,
            rotation: _rotation,
            onChanged: (dx, dy, s, r) {
              setState(() {
                _offsetX = dx;
                _offsetY = dy;
                _scale = s;
                _rotation = r;
              });
              _onManualOffsetChanged();
            },
          ),
        ),
        // Capture + back buttons.
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
  const _DebugToggleButton({required this.label, required this.on, required this.onTap});
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
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }
}

class _ManualOffsetPanel extends StatelessWidget {
  final double offsetX;
  final double offsetY;
  final double scale;
  final double rotation;
  final void Function(double dx, double dy, double s, double r) onChanged;

  const _ManualOffsetPanel({
    required this.offsetX,
    required this.offsetY,
    required this.scale,
    required this.rotation,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('dx', style: TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: offsetX,
                  min: -50, max: 50,
                  onChanged: (v) => onChanged(v, offsetY, scale, rotation),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('dy', style: TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: offsetY,
                  min: -50, max: 50,
                  onChanged: (v) => onChanged(offsetX, v, scale, rotation),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('sc', style: TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: scale,
                  min: 0.5, max: 1.5,
                  onChanged: (v) => onChanged(offsetX, offsetY, v, rotation),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('rot', style: TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: rotation,
                  min: -1.0, max: 1.0,
                  onChanged: (v) => onChanged(offsetX, offsetY, scale, v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}