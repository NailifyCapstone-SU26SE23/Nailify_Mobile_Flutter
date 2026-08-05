import 'package:flutter/material.dart';
import '../../../generated/l10n.dart';

import '../../../core/di/injection.dart';
import '../../nails/data/models/customer_nail_models.dart';
import '../../nails/services/ar_try_on_service.dart';
import 'snapshot_preview_screen.dart';

import '../models/try_on_data.dart';
import '../../nails/data/models/nail_shape_model.dart';
import '../../nails/data/models/nail_surface_model.dart';
import '../models/placed_component_draft.dart';

class TryOnMethodSelectionScreen extends StatefulWidget {
  final CustomerNailModel previewNail;
  final TryOnData tryOnData;
  final NailShapeModel? selectedShape;
  final NailSurfaceModel? selectedSurface;
  final Map<int, String> fingerColors;
  final Map<int, List<String>?> fingerGradients;
  final List<PlacedComponentDraft> placements;

  const TryOnMethodSelectionScreen({
    super.key,
    required this.previewNail,
    required this.tryOnData,
    required this.selectedShape,
    required this.selectedSurface,
    required this.fingerColors,
    required this.fingerGradients,
    required this.placements,
  });

  @override
  State<TryOnMethodSelectionScreen> createState() =>
      _TryOnMethodSelectionScreenState();
}

class _TryOnMethodSelectionScreenState
    extends State<TryOnMethodSelectionScreen> {
  bool _launching = false;

  // ---- Live Try-on (hành vi cũ) ----
  Future<void> _launchLive() async {
    setState(() => _launching = true);
    try {
      final service = getIt<ArTryOnService>();
      if (!await service.isAvailable()) {
        throw UnsupportedError(
          'Virtual try-on is not available on this build.',
        );
      }
      await service.launchCustomerLive(widget.previewNail);
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  // ---- Snapshot Try-on ----
  Future<void> _launchSnapshot() async {
    setState(() => _launching = true);
    try {
      final service = getIt<ArTryOnService>();
      if (!await service.isAvailable()) {
        throw UnsupportedError(
          'Virtual try-on is not available on this build.',
        );
      }

      // Vòng lặp: mở camera → nếu user bấm "Chụp lại" thì mở camera lại
      // mà KHÔNG đưa user về trang chọn phương thức.
      while (true) {
        final result = await service.launchCustomerSnapshot(widget.previewNail);
        if (!mounted) return;

        // Push màn hình Preview và chờ kết quả
        final action = await Navigator.of(context, rootNavigator: true)
            .push<dynamic>(
              MaterialPageRoute(
                builder: (_) => SnapshotPreviewScreen(
                  snapshot: result,
                  nail: widget.previewNail,
                  tryOnData: widget.tryOnData,
                  selectedShape: widget.selectedShape,
                  selectedSurface: widget.selectedSurface,
                  fingerColors: widget.fingerColors,
                  fingerGradients: widget.fingerGradients,
                  placements: widget.placements,
                ),
              ),
            );

        if (action is SnapshotEditorResult) {
          if (mounted) Navigator.of(context).pop(action);
          break;
        }
        if (action != 'retake') break;
      }
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  // ---- Gallery Snapshot Try-on ----
  Future<void> _launchGallery() async {
    setState(() => _launching = true);
    try {
      final service = getIt<ArTryOnService>();
      if (!await service.isAvailable()) {
        throw UnsupportedError(
          'Virtual try-on is not available on this build.',
        );
      }

      // Vòng lặp: mở gallery → nếu user bấm "Chọn ảnh khác" thì mở gallery lại
      while (true) {
        final result = await service.launchCustomerGallery(widget.previewNail);
        if (!mounted) return;

        // Push màn hình Preview và chờ kết quả
        final action = await Navigator.of(context, rootNavigator: true)
            .push<dynamic>(
              MaterialPageRoute(
                builder: (_) => SnapshotPreviewScreen(
                  snapshot: result,
                  nail: widget.previewNail,
                  tryOnData: widget.tryOnData,
                  selectedShape: widget.selectedShape,
                  selectedSurface: widget.selectedSurface,
                  fingerColors: widget.fingerColors,
                  fingerGradients: widget.fingerGradients,
                  placements: widget.placements,
                  isFromGallery: true,
                ),
              ),
            );

        if (action is SnapshotEditorResult) {
          if (mounted) Navigator.of(context).pop(action);
          break;
        }
        if (action != 'retake') break;
      }
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(S.of(context).selectTryOnMethodTitle),
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Snapshot Try-on
                SizedBox(
                  width: 260,
                  child: FilledButton.tonalIcon(
                    onPressed: _launching ? null : _launchSnapshot,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Snapshot Try-on'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Chụp 1 tấm ảnh bàn tay, AI phân tích rồi ghép móng lên ảnh tĩnh.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 24),

                // Upload ảnh
                SizedBox(
                  width: 260,
                  child: FilledButton.tonalIcon(
                    onPressed: _launching ? null : _launchGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Upload ảnh'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Chọn ảnh bàn tay từ thư viện để AI phân tích rồi ghép móng.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 24),

                // Live Try-on
                SizedBox(
                  width: 260,
                  child: FilledButton.icon(
                    onPressed: _launching ? null : _launchLive,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Live Try-on'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.pink,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Thử móng trực tiếp qua camera theo thời gian thực.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          if (_launching)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x99FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}