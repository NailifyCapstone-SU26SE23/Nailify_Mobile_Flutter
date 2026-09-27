import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

import '../../nails/data/models/customer_nail_models.dart';
import '../models/placed_component_draft.dart';
import '../widgets/try_on_preview_board.dart';
import '../utils/try_on_setup_helpers.dart';

class NailImageGenerator {
  /// Generates 5 nail images (thumb, index, middle, ring, pinky) and returns their file paths.
  /// This pushes a temporary transparent loading route to render the widgets offstage.
  static Future<Map<String, String>> generate(
    BuildContext context,
    CustomerNailModel nail,
  ) async {
    final Map<String, String>? result = await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (context, _, _) => _GeneratorScreen(nail: nail),
      ),
    );
    return result ?? {};
  }
}

class _GeneratorScreen extends StatefulWidget {
  final CustomerNailModel nail;

  const _GeneratorScreen({required this.nail});

  @override
  State<_GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<_GeneratorScreen> {
  final List<GlobalKey> _keys = List.generate(5, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    _startCaptureProcess();
  }

  Future<void> _startCaptureProcess() async {
    // Wait for first frame to mount
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Extra wait for network images (CachedNetworkImage) to load
      await Future.delayed(const Duration(milliseconds: 2000));
      if (!mounted) return;
      _captureImages();
    });
  }

  Future<void> _captureImages() async {
    try {
      final Map<String, String> paths = {};
      final fingerNames = ['thumb', 'index', 'middle', 'ring', 'pinky'];
      final tempDir = await getTemporaryDirectory();

      for (int i = 0; i < 5; i++) {
        final ctx = _keys[i].currentContext;
        if (ctx == null) {
          debugPrint('[NailGen] finger $i: context is null — skipping');
          continue;
        }
        final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) {
          debugPrint(
            '[NailGen] finger $i: RenderRepaintBoundary is null — skipping',
          );
          continue;
        }

        // Wait if it still needs paint
        if (boundary.debugNeedsPaint) {
          debugPrint(
            '[NailGen] finger $i: still needs paint, waiting a bit...',
          );
          await Future.delayed(const Duration(milliseconds: 100));
          if (boundary.debugNeedsPaint) {
            debugPrint(
              '[NailGen] finger $i: STILL needs paint, skipping to avoid crash',
            );
            continue;
          }
        }

        debugPrint('[NailGen] capturing finger $i (${fingerNames[i]})...');
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final file = File('${tempDir.path}/nail_${fingerNames[i]}.png');
          await file.writeAsBytes(byteData.buffer.asUint8List());
          paths[fingerNames[i]] = file.path;
          debugPrint(
            '[NailGen] saved: ${file.path} (${byteData.lengthInBytes} bytes)',
          );
        }
      }

      debugPrint('[NailGen] done. paths=$paths');
      if (mounted) {
        Navigator.of(context).pop(paths);
      }
    } catch (e) {
      debugPrint('[NailGen] Error capturing nail images: $e');
      if (mounted) {
        Navigator.of(context).pop(<String, String>{});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Parse nail colors and gradients
    final colorMap = _parseVariantColorJson(widget.nail.customColor);
    final fingerColors = <int, String>{};
    final fingerGradients = <int, List<String>?>{};
    for (int i = 1; i <= 5; i++) {
      fingerColors[i] = colorMap[i]?.color ?? '#FF4081';
      fingerGradients[i] = colorMap[i]?.gradient;
    }

    final placements = widget.nail.customerNailComponents
        .map((c) {
          try {
            final config = jsonDecode(c.configJson);
            return PlacedComponentDraft(
              localId: c.customerNailComponentId,
              component:
                  null, // Since we don't have CombinedComponent, we rely on imageUrl directly
              componentId: c.componentId,
              customerComponentId: c.customerComponentId,
              name: c.component?.name ?? c.customerComponent?.name ?? 'Sticker',
              imageUrl:
                  c.component?.imageUrl ?? c.customerComponent?.imageUrl ?? '',
              fingerIndex: c.fingerIndex,
              posX: config['x'] ?? c.posX,
              posY: config['y'] ?? c.posY,
              scale: config['scale'] ?? 1.0,
              rotation: config['rotation'] ?? 0.0,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<PlacedComponentDraft>()
        .toList();

    return Material(
      color: Colors.transparent, // Changed to transparent for opaque_bbox
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. The nails to capture (must be on-screen to paint)
          Align(
            alignment: Alignment.topLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(5, (index) {
                  final fingerIndex = index + 1; // 1 to 5
                  return RepaintBoundary(
                    key: _keys[index],
                    child: SizedBox(
                      width: 250,
                      height: 400,
                      child: FingerPreviewTile(
                        selectedShape: widget.nail.nailShape,
                        selectedSurface: widget.nail.nailSurface,
                        color: fingerColors[fingerIndex]!,
                        gradientStops: fingerGradients[fingerIndex],
                        placements: placements
                            .where(
                              (p) => placementMatchesFinger(
                                p.fingerIndex,
                                fingerIndex,
                              ),
                            )
                            .toList(),
                        selectedPlacementId: null,
                        onSelectPlacement: (_) {},
                        compact: false,
                        transparentBackground: true,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          // 2. An opaque overlay to hide the nails from the user
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Chuẩn bị móng AR...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
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

  Map<int, _FingerAppearance> _parseVariantColorJson(String? jsonString) {
    final Map<int, _FingerAppearance> map = {};
    if (jsonString == null || jsonString.isEmpty) return map;
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final mode = decoded['mode'] as String?;
      if (mode == 'perFinger' && decoded['fingers'] != null) {
        final list = decoded['fingers'] as List;
        for (final item in list) {
          final idx = item['fingerIndex'] as int;
          final c = item['color'] as String?;
          final gRaw = item['gradient'] as List?;
          final g = gRaw?.map((e) => e.toString()).toList();
          map[idx] = _FingerAppearance(color: c, gradient: g);
        }
      } else {
        final c = decoded['color'] as String?;
        final gRaw = decoded['gradient'] as List?;
        final g = gRaw?.map((e) => e.toString()).toList();
        for (int i = 1; i <= 5; i++) {
          map[i] = _FingerAppearance(color: c, gradient: g);
        }
      }
    } catch (_) {}
    return map;
  }
}

class _FingerAppearance {
  final String? color;
  final List<String>? gradient;
  _FingerAppearance({this.color, this.gradient});
}
