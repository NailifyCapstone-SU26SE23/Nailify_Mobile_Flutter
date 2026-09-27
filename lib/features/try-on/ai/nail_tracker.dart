import 'dart:math';
import 'dart:ui';
import 'package:hand_landmarker/hand_landmarker.dart';

import 'fingertip_gate.dart';

/// Decouples nail *shape* (accurate but slow — comes from the YOLO
/// segmentation pipeline, updated maybe once every few seconds) from nail
/// *position* (needs to track the hand live — comes from MediaPipe hand
/// landmarks, updated every camera frame).
///
/// Whenever a YOLO detection is matched to a specific fingertip, its polygon
/// is stored in a frame relative to that finger: rotated so the finger points
/// along +x and scaled by the tip-to-DIP-joint distance. On every landmark
/// update, each stored shape is re-projected onto the *current* fingertip
/// position/orientation/scale — so the overlay follows the hand in real time
/// even though the shape itself is only refreshed occasionally.
class NailTracker {
  /// Generates a standard nail polygon for every currently visible finger.
  /// Fingers that are clenched (fist) will be automatically skipped by [_currentFingerFrames].
  List<List<Offset>> render({
    required List<Hand> hands,
    required int sensorWidth,
    required int sensorHeight,
    required int rotationDegrees,
    double nailScale = 1.0,
  }) {
    if (hands.isEmpty) return [];

    final fingerFrames = _currentFingerFrames(
      hands: hands,
      sensorWidth: sensorWidth,
      sensorHeight: sensorHeight,
      rotationDegrees: rotationDegrees,
    );

    final List<List<Offset>> rendered = [];
    fingerFrames.forEach((key, frame) {
      if (frame.length < 1.0) return;

      // Create a standard rectangular bounding box representing the nail bed.
      // +X is pointing toward the fingertip. -X is toward the palm.
      final double width = frame.length * 0.95 * nailScale;
      final double length = frame.length * 1.5 * nailScale;

      // Center the polygon slightly behind the actual fingertip landmark
      // (because the landmark is at the very edge of the flesh).
      final double centerX = -length * 0.45;

      final List<Offset> localShape = [
        Offset(centerX - length / 2, -width / 2), // Cuticle left
        Offset(centerX + length / 2, -width / 2), // Tip left
        Offset(centerX + length / 2, width / 2), // Tip right
        Offset(centerX - length / 2, width / 2), // Cuticle right
      ];

      // Transform local polygon to world screen space
      rendered.add(
        localShape.map((lp) => frame.tip + _rotate(lp, frame.angle)).toList(),
      );
    });
    return rendered;
  }

  void reset() {}

  /// Computes, for every (hand, finger) pair currently visible, the
  /// fingertip position/orientation/scale needed to place a nail shape.
  /// Keyed by `handIndex * 5 + fingerSlot` (fingerSlot indexes into
  /// [fingertipLandmarkIndices]).
  Map<int, _FingerFrame> _currentFingerFrames({
    required List<Hand> hands,
    required int sensorWidth,
    required int sensorHeight,
    required int rotationDegrees,
  }) {
    final Map<int, _FingerFrame> frames = {};

    for (int handIdx = 0; handIdx < hands.length; handIdx++) {
      final landmarks = hands[handIdx].landmarks;
      for (int slot = 0; slot < fingertipLandmarkIndices.length; slot++) {
        final tipIndex = fingertipLandmarkIndices[slot];
        final jointIndex = tipIndex - 1; // DIP/IP joint, just before the tip
        final pipIndex = tipIndex - 2; // PIP joint
        if (tipIndex >= landmarks.length || jointIndex < 0) continue;

        final tip = landmarkToPixel(
          landmarks[tipIndex],
          sensorWidth: sensorWidth,
          sensorHeight: sensorHeight,
          rotationDegrees: rotationDegrees,
        );

        // Check if finger is clenched in a fist (tip folded towards palm/wrist)
        if (pipIndex >= 0 && pipIndex < landmarks.length) {
          final wrist = landmarkToPixel(
            landmarks[0],
            sensorWidth: sensorWidth,
            sensorHeight: sensorHeight,
            rotationDegrees: rotationDegrees,
          );
          final pip = landmarkToPixel(
            landmarks[pipIndex],
            sensorWidth: sensorWidth,
            sensorHeight: sensorHeight,
            rotationDegrees: rotationDegrees,
          );

          final distWristTip = (tip - wrist).distance;
          final distWristPip = (pip - wrist).distance;

          // If tip is closer to wrist than PIP joint, finger is folded into a fist -> nails hidden
          if (distWristTip < distWristPip * 0.92) {
            continue;
          }
        }

        final joint = landmarkToPixel(
          landmarks[jointIndex],
          sensorWidth: sensorWidth,
          sensorHeight: sensorHeight,
          rotationDegrees: rotationDegrees,
        );

        final vector = tip - joint;
        frames[handIdx * fingertipLandmarkIndices.length + slot] = _FingerFrame(
          tip: tip,
          angle: atan2(vector.dy, vector.dx),
          length: vector.distance,
        );
      }
    }

    return frames;
  }

  static Offset _rotate(Offset v, double angle) {
    final c = cos(angle);
    final s = sin(angle);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }
}

class _FingerFrame {
  final Offset tip;
  final double angle;
  final double length;
  _FingerFrame({required this.tip, required this.angle, required this.length});
}
