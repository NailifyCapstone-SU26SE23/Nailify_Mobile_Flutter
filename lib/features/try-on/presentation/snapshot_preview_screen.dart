import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../nails/data/models/customer_nail_models.dart';
import '../../nails/data/models/nail_shape_model.dart';
import '../../nails/data/models/nail_surface_model.dart';
import '../../nails/services/ar_try_on_service.dart';
import '../models/placed_component_draft.dart';
import '../models/try_on_data.dart';
import '../widgets/try_on_color_selector.dart';
import '../widgets/try_on_preview_board.dart';

/// Kết quả trả về từ màn hình Editor khi người dùng xác nhận thiết kế.
class SnapshotEditorResult {
  final SnapshotResult snapshotResult;
  final NailShapeModel? selectedShape;
  final NailSurfaceModel? selectedSurface;
  final Map<int, String> fingerColors;
  final Map<int, List<String>?> fingerGradients;
  final List<PlacedComponentDraft> placements;

  SnapshotEditorResult({
    required this.snapshotResult,
    required this.selectedShape,
    required this.selectedSurface,
    required this.fingerColors,
    required this.fingerGradients,
    required this.placements,
  });
}

/// Màn hình chỉnh sửa thiết kế sau khi chụp Snapshot.
///
/// - Ảnh bàn tay làm nền (BoxFit.cover).
/// - Khớp tọa độ chuẩn xác bằng phép biến đổi BoxFit.cover.
/// - Sử dụng NailOverlayPreview vẽ dáng móng mask thực tế và phụ kiện.
class SnapshotPreviewScreen extends StatefulWidget {
  final SnapshotResult snapshot;
  final CustomerNailModel nail;
  final TryOnData tryOnData;
  final NailShapeModel? selectedShape;
  final NailSurfaceModel? selectedSurface;
  final Map<int, String> fingerColors;
  final Map<int, List<String>?> fingerGradients;
  final List<PlacedComponentDraft> placements;

  const SnapshotPreviewScreen({
    super.key,
    required this.snapshot,
    required this.nail,
    required this.tryOnData,
    this.selectedShape,
    this.selectedSurface,
    required this.fingerColors,
    required this.fingerGradients,
    required this.placements,
  });

  @override
  State<SnapshotPreviewScreen> createState() => _SnapshotPreviewScreenState();
}

class _SnapshotPreviewScreenState extends State<SnapshotPreviewScreen> {
  late NailShapeModel? _selectedShape;
  late NailSurfaceModel? _selectedSurface;
  late final List<PlacedComponentDraft> _placements;
  late final Map<int, String> _fingerColors;
  late final Map<int, List<String>?> _fingerGradients;

  int _activeTab = 0; // 0: Dáng móng, 1: Màu sắc, 2: Phụ kiện
  int _selectedFingerIndex = -1; // -1 = tất cả

  String get _activeFingerColor =>
      _fingerColors[_selectedFingerIndex == -1 ? 2 : _selectedFingerIndex] ??
      '#FF4081';

  @override
  void initState() {
    super.initState();
    _selectedShape = widget.selectedShape;
    _selectedSurface = widget.selectedSurface;
    _fingerColors = Map<int, String>.from(widget.fingerColors);
    _fingerGradients = Map<int, List<String>?>.from(widget.fingerGradients);
    _placements = List<PlacedComponentDraft>.from(widget.placements);
  }

