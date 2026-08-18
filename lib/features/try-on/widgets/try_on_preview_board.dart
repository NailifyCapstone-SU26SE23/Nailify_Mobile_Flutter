import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../nails/data/models/customer_nail_models.dart';
import '../../nails/data/models/nail_shape_model.dart';
import '../../nails/data/models/nail_surface_model.dart';
import '../models/placed_component_draft.dart';
import '../utils/try_on_setup_helpers.dart';

class TryOnPreviewBoard extends StatefulWidget {
  final CustomerNailModel? nail;
  final NailShapeModel? selectedShape;
  final NailSurfaceModel? selectedSurface;
  final String selectedColor;
  final List<String>? gradientStops;
  final Map<int, String> fingerColors;
  final Map<int, List<String>?> fingerGradients;
  final int selectedFingerIndex;
  final int? detailFingerIndex;
  final List<PlacedComponentDraft> placements;
  final int? selectedPlacementId;
  final ValueChanged<int> onSelectPlacement;
  final ValueChanged<int>? onToggleDetailFinger;
  final VoidCallback? onApplyToAll;

  final ValueChanged<PlacedComponentDraft> onUpdatePlacement;
  final ValueChanged<int> onDeletePlacement;

  const TryOnPreviewBoard({
    super.key,
    required this.nail,
    required this.selectedShape,
    required this.selectedSurface,
    required this.selectedColor,
    required this.gradientStops,
    required this.fingerColors,
    required this.fingerGradients,
    required this.selectedFingerIndex,
    required this.detailFingerIndex,
    required this.placements,
    required this.selectedPlacementId,
    required this.onSelectPlacement,
    required this.onUpdatePlacement,
    required this.onDeletePlacement,
    this.onToggleDetailFinger,
    this.onApplyToAll,
  });

  @override
  State<TryOnPreviewBoard> createState() => _TryOnPreviewBoardState();
}

