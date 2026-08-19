import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../models/nail_variant_model.dart';

class NailVariantApiService {
  static const String baseUrl =
      "https://nailify-be.onrender.com/api/NailVariants";

  /// Fetches nail variant items from Backend API
  static Future<List<NailVariantModel>> fetchNailVariants({
    int pageNumber = 1,
    int pageSize = 10,
    int? nailDesignId,
    String? name,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'pageNumber': '$pageNumber',
        'pageSize': '$pageSize',
      };
      if (nailDesignId != null) {
        queryParams['nailDesignId'] = '$nailDesignId';
      }
      if (name != null && name.isNotEmpty) {
        queryParams['name'] = name;
      }

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(response.body);
        final List<dynamic> items = jsonBody['data']['items'] ?? [];
        return items.map((i) => NailVariantModel.fromJson(i)).toList();
      }
    } catch (e) {
      debugPrint("⚠️ Lỗi fetch NailVariants: $e");
    }
    return [];
  }

  /// Fetches nail shapes from Backend API
  static Future<List<NailShape>> fetchNailShapes({
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    try {
      final uri = Uri.parse(
        "https://nailify-be.onrender.com/api/NailShapes?pageNumber=$pageNumber&pageSize=$pageSize",
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(response.body);
        final List<dynamic> items = jsonBody['data']['items'] ?? [];
        return items.map((i) => NailShape.fromJson(i)).toList();
      }
    } catch (e) {
      debugPrint("⚠️ Lỗi fetch NailShapes: $e");
    }
    return [];
  }

  /// Fetches nail surfaces from Backend API
  static Future<List<NailSurface>> fetchNailSurfaces({
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    try {
      final uri = Uri.parse(
        "https://nailify-be.onrender.com/api/NailSurfaces?pageNumber=$pageNumber&pageSize=$pageSize",
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(response.body);
        final List<dynamic> items = jsonBody['data']['items'] ?? [];
        return items.map((i) => NailSurface.fromJson(i)).toList();
      }
    } catch (e) {
      debugPrint("⚠️ Lỗi fetch NailSurfaces: $e");
    }
    return [];
  }

  /// Fetches components (accessories) from Backend API
  static Future<List<ComponentDetail>> fetchComponents({
    int pageNumber = 1,
    int pageSize = 10,
    String? componentType,
  }) async {
    try {
      String url =
          "https://nailify-be.onrender.com/api/Components?pageNumber=$pageNumber&pageSize=$pageSize";
      if (componentType != null && componentType.isNotEmpty) {
        url += "&componentType=$componentType";
      }
      final uri = Uri.parse(url);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = jsonDecode(response.body);
        final List<dynamic> items = jsonBody['data']['items'] ?? [];
        return items.map((i) => ComponentDetail.fromJson(i)).toList();
      }
    } catch (e) {
      debugPrint("⚠️ Lỗi fetch Components: $e");
    }
    return [];
  }

  /// Downloads network image URL and decodes it into ui.Image for Flutter Canvas drawing
  static Future<ui.Image?> loadUiImageFromUrl(String url) async {
    if (url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        final Completer<ui.Image> completer = Completer();
        ui.decodeImageFromList(bytes, (ui.Image img) {
          completer.complete(img);
        });
        return await completer.future;
      }
    } catch (e) {
      debugPrint("⚠️ Lỗi load ui.Image ($url): $e");
    }
    return null;
  }

  /// Downloads a nail shape / component PNG and prepares it for Canvas fitting:
  /// 1. Chroma-keys a solid studio background to transparent (many Cloudinary
  ///    shape PNGs are exported on an opaque light-gray card).
  /// 2. Trims fully transparent margins, so the painted rect maps 1:1 onto
  ///    real nail pixels — critical for a snug fit on the finger.
  /// Heavy pixel work runs on a background isolate via compute().
  static Future<ui.Image?> loadTrimmedUiImageFromUrl(String url) async {
    if (url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      final ProcessedImageBytes? processed = await compute(
        processNailImageBytes,
        response.bodyBytes,
      );
      if (processed == null) return null;

      final Completer<ui.Image> completer = Completer();
      ui.decodeImageFromPixels(
        processed.rgba,
        processed.width,
        processed.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      return await completer.future;
    } catch (e) {
      debugPrint("⚠️ Lỗi load trimmed ui.Image ($url): $e");
    }
    return null;
  }
}

