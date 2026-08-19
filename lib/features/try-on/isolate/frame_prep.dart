import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../ai/letterbox.dart';
import 'raw_camera_frame.dart';

/// Runs entirely on a background isolate via `compute()`: YUV420/BGRA8888 ->
/// RGB -> sensor-orientation rotation -> letterbox tensor. This is the
/// heaviest per-pixel work in the AR pipeline (two full-frame loops), so it
/// must not run on the UI isolate every camera frame.
LetterboxResult prepareFrameForInference(RawCameraFrame raw) {
  int step = 1;
  if (raw.width > 640 || raw.height > 640) {
    step = (raw.width > raw.height ? raw.width / 640 : raw.height / 640).ceil();
    if (step < 1) step = 1;
  }

  img.Image rgb = raw.isYuv420
      ? _yuv420ToImage(raw, step: step)
      : _bgraToImage(raw, step: step);

  if (raw.rotationDegrees == 90 || raw.rotationDegrees == 270) {
    rgb = img.copyRotate(rgb, angle: raw.rotationDegrees);
  }

  final letterbox = LetterboxProcessor.process(rgb);

  final int origW = (raw.rotationDegrees == 90 || raw.rotationDegrees == 270) ? raw.height : raw.width;
  final int origH = (raw.rotationDegrees == 90 || raw.rotationDegrees == 270) ? raw.width : raw.height;

  return LetterboxResult(
    tensor: letterbox.tensor,
    scale: letterbox.scale / step,
    padLeft: letterbox.padLeft,
    padTop: letterbox.padTop,
    originalWidth: origW,
    originalHeight: origH,
  );
}

Uint8List prepareJpgForOnlineInference(RawCameraFrame raw) {
  int step = 1;
  if (raw.width > 640 || raw.height > 640) {
    step = (raw.width > raw.height ? raw.width / 640 : raw.height / 640).ceil();
    if (step < 1) step = 1;
  }

  img.Image rgb = raw.isYuv420
      ? _yuv420ToImage(raw, step: step)
      : _bgraToImage(raw, step: step);

  if (raw.rotationDegrees == 90 || raw.rotationDegrees == 270) {
    rgb = img.copyRotate(rgb, angle: raw.rotationDegrees);
  }

  return img.encodeJpg(rgb);
}

img.Image _yuv420ToImage(RawCameraFrame raw, {int step = 1}) {
  final int width = raw.width;
  final int height = raw.height;
  final int outW = (width / step).floor();
  final int outH = (height / step).floor();

  final imgImage = img.Image(width: outW, height: outH);

  final yBuffer = raw.plane0;
  final uBuffer = raw.plane1!;
  final vBuffer = raw.plane2!;

  final int yRowStride = raw.plane0RowStride;
  final int uvRowStride = raw.uvRowStride;
  final int uvPixelStride = raw.uvPixelStride;

  for (int outY = 0; outY < outH; outY++) {
    final int y = outY * step;
    for (int outX = 0; outX < outW; outX++) {
      final int x = outX * step;

      final int yIndex = y * yRowStride + x;
      final int uvIndex = (y >> 1) * uvRowStride + (x >> 1) * uvPixelStride;

      final int yValue = yBuffer[yIndex];
      final int uValue = uBuffer[uvIndex] - 128;
      final int vValue = vBuffer[uvIndex] - 128;

      int r = (yValue + 1.402 * vValue).round().clamp(0, 255);
      int g = (yValue - 0.344136 * uValue - 0.714136 * vValue).round().clamp(0, 255);
      int b = (yValue + 1.772 * uValue).round().clamp(0, 255);

      imgImage.setPixelRgb(outX, outY, r, g, b);
    }
  }

  return imgImage;
}

img.Image _bgraToImage(RawCameraFrame raw, {int step = 1}) {
  final int width = raw.width;
  final int height = raw.height;
  final int outW = (width / step).floor();
  final int outH = (height / step).floor();

  final bytes = raw.plane0;
  final imgImage = img.Image(width: outW, height: outH);

  for (int outY = 0; outY < outH; outY++) {
    final int y = outY * step;
    for (int outX = 0; outX < outW; outX++) {
      final int x = outX * step;
      final int bufferIndex = (y * width + x) * 4;

      final int b = bytes[bufferIndex];
      final int g = bytes[bufferIndex + 1];
      final int r = bytes[bufferIndex + 2];

      imgImage.setPixelRgb(outX, outY, r, g, b);
    }
  }

  return imgImage;
}
