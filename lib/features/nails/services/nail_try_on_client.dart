/*
 * nail_try_on_client.dart — Dart-side wrapper cho Native MethodChannel +
 * EventChannel từ NailTryOnPlugin (Android).
 *
 * Cung cấp:
 *  - startSession(config, mode)
 *  - stopSession()
 *  - updateManualOffset(x, y, scale, rotation)
 *  - setDebugFlags(showSkeleton, showBbox, showFps)
 *  - captureSnapshot()
 *  - Stream<NailTryOnStats> stats (từ EventChannel)
 *
 * Channel names phải khớp với NailTryOnPlugin.kt (com.nailify.ar/tryon và
 * com.nailify.ar/tryon/events).
 */
import 'dart:async';

import 'package:flutter/services.dart';

class NailTryOnStats {
  final int yoloDetections;
  final int yoloInferenceMs;
  final bool mediapipeHand;
  final int mediapipeFingers;
  final int mediapipeMs;
  final int trackerConfirmed;
  final String frameSize;
  final int totalMs;

  const NailTryOnStats({
    required this.yoloDetections,
    required this.yoloInferenceMs,
    required this.mediapipeHand,
    required this.mediapipeFingers,
    required this.mediapipeMs,
    required this.trackerConfirmed,
    required this.frameSize,
    required this.totalMs,
  });

  factory NailTryOnStats.fromMap(Map<dynamic, dynamic> map) {
    return NailTryOnStats(
      yoloDetections: (map['yolo.detections'] as num?)?.toInt() ?? 0,
      yoloInferenceMs: (map['yolo.inferenceMs'] as num?)?.toInt() ?? 0,
      mediapipeHand: map['mediapipe.hand'] as bool? ?? false,
      mediapipeFingers: (map['mediapipe.fingers'] as num?)?.toInt() ?? 0,
      mediapipeMs: (map['mediapipe.ms'] as num?)?.toInt() ?? 0,
      trackerConfirmed: (map['tracker.confirmed'] as num?)?.toInt() ?? 0,
      frameSize: map['frame.size'] as String? ?? '',
      totalMs: (map['total.ms'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() =>
      'YOLO=$yoloDetections(${yoloInferenceMs}ms) '
      'MP=${mediapipeHand ? "${mediapipeFingers}f" : "no"} '
      'tracks=$trackerConfirmed total=${totalMs}ms';
}

class NailTryOnClient {
  NailTryOnClient._();

  static final NailTryOnClient instance = NailTryOnClient._();

  static const MethodChannel _method =
      MethodChannel('com.nailify.ar/tryon');
  static const EventChannel _events =
      EventChannel('com.nailify.ar/tryon/events');

  Stream<NailTryOnStats>? _statsStream;

  /// Bắt đầu session. Trước đó cần dựng 1 NativeSurfaceView (AndroidView) trên UI.
  /// `config` là Map (shape, length, nails, ...) giống như config cũ.
  Future<void> startSession({
    Map<String, dynamic>? config,
    String mode = 'live',
  }) async {
    await _method.invokeMethod<void>('startSession', {
      'config': config ?? <String, dynamic>{},
      'mode': mode,
    });
  }

  Future<void> stopSession() async {
    await _method.invokeMethod<void>('stopSession');
  }

  Future<void> updateManualOffset({
    double offsetX = 0,
    double offsetY = 0,
    double scale = 1,
    double rotation = 0,
  }) async {
    await _method.invokeMethod<void>('updateManualOffset', {
      'offsetX': offsetX,
      'offsetY': offsetY,
      'scale': scale,
      'rotation': rotation,
    });
  }

  Future<void> setDebugFlags({
    bool showSkeleton = true,
    bool showBbox = true,
    bool showFps = true,
  }) async {
    await _method.invokeMethod<void>('setDebugFlags', {
      'showSkeleton': showSkeleton,
      'showBbox': showBbox,
      'showFps': showFps,
    });
  }

  Future<String?> captureSnapshot() async {
    final result = await _method.invokeMapMethod<String, dynamic>('captureSnapshot');
    return result?['imagePath'] as String?;
  }

  /// Subscribe vào frame stats. Mỗi frame native gửi 1 event (lọc 1/5 frame).
  Stream<NailTryOnStats> get stats {
    _statsStream ??= _events
        .receiveBroadcastStream()
        .map((event) => NailTryOnStats.fromMap(event as Map))
        .handleError((e, st) {
      // swallow stream errors; emit empty stats
      return NailTryOnStats(
        yoloDetections: 0,
        yoloInferenceMs: 0,
        mediapipeHand: false,
        mediapipeFingers: 0,
        mediapipeMs: 0,
        trackerConfirmed: 0,
        frameSize: '',
        totalMs: 0,
      );
    });
    return _statsStream!;
  }
}