class _TryOnPreviewBoardState extends State<TryOnPreviewBoard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  int _animatingFingerIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    final initialFinger = _getEffectiveFingerIndex(widget.selectedFingerIndex, widget.detailFingerIndex);
    if (initialFinger != -1) {
      _animatingFingerIndex = initialFinger;
      _controller.value = 1.0;
    }

    _controller.addListener(() {
      setState(() {});
    });
  }

  int _getEffectiveFingerIndex(int selected, int? detail) {
    if (selected != -1) return selected;
    if (detail != null) return detail;
    return -1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TryOnPreviewBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFinger = _getEffectiveFingerIndex(oldWidget.selectedFingerIndex, oldWidget.detailFingerIndex);
    final newFinger = _getEffectiveFingerIndex(widget.selectedFingerIndex, widget.detailFingerIndex);

    if (oldFinger != newFinger) {
      if (newFinger != -1) {
        setState(() {
          _animatingFingerIndex = newFinger;
        });
        _controller.forward(from: _controller.value);
      } else {
        _controller.reverse(from: _controller.value).then((_) {
          if (mounted && _controller.value == 0.0) {
            setState(() {
              _animatingFingerIndex = -1;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.onSelectPlacement(-1);
        },
        child: AspectRatio(
          aspectRatio: 1.0, // Fixed 1.0 Aspect Ratio for perfectly aligned and smooth transitions
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(16),
            ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final double height = constraints.maxHeight;
              if (width <= 0 || height <= 0) return const SizedBox.expand();

              final t = _animation.value;

              // Calculate dynamic zoom size based on nail shape aspect ratio to prevent screen overflow
              final cached = widget.selectedShape?.imageUrl.isNotEmpty == true
                  ? _NailImageCache._resolved[widget.selectedShape!.imageUrl]
                  : null;
              final double nailAspectRatio = cached != null
                  ? cached.contentRect.width / cached.contentRect.height
                  : 0.35;

              final double maxZoomWidth = width * 0.42; // Up to 42% of preview board width
              final double maxZoomHeight = height * 0.72; // Up to 72% of preview board height

              double detailWidth = maxZoomWidth;
              double detailHeight = detailWidth / nailAspectRatio;

              if (detailHeight > maxZoomHeight) {
                detailHeight = maxZoomHeight;
                detailWidth = detailHeight * nailAspectRatio;
              }

              final double detailLeft = (width - detailWidth) / 2;
              final double detailTop = (height - detailHeight) / 2;

              // Calibrated finger config bounds on 1024x1024 template
              // Positioned mathematically using cuticle center (cx, cy) and rotation angle
              final List<Map<String, dynamic>> fingerConfigs = [
                {
                  'finger': 1, // Ngón cái
                  'cx': 0.242,
                  'cy': 0.485,
                  'w': 0.0781,
                  'h': 0.1074,
                  'angle': -30.0,
                },
                {
                  'finger': 2, // Ngón trỏ
                  'cx': 0.374,
                  'cy': 0.2497,
                  'w': 0.0664,
                  'h': 0.0928,
                  'angle': -6.0,
                },
                {
                  'finger': 3, // Ngón giữa
                  'cx': 0.5087,
                  'cy': 0.2061,
                  'w': 0.0703,
                  'h': 0.0928,
                  'angle': 0.0,
                },
                {
                  'finger': 4, // Ngón áp út
                  'cx': 0.6352,
                  'cy': 0.2645,
                  'w': 0.0635,
                  'h': 0.0928,
                  'angle': 5.0,
                },
                {
                  'finger': 5, // Ngón út
                  'cx': 0.7460,
                  'cy': 0.4021,
                  'w': 0.0605,
                  'h': 0.0977,
                  'angle': 13.0,
                },
              ].map((cfg) {
                final angle = cfg['angle'] as double;
                final rad = angle * math.pi / 180;
                final cx = cfg['cx'] as double;
                final cy = cfg['cy'] as double;
                final w = cfg['w'] as double;
                final h = cfg['h'] as double;

                // Rotated bottom-center math to find top-left:
                // L = cx - w/2 + (h/2) * sin(theta)
                // T = cy - h/2 - (h/2) * cos(theta)
                final leftRatio = cx - w / 2 + (h / 2) * math.sin(rad);
                final topRatio = cy - h / 2 - (h / 2) * math.cos(rad);

                return {
                  'finger': cfg['finger'],
                  'left': width * leftRatio,
                  'top': height * topRatio,
                  'width': width * w,
                  'height': height * h,
                  'angle': angle,
                };
              }).toList();

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Hand Template Background
                  if (t < 1.0)
                    Positioned.fill(
                      child: Opacity(
                        opacity: (1.0 - t).clamp(0.0, 1.0),
                        child: RepaintBoundary(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/images/try_on_hand_template.png',
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, st) => Container(
                                color: const Color(0xFFFDE8F0),
                                child: const Center(
                                  child: Icon(Icons.pan_tool_outlined, color: Color(0xFFFFB6C1), size: 80),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 2. Inactive Fingers
                  for (final cfg in fingerConfigs) ...[
                    if (cfg['finger'] != _animatingFingerIndex)
                      Positioned(
                        left: cfg['left'] as double,
                        top: cfg['top'] as double,
                        width: cfg['width'] as double,
                        height: cfg['height'] as double,
                        child: Opacity(
                          opacity: (1.0 - t).clamp(0.0, 1.0),
                          child: _FingerSlot(
                            width: cfg['width'] as double,
                            height: cfg['height'] as double,
                            angle: cfg['angle'] as double,
                            fingerIndex: cfg['finger'] as int,
                            selectedShape: widget.selectedShape,
                            selectedSurface: widget.selectedSurface,
                            color: widget.fingerColors[cfg['finger']] ?? '#FF4081',
                            gradientStops: widget.fingerGradients[cfg['finger']],
                            placements: widget.placements
                                .where((p) => placementMatchesFinger(p.fingerIndex, cfg['finger'] as int))
                                .toList(),
                            onToggleDetailFinger: t > 0.1 ? null : widget.onToggleDetailFinger,
                            onUpdatePlacement: widget.onUpdatePlacement,
                            onDeletePlacement: widget.onDeletePlacement,
                          ),
                        ),
                      ),
                  ],

                  // 3. Zooming/Interpolating Active Finger
                  if (_animatingFingerIndex != -1)
                    Positioned(
                      left: ui.lerpDouble(
                        fingerConfigs.firstWhere((c) => c['finger'] == _animatingFingerIndex)['left'] as double,
                        detailLeft,
                        t,
                      )!,
                      top: ui.lerpDouble(
                        fingerConfigs.firstWhere((c) => c['finger'] == _animatingFingerIndex)['top'] as double,
                        detailTop,
                        t,
                      )!,
                      width: ui.lerpDouble(
                        fingerConfigs.firstWhere((c) => c['finger'] == _animatingFingerIndex)['width'] as double,
                        detailWidth,
                        t,
                      )!,
                      height: ui.lerpDouble(
                        fingerConfigs.firstWhere((c) => c['finger'] == _animatingFingerIndex)['height'] as double,
                        detailHeight,
                        t,
                      )!,
                      child: _FingerSlot(
                        width: ui.lerpDouble(
                          fingerConfigs.firstWhere((c) => c['finger'] == _animatingFingerIndex)['width'] as double,
                          detailWidth,
                          t,
                        )!,
                        height: ui.lerpDouble(
                          fingerConfigs.firstWhere((c) => c['finger'] == _animatingFingerIndex)['height'] as double,
                          detailHeight,
                          t,
                        )!,
                        angle: ui.lerpDouble(
                          fingerConfigs.firstWhere((c) => c['finger'] == _animatingFingerIndex)['angle'] as double,
                          0.0,
                          t,
                        )!,
                        fingerIndex: _animatingFingerIndex,
                        selectedShape: widget.selectedShape,
                        selectedSurface: widget.selectedSurface,
                        color: widget.fingerColors[_animatingFingerIndex] ?? '#FF4081',
                        gradientStops: widget.fingerGradients[_animatingFingerIndex],
                        placements: widget.placements
                            .where((p) => placementMatchesFinger(p.fingerIndex, _animatingFingerIndex))
                            .toList(),
                        isZoomed: t > 0.9,
                        selectedPlacementId: widget.selectedPlacementId,
                        onSelectPlacement: widget.onSelectPlacement,
                        onToggleDetailFinger: t > 0.9 ? widget.onToggleDetailFinger : null,
                        onUpdatePlacement: widget.onUpdatePlacement,
                        onDeletePlacement: widget.onDeletePlacement,
                      ),
                    ),

                  // 4. Zoomed Active Finger Placements (Rendered in the main Stack of TryOnPreviewBoard to avoid hit-test boundary clipping!)
                  if (_animatingFingerIndex != -1 && t > 0.9 && widget.selectedShape?.imageUrl.isNotEmpty == true)
                    ...widget.placements
                        .where((p) => placementMatchesFinger(p.fingerIndex, _animatingFingerIndex))
                        .map((placement) {
                      final size = (detailWidth * placement.scale.clamp(0.1, 2.5)).clamp(4.0, double.infinity);
                      final centerX = detailLeft + detailWidth / 2 + placement.posX * detailWidth;
                      final centerY = detailTop + detailHeight / 2 + placement.posY * detailHeight;
                      
                      return _PlacedComponentPreview(
                        placement: placement,
                        selected: widget.selectedPlacementId == placement.localId,
                        size: size,
                        left: centerX - size / 2 - 12.0,
                        top: centerY - size / 2 - 12.0,
                        nailWidth: detailWidth,
                        nailHeight: detailHeight,
                        compact: false,
                        onSelectPlacement: widget.onSelectPlacement,
                        onUpdate: widget.onUpdatePlacement,
                        onDelete: () => widget.onDeletePlacement(placement.localId),
                        selectedShape: widget.selectedShape,
                      );
                    }),

                  // 5. Detail UI Back Button (Left side)
                  if (t > 0.0)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Opacity(
                        opacity: t,
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: t > 0.9 ? () => widget.onToggleDetailFinger?.call(-1) : null,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFFE91E63)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Bàn tay',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Color(0xFFE91E63),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 6. Detail UI Apply to All Button (Right side)
                  if (t > 0.0)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Opacity(
                        opacity: t,
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: t > 0.9 ? widget.onApplyToAll : null,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.copy_all_rounded, size: 16, color: Color(0xFFE91E63)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Áp dụng tất cả',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Color(0xFFE91E63),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
}

class _FingerSlot extends StatelessWidget {
  final double width;
  final double height;
  final double angle;
  final int fingerIndex;
  final NailShapeModel? selectedShape;
  final NailSurfaceModel? selectedSurface;
  final String color;
  final List<String>? gradientStops;
  final List<PlacedComponentDraft> placements;
  final ValueChanged<int>? onToggleDetailFinger;
  final bool isZoomed;
  final int? selectedPlacementId;
  final ValueChanged<int>? onSelectPlacement;

  final ValueChanged<PlacedComponentDraft> onUpdatePlacement;
  final ValueChanged<int> onDeletePlacement;

  const _FingerSlot({
    required this.width,
    required this.height,
    required this.angle,
    required this.fingerIndex,
    required this.selectedShape,
    required this.selectedSurface,
    required this.color,
    required this.gradientStops,
    required this.placements,
    required this.onUpdatePlacement,
    required this.onDeletePlacement,
    this.onToggleDetailFinger,
    this.isZoomed = false,
    this.selectedPlacementId,
    this.onSelectPlacement,
  });

  @override
  Widget build(BuildContext context) {
    Widget overlay = NailOverlayPreview(
      selectedShape: selectedShape,
      selectedSurface: selectedSurface,
      color: color,
      gradientStops: gradientStops,
      placements: isZoomed ? const [] : placements,
      showShadow: isZoomed,
    );

    if (!isZoomed && onToggleDetailFinger != null) {
      overlay = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onToggleDetailFinger!.call(fingerIndex),
        child: overlay,
      );
    }

    Widget slot = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: isZoomed,
            child: RepaintBoundary(
              child: overlay,
            ),
          ),
        ),
        if (!isZoomed && selectedShape?.imageUrl.isNotEmpty == true)
          ...placements.map((placement) {
            final nailWidth = width;
            final nailHeight = height;
            final size = (nailWidth * placement.scale.clamp(0.1, 2.5)).clamp(4.0, double.infinity);
            final centerX = nailWidth / 2 + placement.posX * nailWidth;
            final centerY = nailHeight / 2 + placement.posY * nailHeight;

            Widget icon = placement.imageUrl.isEmpty
                ? const Icon(Icons.auto_awesome, color: Colors.purple, size: 10)
                : Image.network(
                    placement.imageUrl,
                    fit: BoxFit.contain,
                    cacheWidth: 100,
                    cacheHeight: 100,
                    errorBuilder: (context, error, stackTrace) => const SizedBox(),
                  );

            if (placement.rotation != 0) {
              icon = Transform.rotate(
                angle: placement.rotation * 3.14159265359 / 180,
                child: icon,
              );
            }

            return _PlacedComponentPreview(
              placement: placement,
              selected: selectedPlacementId == placement.localId,
              size: size,
              left: centerX - size / 2 - (isZoomed ? 12.0 : 0.0),
              top: centerY - size / 2 - (isZoomed ? 12.0 : 0.0),
              nailWidth: nailWidth,
              nailHeight: nailHeight,
              compact: !isZoomed,
              onSelectPlacement: onSelectPlacement ?? (_) {},
              onUpdate: onUpdatePlacement,
              onDelete: () => onDeletePlacement(placement.localId),
              selectedShape: selectedShape,
            );
          }),
      ],
    );

    if (angle != 0) {
      slot = Transform.rotate(
        angle: angle * 3.14159265359 / 180,
        child: slot,
      );
    }

    return slot;
  }
}

class _PlacedComponentPreview extends StatefulWidget {
  final PlacedComponentDraft placement;
  final bool selected;
  final double size;
  final double left;
  final double top;
  final double nailWidth;
  final double nailHeight;
  final bool compact;
  final ValueChanged<int> onSelectPlacement;
  final ValueChanged<PlacedComponentDraft> onUpdate;
  final VoidCallback onDelete;
  final NailShapeModel? selectedShape;

  const _PlacedComponentPreview({
    required this.placement,
    required this.selected,
    required this.size,
    required this.left,
    required this.top,
    required this.nailWidth,
    required this.nailHeight,
    required this.compact,
    required this.onSelectPlacement,
    required this.onUpdate,
    required this.onDelete,
    required this.selectedShape,
  });

  @override
  State<_PlacedComponentPreview> createState() => _PlacedComponentPreviewState();
}

class _PlacedComponentPreviewState extends State<_PlacedComponentPreview> {
  double _initialScale = 1.0;
  double _initialRotation = 0.0;
  double _initialDistance = 1.0;
  double _initialAngle = 0.0;

  // Track drag start state for precise movement alignment
  Offset? _startGlobalPosition;
  double _startPosX = 0.0;
  double _startPosY = 0.0;

  bool _isPixelOnNail(double posX, double posY, CachedNailImage cached) {
    final contentRect = cached.contentRect;
    final img = cached.image;
    final byteData = cached.byteData;

    // Convert relative posX/posY (range -0.5 to 0.5) based on contentRect back to original image pixel coordinate
    final double pixelX = contentRect.left + contentRect.width * (0.5 + posX);
    final double pixelY = contentRect.top + contentRect.height * (0.5 + posY);

    final int x = pixelX.round();
    final int y = pixelY.round();

    if (x < 0 || x >= img.width || y < 0 || y >= img.height) {
      return false;
    }

    final int offset = (y * img.width + x) * 4;
    if (offset + 3 >= byteData.lengthInBytes) return false;
    
    final int alpha = byteData.getUint8(offset + 3);
    return alpha > 10; // Non-transparent pixel (threshold > 10)
  }

  bool _isPlacementOnNail(double posX, double posY, CachedNailImage cached) {
    // 1. Check center point
    if (!_isPixelOnNail(posX, posY, cached)) return false;

    // 2. Check 4 edge points based on accessory scale to prevent overflowing the boundary.
    // We check points at 30% of the accessory's relative radius for a balanced margin.
    final double radius = widget.placement.scale * 0.5 * 0.3;

    if (!_isPixelOnNail(posX - radius, posY, cached)) return false;
    if (!_isPixelOnNail(posX + radius, posY, cached)) return false;
    if (!_isPixelOnNail(posX, posY - radius, cached)) return false;
    if (!_isPixelOnNail(posX, posY + radius, cached)) return false;

    return true;
  }

  @override
  Widget build(BuildContext context) {
    // We add 12.0 logical pixels margin on each side to keep control handles inside the hit-test bounds when zoomed
    final double margin = widget.compact ? 0.0 : 12.0;
    final double widgetSize = widget.size + margin * 2;

    Widget content = Stack(
      clipBehavior: Clip.none,
      children: [
        // Center accessory image with Pan (drag to move) gesture
        Positioned(
          left: margin,
          top: margin,
          width: widget.size,
          height: widget.size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onSelectPlacement(widget.placement.localId),
            onPanStart: (details) {
              widget.onSelectPlacement(widget.placement.localId);
              _startGlobalPosition = details.globalPosition;
              _startPosX = widget.placement.posX;
              _startPosY = widget.placement.posY;
            },
            onPanUpdate: (details) {
              if (_startGlobalPosition == null) return;
              final double dx = (details.globalPosition.dx - _startGlobalPosition!.dx) / widget.nailWidth;
              final double dy = (details.globalPosition.dy - _startGlobalPosition!.dy) / widget.nailHeight;

              final double targetPosX = (_startPosX + dx).clamp(-0.8, 0.8);
              final double targetPosY = (_startPosY + dy).clamp(-0.8, 0.8);

              final cached = widget.selectedShape != null
                  ? _NailImageCache._resolved[widget.selectedShape!.imageUrl]
                  : null;

              if (cached != null) {
                if (_isPlacementOnNail(targetPosX, targetPosY, cached)) {
                  widget.onUpdate(
                    widget.placement.copyWith(
                      posX: targetPosX,
                      posY: targetPosY,
                    ),
                  );
                } else {
                  // Sliding collision check: Try updating only X or only Y axis for smooth edge sliding
                  final bool xValid = _isPlacementOnNail(targetPosX, widget.placement.posY, cached);
                  final bool yValid = _isPlacementOnNail(widget.placement.posX, targetPosY, cached);

                  if (xValid) {
                    widget.onUpdate(widget.placement.copyWith(posX: targetPosX));
                  } else if (yValid) {
                    widget.onUpdate(widget.placement.copyWith(posY: targetPosY));
                  }
                }
              } else {
                // Fallback if image cache is not ready
                widget.onUpdate(
                  widget.placement.copyWith(
                    posX: targetPosX,
                    posY: targetPosY,
                  ),
                );
              }
            },
            child: Container(
              padding: EdgeInsets.all(widget.compact ? 1 : 2),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: widget.selected ? const Color(0xFFE91E63) : Colors.transparent,
                  width: widget.selected ? 1.5 : 0,
                ),
                borderRadius: BorderRadius.circular(widget.compact ? 3 : 6),
              ),
              child: widget.placement.imageUrl.isEmpty
                  ? Icon(
                      Icons.auto_awesome_outlined,
                      color: const Color(0xFFE91E63),
                      size: widget.compact ? 12 : 16,
                    )
                  : Image.network(
                      widget.placement.imageUrl,
                      fit: BoxFit.contain,
                      cacheWidth: 100,
                      cacheHeight: 100,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.auto_awesome_outlined,
                        color: const Color(0xFFE91E63),
                        size: widget.compact ? 12 : 16,
                      ),
                    ),
            ),
          ),
        ),

        // Delete button handle (Top-Left corner of the widget box)
        if (widget.selected && !widget.compact)
          Positioned(
            top: 0,
            left: 0,
            width: 24,
            height: 24,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => widget.onDelete(),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFFE91E63),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),

        // Scale & Rotate drag handle (Bottom-Right corner of the widget box)
        if (widget.selected && !widget.compact)
          Positioned(
            bottom: 0,
            right: 0,
            width: 24,
            height: 24,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                widget.onSelectPlacement(widget.placement.localId);
                final box = context.findRenderObject() as RenderBox;
                final localPos = box.globalToLocal(details.globalPosition);
                final center = Offset(widgetSize / 2, widgetSize / 2);
                final vector = localPos - center;
                
                _initialDistance = vector.distance;
                _initialAngle = math.atan2(vector.dy, vector.dx);
                _initialScale = widget.placement.scale;
                _initialRotation = widget.placement.rotation;
              },
              onPanUpdate: (details) {
                final box = context.findRenderObject() as RenderBox;
                final localPos = box.globalToLocal(details.globalPosition);
                final center = Offset(widgetSize / 2, widgetSize / 2);
                final vector = localPos - center;
                
                final currentDistance = vector.distance;
                final currentAngle = math.atan2(vector.dy, vector.dx);
                
                final scaleFactor = _initialDistance > 0 ? (currentDistance / _initialDistance) : 1.0;
                final newScale = (_initialScale * scaleFactor).clamp(0.15, 2.5);
                
                final angleDiffRad = currentAngle - _initialAngle;
                final angleDiffDeg = angleDiffRad * 180 / math.pi;
                final newRotation = (_initialRotation + angleDiffDeg) % 360;

                widget.onUpdate(
                  widget.placement.copyWith(
                    scale: newScale,
                    rotation: newRotation,
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFFE91E63),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
                  ],
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.placement.rotation != 0) {
      content = Transform.rotate(
        angle: widget.placement.rotation * math.pi / 180,
        child: content,
      );
    }

    return Positioned(
      left: widget.left,
      top: widget.top,
      width: widgetSize,
      height: widgetSize,
      child: content,
    );
  }
}

class CachedNailImage {
  final ui.Image image;
  final Rect contentRect;
  final ByteData byteData;
  CachedNailImage(this.image, this.contentRect, this.byteData);
}

class _NailImageCache {
  static final Map<String, CachedNailImage> _resolved = {};
  static final Map<String, Future<CachedNailImage>> _pending = {};

  static Future<CachedNailImage> load(String url) {
    final cached = _resolved[url];
    if (cached != null) return Future.value(cached);

    final pending = _pending[url];
    if (pending != null) return pending;

    final completer = Completer<CachedNailImage>();
    final stream = NetworkImage(url).resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, synchronousCall) async {
        try {
          final img = info.image;
          final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
          if (byteData == null) {
            throw Exception("Failed to get byte data from image");
          }
          final rect = _calculateContentRect(img, byteData);
          final cachedImage = CachedNailImage(img, rect, byteData);
          _resolved[url] = cachedImage;
          _pending.remove(url);
          if (!completer.isCompleted) completer.complete(cachedImage);
        } catch (e, stack) {
          _pending.remove(url);
          if (!completer.isCompleted) completer.completeError(e, stack);
        }
        stream.removeListener(listener);
      },
      onError: (error, stackTrace) {
        _pending.remove(url);
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    _pending[url] = completer.future;
    return completer.future;
  }

  static Rect _calculateContentRect(ui.Image img, ByteData byteData) {
    final width = img.width;
    final height = img.height;
    int minX = width;
    int maxX = 0;
    int minY = height;
    int maxY = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final offset = (y * width + x) * 4;
        final alpha = byteData.getUint8(offset + 3);
        if (alpha > 5) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX < minX || maxY < minY) {
      return Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    }
    return Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    );
  }
}

class _NailColorPreview extends StatelessWidget {
  final String imageUrl;
  final String color;
  final List<String>? gradientStops;
  final NailSurfaceModel? surface;
  final bool showShadow;

  const _NailColorPreview({
    required this.imageUrl,
    required this.color,
    required this.gradientStops,
    required this.surface,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = _applySurfaceOffsets(parseTryOnHexColor(color), surface);
    final stops = gradientStops;
    final adjustedStops = (stops != null && stops.length >= 2)
        ? stops
            .take(3)
            .map((item) => _applySurfaceOffsets(parseTryOnHexColor(item), surface))
            .toList()
        : null;
    final shaderParams = _SurfaceShader.fromSurface(surface);

    return FutureBuilder<CachedNailImage>(
      future: _NailImageCache.load(imageUrl),
      builder: (context, snapshot) {
        final cached = snapshot.data;
        if (cached == null) return const SizedBox.shrink();
        return CustomPaint(
          size: Size.infinite,
          painter: _NailPainter(
            image: cached.image,
            contentRect: cached.contentRect,
            baseColor: baseColor,
            gradientColors: adjustedStops,
            shader: shaderParams,
            showShadow: showShadow,
          ),
        );
      },
    );
  }
}

class _NailPainter extends CustomPainter {
  final ui.Image image;
  final Rect contentRect;
  final Color baseColor;
  final List<Color>? gradientColors;
  final _SurfaceShader shader;
  final bool showShadow;

  _NailPainter({
    required this.image,
    required this.contentRect,
    required this.baseColor,
    required this.gradientColors,
    required this.shader,
    required this.showShadow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double destWidth = size.width;
    final double destHeight = contentRect.height * (size.width / contentRect.width);

    final srcRect = contentRect;
    final destRect = Rect.fromLTWH(
      0,
      size.height - destHeight,
      destWidth,
      destHeight,
    );

    // Draw a custom blurred drop shadow matching the nail shape boundaries (only when showShadow is true)
    if (showShadow) {
      final shadowPaint = Paint()
        ..colorFilter = ColorFilter.mode(Colors.black.withValues(alpha: 0.12), BlendMode.srcIn)
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5);
      canvas.drawImageRect(
        image,
        srcRect,
        destRect.translate(0, 4),
        shadowPaint,
      );
    }

    // Expand the layer bounds to include the entire destRect to prevent cropping
    final bounds = (Offset.zero & size).expandToInclude(destRect);
    canvas.saveLayer(bounds, Paint());

    if (gradientColors == null) {
      canvas.drawImageRect(
        image,
        srcRect,
        destRect,
        Paint()..colorFilter = ColorFilter.mode(baseColor, BlendMode.srcIn),
      );
    } else {
      canvas.drawImageRect(image, srcRect, destRect, Paint());
      final colors = gradientColors!;
      final colorStops = colors.length == 2
          ? null
          : List<double>.generate(colors.length, (i) => i / (colors.length - 1));
      canvas.drawRect(
        destRect,
        Paint()
          ..shader = ui.Gradient.linear(
            destRect.topLeft,
            destRect.bottomRight,
            colors,
            colorStops,
          )
          ..blendMode = BlendMode.srcIn,
      );
    }

    if (shader.matte) {
      final paint = Paint()
        ..color = Colors.black.withValues(alpha: shader.matteOpacity)
        ..blendMode = BlendMode.srcATop;
      if (shader.matteBlur > 0) {
        paint.imageFilter = ui.ImageFilter.blur(sigmaX: shader.matteBlur, sigmaY: shader.matteBlur);
      }
      canvas.drawRect(
        destRect,
        paint,
      );
    }

    if (shader.gradient) {
      canvas.drawRect(
        destRect,
        Paint()
          ..shader = ui.Gradient.linear(
            destRect.centerLeft,
            destRect.centerRight,
            const [
              Color(0x2E000000),
              Colors.transparent,
              Color(0x38FFFFFF),
            ],
            const [0.0, 0.5, 1.0],
          )
          ..blendMode = BlendMode.srcATop,
      );
    }

    if (shader.stripe) {
      canvas.drawRect(
        destRect,
        Paint()
          ..shader = ui.Gradient.linear(
            destRect.centerLeft,
            destRect.centerRight,
            [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.42),
              Colors.transparent,
            ],
            const [0.38, 0.5, 0.62],
          )
          ..blendMode = BlendMode.srcATop,
      );
    }

    if (shader.rainbow) {
      canvas.drawRect(
        destRect,
        Paint()
          ..shader = ui.Gradient.linear(
            destRect.topLeft,
            destRect.bottomRight,
            [
              Colors.red.withValues(alpha: 0.45),
              Colors.yellow.withValues(alpha: 0.40),
              Colors.green.withValues(alpha: 0.38),
              Colors.blue.withValues(alpha: 0.40),
              Colors.purple.withValues(alpha: 0.45),
            ],
            const [0.0, 0.25, 0.5, 0.75, 1.0],
          )
          ..blendMode = BlendMode.srcATop,
      );
    }

    if (shader.metallic) {
      canvas.drawRect(
        destRect,
        Paint()
          ..shader = ui.Gradient.linear(
            destRect.topLeft,
            destRect.bottomRight,
            [
              Colors.white.withValues(alpha: 0.52),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.16),
              Colors.white.withValues(alpha: 0.36),
            ],
            const [0, 0.32, 0.62, 1],
          )
          ..blendMode = BlendMode.srcATop,
      );
    }

    if (shader.shine) {
      final shineCenter = Offset(
        destRect.left + destRect.width * (shader.shineAlignment.x + 1) / 2,
        destRect.top + destRect.height * (shader.shineAlignment.y + 1) / 2,
      );
      canvas.drawRect(
        destRect,
        Paint()
          ..shader = ui.Gradient.radial(
            shineCenter,
            destRect.longestSide * shader.shineSize,
            [
              Colors.white.withValues(alpha: shader.shineOpacity),
              Colors.white.withValues(alpha: 0),
            ],
          )
          ..blendMode = BlendMode.srcATop,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NailPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.contentRect != contentRect ||
        oldDelegate.baseColor != baseColor ||
        !_colorListEquals(oldDelegate.gradientColors, gradientColors) ||
        oldDelegate.shader != shader;
  }
}

bool _colorListEquals(List<Color>? a, List<Color>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Color _applySurfaceOffsets(Color color, NailSurfaceModel? surface) {
  if (surface == null) return color;
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withHue((hsl.hue + surface.hueOffset) % 360)
      .withSaturation(
        (hsl.saturation + surface.saturationOffset).clamp(0.0, 1.0),
      )
      .withLightness((hsl.lightness + surface.lightnessOffset).clamp(0.0, 1.0))
      .toColor();
}

class _SurfaceShader {
  final bool matte;
  final double matteOpacity;
  final double matteBlur;
  final bool shine;
  final bool metallic;
  final bool stripe;
  final bool gradient;
  final bool rainbow;
  final Alignment shineAlignment;
  final double shineSize;
  final double shineOpacity;

  const _SurfaceShader({
    required this.matte,
    required this.matteOpacity,
    required this.matteBlur,
    required this.shine,
    required this.metallic,
    required this.stripe,
    required this.gradient,
    required this.rainbow,
    required this.shineAlignment,
    required this.shineSize,
    required this.shineOpacity,
  });

  factory _SurfaceShader.fromSurface(NailSurfaceModel? surface) {
    final params = _decodeShaderParams(surface?.shaderParam);
    final name = surface?.name.toLowerCase() ?? '';

    // Support both flat API values (e.g. {"shine":0.85}) and legacy nested objects
    final shineRaw = params['shine'];
    final shineMap = _asMap(shineRaw);
    // Flat: shine is a numeric value → use directly as opacity
    final shineValue = shineRaw is num ? shineRaw.toDouble() : null;

    final metalnessMap = _asMap(params['metalness']);
    // Flat: "metallic" key with numeric value (Chrome: {"metallic":1.0})
    final metallicFlat = params['metallic'];

    final stripeMap = _asMap(params['stripe']);
    // Flat: "streak" key (Cat Eyes: {"streak":0.9,"angle":90})
    final streakFlat = params['streak'];

    final gradientMap = _asMap(params['gradient']);
    final prismMap = _asMap(params['prism']);

    // Flat: "rainbow" key as boolean (Holographic: {"rainbow":true})
    final rainbowRaw = params['rainbow'];
    final rainbowMap = _asMap(rainbowRaw);
    final rainbowFlat = rainbowRaw == true;

    final iridescenceMap = _asMap(params['iridescence']);

    final isMatte = name.contains('matte') ||
        _asMap(params['texture'])?['type'] == 'matte' ||
        params.containsKey('opacity') ||
        params.containsKey('blur');

    final isShine = name.contains('glossy') ||
        name.contains('shine') ||
        shineValue != null ||
        _asEnabled(shineMap);

    final isMetallic = name.contains('chrome') ||
        name.contains('metallic') ||
        (metallicFlat is num && metallicFlat > 0) ||
        _asEnabled(metalnessMap);

    final isStripe = name.contains('cat') ||
        name.contains('stripe') ||
        (streakFlat is num && streakFlat > 0) ||
        _asEnabled(stripeMap);

    final isRainbow = name.contains('holo') ||
        name.contains('rainbow') ||
        rainbowFlat ||
        _asEnabled(prismMap) ||
        _asEnabled(rainbowMap) ||
        _asEnabled(iridescenceMap);

    // Resolve shine opacity: flat numeric value takes priority over nested map
    final resolvedShineOpacity = shineValue ??
        _asDouble(shineMap?['opacity'], fallback: 0.55);

    // Resolve metallic reflectivity for shine size scaling
    final reflectivity = _asDouble(params['reflectivity'], fallback: 0.75);

    // Resolve boosted shine (Glossy surface specific)
    final boostedShine = _asDouble(params['boostedShine'], fallback: 1.0);

    return _SurfaceShader(
      matte: isMatte,
      matteOpacity: _asDouble(params['opacity'], fallback: 0.08).clamp(0.0, 1.0),
      matteBlur: _asDouble(params['blur'], fallback: 0.0).clamp(0.0, 20.0),
      shine: isShine,
      metallic: isMetallic,
      stripe: isStripe,
      gradient: _asEnabled(gradientMap),
      rainbow: isRainbow,
      shineAlignment: _alignmentFromPosition(shineMap?['position']?.toString()),
      shineSize: (_asDouble(shineMap?['size'], fallback: 0.42) * boostedShine).clamp(0.18, 0.9),
      shineOpacity: (resolvedShineOpacity * (isMetallic ? reflectivity : 1.0)).clamp(0.0, 1.0),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _SurfaceShader &&
        other.matte == matte &&
        other.matteOpacity == matteOpacity &&
        other.matteBlur == matteBlur &&
        other.shine == shine &&
        other.metallic == metallic &&
        other.stripe == stripe &&
        other.gradient == gradient &&
        other.rainbow == rainbow &&
        other.shineAlignment == shineAlignment &&
        other.shineSize == shineSize &&
        other.shineOpacity == shineOpacity;
  }

  @override
  int get hashCode => Object.hash(
        matte,
        matteOpacity,
        matteBlur,
        shine,
        metallic,
        stripe,
        gradient,
        rainbow,
        shineAlignment,
        shineSize,
        shineOpacity,
      );
}

Map<String, dynamic> _decodeShaderParams(String? value) {
  if (value == null || value.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return const {};
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

bool _asEnabled(Map<String, dynamic>? value) => value?['enabled'] == true;

double _asDouble(dynamic value, {required double fallback}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

Alignment _alignmentFromPosition(String? value) {
  switch (value) {
    case 'top-left':
      return Alignment.topLeft;
    case 'top-right':
      return Alignment.topRight;
    case 'center':
      return Alignment.center;
    default:
      return Alignment.topRight;
  }
}

class NailOverlayPreview extends StatelessWidget {
  final NailShapeModel? selectedShape;
  final NailSurfaceModel? selectedSurface;
  final String color;
  final List<String>? gradientStops;
  final List<PlacedComponentDraft> placements;
  final bool showShadow;

  const NailOverlayPreview({
    super.key,
    required this.selectedShape,
    required this.selectedSurface,
    required this.color,
    required this.gradientStops,
    required this.placements,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final nailWidth = constraints.maxWidth;
        final nailHeight = constraints.maxHeight;

        if (nailWidth <= 0 || nailHeight <= 0) return const SizedBox.expand();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (selectedShape?.imageUrl.isNotEmpty == true)
              Positioned.fill(
                child: _NailColorPreview(
                  imageUrl: selectedShape!.imageUrl,
                  color: color,
                  gradientStops: gradientStops,
                  surface: selectedSurface,
                  showShadow: showShadow,
                ),
              ),
            if (selectedShape?.imageUrl.isNotEmpty == true && placements.isNotEmpty)
              Positioned.fill(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: placements.map((placement) {
                    final size = (nailWidth * placement.scale.clamp(0.1, 1.5)).clamp(2.0, nailWidth);
                    final centerX = (nailWidth / 2 + placement.posX * nailWidth).clamp(0.0, nailWidth);
                    final centerY = (nailHeight / 2 + placement.posY * nailHeight).clamp(0.0, nailHeight);
                    final left = (centerX - size / 2).clamp(-size / 2, nailWidth);
                    final top = (centerY - size / 2).clamp(-size / 2, nailHeight);

                    Widget icon = placement.imageUrl.isEmpty
                        ? const Icon(Icons.auto_awesome, color: Colors.purple, size: 10)
                        : Image.network(
                            placement.imageUrl,
                            fit: BoxFit.contain,
                            cacheWidth: 100,
                            cacheHeight: 100,
                            errorBuilder: (context, error, stackTrace) => const SizedBox(),
                          );

                    if (placement.rotation != 0) {
                      icon = Transform.rotate(
                        angle: placement.rotation * 3.14159265359 / 180,
                        child: icon,
                      );
                    }

                    return Positioned(
                      left: left,
                      top: top,
                      width: size,
                      height: size,
                      child: icon,
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}