/// Plain-data result so it can cross the compute() isolate boundary.
class ProcessedImageBytes {
  final Uint8List rgba;
  final int width;
  final int height;

  ProcessedImageBytes(this.rgba, this.width, this.height);
}

/// Top-level isolate entry: decode -> background key -> alpha trim -> raw RGBA.
ProcessedImageBytes? processNailImageBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  img.Image im = decoded.convert(numChannels: 4);

  _keyOutSolidBackground(im);

  // Trim fully transparent margins so drawn rect == real content bounds.
  int minX = im.width, minY = im.height, maxX = -1, maxY = -1;
  for (int y = 0; y < im.height; y++) {
    for (int x = 0; x < im.width; x++) {
      if (im.getPixel(x, y).a > 8) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX > minX && maxY > minY) {
    im = img.copyCrop(
      im,
      x: minX,
      y: minY,
      width: maxX - minX + 1,
      height: maxY - minY + 1,
    );
  }

  return ProcessedImageBytes(
    im.getBytes(order: img.ChannelOrder.rgba),
    im.width,
    im.height,
  );
}

/// If all four corners are opaque and near-identical, the PNG sits on a solid
/// background card — flood-fills it to transparent starting from the borders
/// (flood fill protects similar colors inside the nail, e.g. white gel on a
/// light-gray card).
void _keyOutSolidBackground(img.Image im) {
  final int w = im.width, h = im.height;
  if (w < 4 || h < 4) return;

  final corners = [
    im.getPixel(0, 0),
    im.getPixel(w - 1, 0),
    im.getPixel(0, h - 1),
    im.getPixel(w - 1, h - 1),
  ];
  for (final c in corners) {
    if (c.a < 200) return; // already transparent margins — nothing to key
  }
  num rSum = 0, gSum = 0, bSum = 0;
  for (final c in corners) {
    rSum += c.r;
    gSum += c.g;
    bSum += c.b;
  }
  final double bgR = rSum / 4, bgG = gSum / 4, bgB = bSum / 4;
  for (final c in corners) {
    if ((c.r - bgR).abs() > 14 ||
        (c.g - bgG).abs() > 14 ||
        (c.b - bgB).abs() > 14) {
      return; // corners disagree — not a solid background card
    }
  }

  const int tol = 13;
  bool isBg(int x, int y) {
    final p = im.getPixel(x, y);
    return p.a > 0 &&
        (p.r - bgR).abs() <= tol &&
        (p.g - bgG).abs() <= tol &&
        (p.b - bgB).abs() <= tol;
  }

  final visited = Uint8List(w * h);
  final stack = <int>[];
  void seed(int x, int y) {
    final idx = y * w + x;
    if (visited[idx] == 0 && isBg(x, y)) {
      visited[idx] = 1;
      stack.add(idx);
    }
  }

  for (int x = 0; x < w; x++) {
    seed(x, 0);
    seed(x, h - 1);
  }
  for (int y = 0; y < h; y++) {
    seed(0, y);
    seed(w - 1, y);
  }

  while (stack.isNotEmpty) {
    final idx = stack.removeLast();
    final int x = idx % w, y = idx ~/ w;
    final p = im.getPixel(x, y);
    im.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 0);

    if (x > 0) seed(x - 1, y);
    if (x < w - 1) seed(x + 1, y);
    if (y > 0) seed(x, y - 1);
    if (y < h - 1) seed(x, y + 1);
  }
}