  void _goBack() {
    Navigator.of(context).pop(
      SnapshotEditorResult(
        snapshotResult: widget.snapshot,
        selectedShape: _selectedShape,
        selectedSurface: _selectedSurface,
        fingerColors: _fingerColors,
        fingerGradients: _fingerGradients,
        placements: _placements,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.snapshot.hasHand) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.pan_tool_outlined,
                  color: Colors.white70,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Không phát hiện bàn tay trong ảnh.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Đảm bảo bàn tay nằm trong khung và thử chụp lại.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop('retake'),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Chụp lại'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF69B4),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    const double panelHeight = 230.0;
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // ── Vùng ảnh + overlay móng ────────────────────────────────
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Ảnh bàn tay làm nền
                Image.file(
                  File(widget.snapshot.imagePath),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),

                // Overlay móng từ landmarks
                LayoutBuilder(
                  builder: (ctx, box) {
                    return _buildNailOverlay(box.maxWidth, box.maxHeight);
                  },
                ),

                // Gradient trên cho dễ đọc tiêu đề
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: topPad + 68,
                  child: IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),

                // Nút Back
                Positioned(
                  top: topPad + 8,
                  left: 12,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _goBack,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),

                // Tiêu đề
                Positioned(
                  top: topPad + 14,
                  left: 56,
                  right: 56,
                  child: const IgnorePointer(
                    child: Center(
                      child: Text(
                        'Tùy chỉnh trên ảnh chụp 📸',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Panel chỉnh sửa ────────────────────────────────────────
          SizedBox(
            height: panelHeight + botPad,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xEE111111),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                children: [
                  // Nội dung tab
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: _buildTabContent(),
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  // Tab bar
                  Padding(
                    padding: EdgeInsets.only(
                      top: 10,
                      bottom: botPad > 0 ? botPad : 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _tab(0, Icons.gesture_rounded, 'Dáng móng'),
                        _tab(1, Icons.palette_rounded, 'Màu sắc'),
                        _tab(2, Icons.auto_awesome_rounded, 'Phụ kiện'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Nail Overlay (BoxFit.cover math)
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildNailOverlay(double sw, double sh) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final lm in widget.snapshot.landmarks) ...[
          _nailWidget(lm, sw, sh),
        ],
      ],
    );
  }

  Widget _nailWidget(FingerLandmark lm, double sw, double sh) {
    final finger = lm.fingerIndex + 1;

    final double imgW = lm.imageWidth > 0 ? lm.imageWidth.toDouble() : 1024.0;
    final double imgH = lm.imageHeight > 0 ? lm.imageHeight.toDouble() : 1024.0;

    // Phép biến đổi BoxFit.cover hoàn chỉnh
    final double scale = math.max(sw / imgW, sh / imgH);
    final double scaledW = imgW * scale;
    final double scaledH = imgH * scale;

    final double dx = (sw - scaledW) / 2;
    final double dy = (sh - scaledH) / 2;

    // Hướng gốc (chưa +90°) — hướng từ khớp ra đầu ngón, dùng để lùi điểm neo
    final dirRad = lm.baseRotation;

    // Tỉ lệ scale móng đúng theo zoom ảnh
    final fingerLen = lm.baseScale * scale;

    // Điểm tip gốc (baseX/baseY từ native là toạ độ ĐẦU NGÓN, không phải
    // tâm móng), map theo BoxFit.cover
    final tipX = lm.baseX * scale + dx;
    final tipY = lm.baseY * scale + dy;

    // FIX: lùi điểm neo vào trong ngón ~35% chiều dài đốt cuối, để móng
    // không trồi hẳn ra ngoài đầu ngón thật (trước đây neo thẳng vào tip
    // khiến móng "bay" ra ngoài rìa ngón).
    final anchorShift = fingerLen * 0.35;
    final cx = tipX - anchorShift * math.cos(dirRad);
    final cy = tipY - anchorShift * math.sin(dirRad);

    // FIX: baseRotation từ native dùng atan2 (0° = hướng phải, ngón thẳng
    // đứng ≈ -90°). Ảnh móng mặc định vẽ theo chiều "thẳng đứng" (0° = lên),
    // nên cần cộng thêm +90° NGAY TỪ ĐÂY để dùng CHUNG một góc cho cả phép
    // tính vị trí (left/top) lẫn Transform.rotate bên dưới. Trước đây 2 chỗ
    // dùng 2 góc khác nhau (rad vs rad+90°) khiến móng bị lệch vị trí.
    final rad = dirRad + math.pi / 2;
    final angleDeg = rad * 180 / math.pi;

    // FIX: giảm hệ số kích thước — móng cũ (1.6 / 1.3) quá to so với móng
    // thật. Tinh chỉnh thêm theo bộ ảnh dáng móng thực tế nếu cần.
    final nailW = fingerLen * 0.85;
    final nailH = fingerLen * 0.8;

    // Top-left của khung móng (đồng bộ với góc `rad` đã cộng offset ở trên)
    final left = cx - nailW / 2 + (nailH / 2) * math.sin(rad);
    final top = cy - nailH / 2 - (nailH / 2) * math.cos(rad);

    // Bỏ qua ngón tay nằm ngoài vùng hiển thị thực tế
    if (left + nailW < -20 ||
        left > sw + 20 ||
        top + nailH < -20 ||
        top > sh + 20) {
      return const SizedBox.shrink();
    }

    final isSelected = _selectedFingerIndex == finger;
    final hexColor = _fingerColors[finger] ?? '#FF4081';
    final gradient = _fingerGradients[finger];

    return Positioned(
      left: left,
      top: top,
      width: nailW,
      height: nailH,
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedFingerIndex = isSelected ? -1 : finger;
        }),
        child: Transform.rotate(
          angle: angleDeg * math.pi / 180,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white24,
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: NailOverlayPreview(
              selectedShape: _selectedShape,
              selectedSurface: _selectedSurface,
              color: hexColor,
              gradientStops: gradient,
              placements: _placements
                  .where((p) => p.fingerIndex == finger)
                  .toList(),
              showShadow: false,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Tab Helpers & Content
  // ─────────────────────────────────────────────────────────────────────

  Widget _tab(int idx, IconData icon, String label) {
    final active = _activeTab == idx;
    const activeColor = Color(0xFFFF4081);
    return GestureDetector(
      onTap: () => setState(() => _activeTab = idx),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? activeColor : Colors.white60, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? activeColor : Colors.white60,
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      // ── Dáng móng ──────────────────────────────────────────────────
      case 0:
        final shapes = widget.tryOnData.nailShapes;
        if (shapes.isEmpty) {
          return const Center(
            child: Text(
              'Không có dáng móng.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: shapes.length,
          itemBuilder: (_, i) {
            final shape = shapes[i];
            final isSel = _selectedShape?.nailShapeId == shape.nailShapeId;
            return GestureDetector(
              onTap: () => setState(() => _selectedShape = shape),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 76,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: isSel
                      ? const Color(0x44FF4081)
                      : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSel ? const Color(0xFFFF4081) : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (shape.imageUrl.isNotEmpty)
                      Image.network(
                        shape.imageUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.gesture, color: Colors.white54),
                      )
                    else
                      const Icon(Icons.gesture, color: Colors.white54),
                    const SizedBox(height: 6),
                    Text(
                      shape.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        );

      // ── Màu sắc ────────────────────────────────────────────────────
      case 1:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedFingerIndex == -1
                  ? '🎨  Áp dụng cho tất cả ngón tay'
                  : '🎨  Đang chọn: Ngón $_selectedFingerIndex  (tap móng để đổi)',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ColorSpectrumSlider(
              selectedColor: _activeFingerColor,
              onColorSelected: (color) {
                setState(() {
                  if (_selectedFingerIndex == -1) {
                    for (var i = 1; i <= 5; i++) {
                      _fingerColors[i] = color;
                      _fingerGradients[i] = null;
                    }
                  } else {
                    _fingerColors[_selectedFingerIndex] = color;
                    _fingerGradients[_selectedFingerIndex] = null;
                  }
                });
              },
            ),
          ],
        );

      // ── Phụ kiện ──────────────────────────────────────────────────
      case 2:
        final comps = widget.tryOnData.combinedComponents;
        if (comps.isEmpty) {
          return const Center(
            child: Text(
              'Chưa có phụ kiện.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: comps.length,
          itemBuilder: (_, i) {
            final comp = comps[i];
            return GestureDetector(
              onTap: () {
                final finger = _selectedFingerIndex == -1
                    ? 2
                    : _selectedFingerIndex;
                final count = _placements
                    .where((p) => p.fingerIndex == finger)
                    .length;
                setState(() {
                  _placements.add(
                    PlacedComponentDraft(
                      localId: DateTime.now().millisecondsSinceEpoch,
                      componentId: comp.componentId,
                      name: comp.name,
                      imageUrl: comp.imageUrl,
                      posX: 0.0,
                      posY: -0.1 - count * 0.06,
                      scale: 0.35,
                      rotation: 0.0,
                      fingerIndex: finger,
                    ),
                  );
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã thêm ${comp.name} vào ngón $finger'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: const Color(0xFFFF4081),
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 76,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (comp.imageUrl.isNotEmpty)
                      Image.network(
                        comp.imageUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.star, color: Colors.white54),
                      )
                    else
                      const Icon(Icons.star, color: Colors.white54),
                    const SizedBox(height: 6),
                    Text(
                      comp.name,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        );

      default:
        return const SizedBox.shrink();
    }
  }
}