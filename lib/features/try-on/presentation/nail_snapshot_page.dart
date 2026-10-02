import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../../../../core/constants/app_colors.dart';
import '../isolate/inference_worker.dart';
import '../models/nail_variant_model.dart';
import '../painter/advanced_nail_painter.dart';
import '../painter/nail_debug_painter.dart';
import '../services/nail_variant_api_service.dart';
import 'widgets/snapshot_camera_screen.dart';

enum _DragMode { none, move, scaleRotate }

class NailSnapshotPage extends StatefulWidget {
  final NailVariantModel? initialVariant;
  final bool lockVariantSelection;

  const NailSnapshotPage({
    super.key,
    this.initialVariant,
    this.lockVariantSelection = false,
  });

  @override
  State<NailSnapshotPage> createState() => _NailSnapshotPageState();
}

class _NailSnapshotPageState extends State<NailSnapshotPage>
    with SingleTickerProviderStateMixin {
  File? _imageFile;
  bool _isProcessing = false;
  bool _isLoadingVariants = false;
  final bool _showDebugOverlay = false; // Render try-on overlay directly

  final InferenceWorker _worker = InferenceWorker();
  List<List<Offset>> _nailPolygons = [];
  List<String> _nailLabels = [];
  List<NailPoseKeypoints?> _nailPoseKeypoints = [];
  double _imgWidth = 0;
  double _imgHeight = 0;

  // Toggle debug outline overlay on demand via eye icon button
  bool _showDebugPreview = false;

  // Backend API Nail Variants state
  List<NailVariantModel> _apiVariants = [];
  NailVariantModel? _selectedVariant;
  ui.Image? _selectedShapeImage;
  Map<int, ui.Image> _selectedComponentImages = {};

  // Customization state
  List<NailShape> _apiShapes = [];
  List<NailSurface> _apiSurfaces = [];
  List<ComponentDetail> _apiComponents = [];
  bool _isLoadingCustomization = false;

  // Accessory & Finger selection state
  int _selectedFingerIndex =
      -1; // -1: All fingers, 1: Thumb, 2: Index, 3: Middle, 4: Ring, 5: Pinky
  int? _selectedComponentId; // Currently active accessory item ID for Bounding Box handles
  _DragMode _dragMode = _DragMode.none;
  bool _isCustomPanelCollapsed = false;

  // Zoom & Focus Transformation controllers
  late TransformationController _transformationController;
  AnimationController? _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _worker.init();
    if (widget.initialVariant != null) {
      _apiVariants = [widget.initialVariant!];
      _onSelectVariant(widget.initialVariant!);
    }
    if (!widget.lockVariantSelection) {
      _fetchApiVariants();
    }
    _fetchCustomizationData();
  }

  Future<void> _fetchCustomizationData() async {
    setState(() => _isLoadingCustomization = true);
    try {
      final shapes = await NailVariantApiService.fetchNailShapes(pageSize: 20);
      final surfaces = await NailVariantApiService.fetchNailSurfaces(
        pageSize: 20,
      );
      final components = await NailVariantApiService.fetchComponents(
        pageSize: 30,
      );
      if (mounted) {
        setState(() {
          _apiShapes = shapes;
          _apiSurfaces = surfaces;
          _apiComponents = components;
        });
      }
    } catch (e) {
      debugPrint("⚠️ Lỗi tải Customization Data: $e");
    } finally {
      if (mounted) setState(() => _isLoadingCustomization = false);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _zoomAnimationController?.dispose();
    _worker.dispose();
    super.dispose();
  }

  Future<void> _fetchApiVariants() async {
    setState(() {
      _isLoadingVariants = true;
    });

    try {
      final variants = await NailVariantApiService.fetchNailVariants(
        pageNumber: 1,
        pageSize: 10,
      );

      if (mounted && variants.isNotEmpty) {
        setState(() {
          _apiVariants = variants;
        });
        // Select first variant by default
        _onSelectVariant(variants.first);
      }
    } catch (e) {
      debugPrint("⚠️ Lỗi tải Nail Variants từ API: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVariants = false;
        });
      }
    }
  }

  Future<void> _onSelectVariant(NailVariantModel variant) async {
    setState(() {
      _selectedVariant = variant;
    });

    // 1. Load Nail Shape PNG Image (trimmed & background-removed for exact 1:1 fitting)
    ui.Image? shapeImg;
    if (variant.nailShape.imageUrl.isNotEmpty) {
      shapeImg =
          await NailVariantApiService.loadTrimmedUiImageFromUrl(
            variant.nailShape.imageUrl,
          ) ??
          await NailVariantApiService.loadUiImageFromUrl(
            variant.nailShape.imageUrl,
          );
    }

    // 2. Load Component Images (Charms/Stickers)
    Map<int, ui.Image> charmImgs = {};
    for (final compItem in variant.nailComponents) {
      final img = await NailVariantApiService.loadUiImageFromUrl(
        compItem.component.imageUrl,
      );
      if (img != null) {
        charmImgs[compItem.component.componentId] = img;
      }
    }

    if (mounted) {
      setState(() {
        _selectedShapeImage = shapeImg;
        _selectedComponentImages = charmImgs;
      });
    }
  }

  Future<void> _onSelectShape(NailShape newShape) async {
    if (_selectedVariant == null) return;

    final updatedVariant = NailVariantModel(
      nailVariantId: _selectedVariant!.nailVariantId,
      name: _selectedVariant!.name,
      imageUrl: _selectedVariant!.imageUrl,
      colorConfig: _selectedVariant!.colorConfig,
      nailShape: newShape,
      nailSurface: _selectedVariant!.nailSurface,
      nailComponents: _selectedVariant!.nailComponents,
    );

    setState(() {
      _selectedVariant = updatedVariant;
    });

    ui.Image? shapeImg;
    if (newShape.imageUrl.isNotEmpty) {
      shapeImg =
          await NailVariantApiService.loadTrimmedUiImageFromUrl(
            newShape.imageUrl,
          ) ??
          await NailVariantApiService.loadUiImageFromUrl(newShape.imageUrl);
    }

    if (mounted) {
      setState(() {
        _selectedShapeImage = shapeImg;
      });
    }
  }

  Future<void> _onSelectSurface(NailSurface newSurface) async {
    if (_selectedVariant == null) return;

    final updatedVariant = NailVariantModel(
      nailVariantId: _selectedVariant!.nailVariantId,
      name: _selectedVariant!.name,
      imageUrl: _selectedVariant!.imageUrl,
      colorConfig: _selectedVariant!.colorConfig,
      nailShape: _selectedVariant!.nailShape,
      nailSurface: newSurface,
      nailComponents: _selectedVariant!.nailComponents,
    );

    setState(() {
      _selectedVariant = updatedVariant;
    });
  }

  List<FingerTransformInfo> _getFingerTransforms() {
    if (_selectedVariant == null) return [];
    return AdvancedNailPainter(
      polygons: _nailPolygons,
      labels: _nailLabels,
      poseKeypoints: _nailPoseKeypoints,
      variant: _selectedVariant!,
      nailShapeImage: _selectedShapeImage,
      componentImages: _selectedComponentImages,
      selectedFingerIndex: _selectedFingerIndex,
      selectedComponentId: _selectedComponentId,
    ).computeTransforms();
  }

  bool _isPointInPolygon(Offset p, List<Offset> poly) {
    bool inside = false;
    int j = poly.length - 1;
    for (int i = 0; i < poly.length; i++) {
      if ((poly[i].dy > p.dy) != (poly[j].dy > p.dy) &&
          (p.dx <
              (poly[j].dx - poly[i].dx) *
                      (p.dy - poly[i].dy) /
                      (poly[j].dy - poly[i].dy) +
                  poly[i].dx)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  Offset _rotateVector(Offset v, double angle) {
    final double c = math.cos(angle);
    final double s = math.sin(angle);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  FingerTransformInfo? _findTransformForComponent(
    NailComponentItem comp,
    List<FingerTransformInfo> transforms,
  ) {
    if (transforms.isEmpty) return null;
    if (comp.fingerIndex != -1) {
      for (final t in transforms) {
        if (t.fingerIndex == comp.fingerIndex) return t;
      }
    }
    if (_selectedFingerIndex != -1) {
      for (final t in transforms) {
        if (t.fingerIndex == _selectedFingerIndex) return t;
      }
    }
    return transforms.first;
  }

  void _zoomToFinger(int fingerIndex) {
    if (_zoomAnimationController == null) return;

    if (fingerIndex == -1 || _imgWidth == 0 || _imgHeight == 0) {
      _animateMatrixTo(Matrix4.identity());
      return;
    }

    final transforms = _getFingerTransforms();
    FingerTransformInfo? targetTransform;
    for (final t in transforms) {
      if (t.fingerIndex == fingerIndex) {
        targetTransform = t;
        break;
      }
    }

    if (targetTransform == null) {
      _animateMatrixTo(Matrix4.identity());
      return;
    }

    final Offset nailCenter = targetTransform.polygonCentroid;
    const double targetScale = 2.8;

    final double viewportCenterX = _imgWidth / 2;
    final double viewportCenterY = _imgHeight / 2;

    final double tx = viewportCenterX - nailCenter.dx * targetScale;
    final double ty = viewportCenterY - nailCenter.dy * targetScale;

    final Matrix4 targetMatrix = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(targetScale);

    _animateMatrixTo(targetMatrix);
  }

  void _animateMatrixTo(Matrix4 targetMatrix) {
    if (_zoomAnimationController == null) return;
    _zoomAnimationController!.stop();

    final Matrix4 startMatrix = _transformationController.value;
    _zoomAnimation = Matrix4Tween(begin: startMatrix, end: targetMatrix)
        .animate(
          CurvedAnimation(
            parent: _zoomAnimationController!,
            curve: Curves.easeInOutCubic,
          ),
        );

    _zoomAnimation!.addListener(() {
      _transformationController.value = _zoomAnimation!.value;
    });

    _zoomAnimationController!.forward(from: 0.0);
  }

  double _getHandRefWidth(List<FingerTransformInfo> transforms) {
    double maxW = 0.0;
    for (final t in transforms) {
      if (t.destRect.width > maxW) maxW = t.destRect.width;
    }
    return maxW;
  }

  void _handleTapDown(TapDownDetails details) {
    if (_selectedVariant == null) return;
    final Offset tapPos = details.localPosition;
    final transforms = _getFingerTransforms();
    final double handRefWidth = _getHandRefWidth(transforms);

    // SCENARIO 1: NOT ZOOMED IN (_selectedFingerIndex == -1)
    if (_selectedFingerIndex == -1) {
      for (final info in transforms) {
        final isInsidePoly = _isPointInPolygon(tapPos, info.polygonPoints);
        final isInsideRect = info.destRect.inflate(16.0).contains(tapPos);
        final distToCentroid = (tapPos - info.polygonCentroid).distance;
        final maxRadius = math.max(info.destRect.width, info.destRect.height);

        if (isInsidePoly || isInsideRect || distToCentroid <= maxRadius * 0.8) {
          setState(() {
            _selectedFingerIndex = info.fingerIndex;
            _selectedComponentId = null;
          });
          _zoomToFinger(info.fingerIndex);
          return;
        }
      }
      return;
    }

    // SCENARIO 2: ZOOMED IN (_selectedFingerIndex != -1)
    if (_selectedComponentId != null) {
      for (final compItem in _selectedVariant!.nailComponents) {
        if (compItem.nailComponentId == _selectedComponentId) {
          final int itemFinger =
              compItem.fingerIndex != -1 ? compItem.fingerIndex : 1;
          if (_selectedFingerIndex != -1 &&
              itemFinger != _selectedFingerIndex) {
            continue;
          }
          final info = _findTransformForComponent(compItem, transforms);
          if (info != null) {
            final charmImage =
                _selectedComponentImages[compItem.component.componentId];
            final double baseWidth = handRefWidth > 0
                ? math.max(info.destRect.width, handRefWidth * 0.90)
                : info.destRect.width;
            final double charmWidth = baseWidth *
                compItem.scale *
                AdvancedNailPainter.accessoryScaleMultiplier;
            final double charmHeight = charmImage != null
                ? charmWidth * (charmImage.height / charmImage.width)
                : charmWidth;

            final double charmLocalX =
                info.destRect.center.dx +
                compItem.posX * (info.destRect.width / 2);
            final double charmLocalY =
                info.destRect.center.dy +
                compItem.posY * (info.destRect.height / 2);
            final Offset charmCanvasCenter = info.localToCanvas(
              Offset(charmLocalX, charmLocalY),
            );

            final double totalAngle =
                info.angle + compItem.rotation * math.pi / 180.0;

            final Offset blLocal = Offset(
              -charmWidth / 2 - 4,
              charmHeight / 2 + 4,
            );
            final Offset deleteHandleCanvas =
                charmCanvasCenter + _rotateVector(blLocal, totalAngle);

            final Offset trLocal = Offset(
              charmWidth / 2 + 4,
              -charmHeight / 2 - 4,
            );
            final Offset trHandleCanvas =
                charmCanvasCenter + _rotateVector(trLocal, totalAngle);

            if ((tapPos - deleteHandleCanvas).distance <= 16.0) {
              _deleteComponent(compItem.nailComponentId);
              return;
            }

            if ((tapPos - trHandleCanvas).distance <= 18.0) {
              _dragMode = _DragMode.scaleRotate;
              return;
            }
          }
        }
      }
    }

    // Priority 2: Check any placed charm (accessory) on the zoomed finger
    for (final compItem in _selectedVariant!.nailComponents.reversed) {
      final int itemFinger =
          compItem.fingerIndex != -1 ? compItem.fingerIndex : 1;
      if (_selectedFingerIndex != -1 && itemFinger != _selectedFingerIndex) {
        continue;
      }
      final info = _findTransformForComponent(compItem, transforms);
      if (info != null) {
        final charmImage =
            _selectedComponentImages[compItem.component.componentId];
        final double baseWidth = handRefWidth > 0
            ? math.max(info.destRect.width, handRefWidth * 0.90)
            : info.destRect.width;
        final double charmWidth = baseWidth *
            compItem.scale *
            AdvancedNailPainter.accessoryScaleMultiplier;
        final double charmHeight = charmImage != null
            ? charmWidth * (charmImage.height / charmImage.width)
            : charmWidth;

        final double charmLocalX =
            info.destRect.center.dx + compItem.posX * (info.destRect.width / 2);
        final double charmLocalY =
            info.destRect.center.dy +
            compItem.posY * (info.destRect.height / 2);
        final Offset charmCanvasCenter = info.localToCanvas(
          Offset(charmLocalX, charmLocalY),
        );

        final double hitRadius = math.max(
          math.max(charmWidth, charmHeight) * 0.8,
          50.0,
        );

        if ((tapPos - charmCanvasCenter).distance <= hitRadius) {
          setState(() {
            _selectedComponentId = compItem.nailComponentId;
          });
          _dragMode = _DragMode.move;
          return;
        }
      }
    }

    // Priority 3: Check if tap is on another finger while zoomed
    for (final info in transforms) {
      if (info.fingerIndex == _selectedFingerIndex) continue;
      final isInsidePoly = _isPointInPolygon(tapPos, info.polygonPoints);
      final isInsideRect = info.destRect.inflate(16.0).contains(tapPos);
      if (isInsidePoly || isInsideRect) {
        setState(() {
          _selectedFingerIndex = info.fingerIndex;
          _selectedComponentId = null;
        });
        _zoomToFinger(info.fingerIndex);
        return;
      }
    }

    // Priority 4: Background tap on zoomed nail -> clear selection
    setState(() {
      _selectedComponentId = null;
    });
  }

  void _handlePanStart(DragStartDetails details) {
    if (_selectedComponentId == null || _selectedVariant == null) return;
    final Offset tapPos = details.localPosition;
    final transforms = _getFingerTransforms();
    final double handRefWidth = _getHandRefWidth(transforms);

    for (final compItem in _selectedVariant!.nailComponents) {
      if (compItem.nailComponentId == _selectedComponentId) {
        final info = _findTransformForComponent(compItem, transforms);
        if (info != null) {
          final charmImage =
              _selectedComponentImages[compItem.component.componentId];
          final double baseWidth = handRefWidth > 0
              ? math.max(info.destRect.width, handRefWidth * 0.90)
              : info.destRect.width;
          final double charmWidth = baseWidth *
              compItem.scale *
              AdvancedNailPainter.accessoryScaleMultiplier;
          final double charmHeight = charmImage != null
              ? charmWidth * (charmImage.height / charmImage.width)
              : charmWidth;

          final double charmLocalX =
              info.destRect.center.dx +
              compItem.posX * (info.destRect.width / 2);
          final double charmLocalY =
              info.destRect.center.dy +
              compItem.posY * (info.destRect.height / 2);
          final Offset charmCanvasCenter = info.localToCanvas(
            Offset(charmLocalX, charmLocalY),
          );

          final double totalAngle =
              info.angle + compItem.rotation * math.pi / 180.0;
          final Offset trLocal = Offset(
            charmWidth / 2 + 4,
            -charmHeight / 2 - 4,
          );
          final Offset trHandleCanvas =
              charmCanvasCenter + _rotateVector(trLocal, totalAngle);

          if ((tapPos - trHandleCanvas).distance <= 18.0) {
            _dragMode = _DragMode.scaleRotate;
          } else {
            _dragMode = _DragMode.move;
          }
          return;
        }
      }
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_selectedComponentId == null ||
        _selectedVariant == null ||
        _dragMode == _DragMode.none) {
      return;
    }

    final transforms = _getFingerTransforms();
    final double handRefWidth = _getHandRefWidth(transforms);
    final int idx = _selectedVariant!.nailComponents.indexWhere(
      (c) => c.nailComponentId == _selectedComponentId,
    );
    if (idx == -1) return;

    final compItem = _selectedVariant!.nailComponents[idx];
    final info = _findTransformForComponent(compItem, transforms);
    if (info == null) return;

    final Offset currentPos = details.localPosition;
    final Offset delta = details.delta;

    final charmImage =
        _selectedComponentImages[compItem.component.componentId];
    final double charmAspect =
        (charmImage != null && charmImage.width > 0)
            ? charmImage.height / charmImage.width
            : 1.0;

    final double baseWidth = handRefWidth > 0
        ? math.max(info.destRect.width, handRefWidth * 0.90)
        : info.destRect.width;

    if (_dragMode == _DragMode.move) {
      final double charmWidth = baseWidth *
          compItem.scale *
          AdvancedNailPainter.accessoryScaleMultiplier;
      final double charmHeight = charmWidth * charmAspect;

      final double rad = (compItem.rotation * math.pi / 180.0).abs();
      final double cosR = math.cos(rad).abs();
      final double sinR = math.sin(rad).abs();

      final double effWidth = charmWidth * cosR + charmHeight * sinR;
      final double effHeight = charmWidth * sinR + charmHeight * cosR;

      final double maxPosX = math.max(
        0.0,
        1.0 - (effWidth / info.destRect.width),
      );
      final double maxPosY = math.max(
        0.0,
        1.0 - (effHeight / info.destRect.height),
      );

      final Offset localDelta =
          info.canvasToLocal(delta) - info.canvasToLocal(Offset.zero);
      final double candidatePosX =
          compItem.posX + localDelta.dx / (info.destRect.width / 2);
      final double candidatePosY =
          compItem.posY + localDelta.dy / (info.destRect.height / 2);

      final double newPosX = candidatePosX.clamp(-maxPosX, maxPosX);
      final double newPosY = candidatePosY.clamp(-maxPosY, maxPosY);

      final updatedItem = compItem.copyWith(posX: newPosX, posY: newPosY);
      final updatedList = List<NailComponentItem>.from(
        _selectedVariant!.nailComponents,
      );
      updatedList[idx] = updatedItem;

      setState(() {
        _selectedVariant = _selectedVariant!.copyWith(
          nailComponents: updatedList,
        );
      });
    } else if (_dragMode == _DragMode.scaleRotate) {
      final double charmLocalX =
          info.destRect.center.dx + compItem.posX * (info.destRect.width / 2);
      final double charmLocalY =
          info.destRect.center.dy + compItem.posY * (info.destRect.height / 2);
      final Offset charmCanvasCenter = info.localToCanvas(
        Offset(charmLocalX, charmLocalY),
      );

      final Offset relTouch = currentPos - charmCanvasCenter;
      final double dist = relTouch.distance;

      final double baseRadius = (baseWidth *
              AdvancedNailPainter.accessoryScaleMultiplier) /
          2;
      final double rawScale = dist / baseRadius;

      final double touchAngle = math.atan2(relTouch.dy, relTouch.dx);
      final double newRotation =
          ((touchAngle - info.angle) * 180.0 / math.pi) + 45.0;

      final double rad = (newRotation * math.pi / 180.0).abs();
      final double cosR = math.cos(rad).abs();
      final double sinR = math.sin(rad).abs();

      final double unitEffWidth = cosR + charmAspect * sinR;
      final double unitEffHeight = sinR + charmAspect * cosR;

      final double maxScaleX = 1.0 / math.max(0.001, unitEffWidth);
      final double maxScaleY =
          (info.destRect.height / info.destRect.width) /
          math.max(0.001, unitEffHeight);
      final double maxScale = math.min(1.0, math.min(maxScaleX, maxScaleY))
          .clamp(0.15, 1.0);

      final double newScale = rawScale.clamp(0.15, maxScale);

      final double charmWidth = info.destRect.width * newScale;
      final double charmHeight = charmWidth * charmAspect;
      final double effWidth = charmWidth * cosR + charmHeight * sinR;
      final double effHeight = charmWidth * sinR + charmHeight * cosR;

      final double maxPosX = math.max(
        0.0,
        1.0 - (effWidth / info.destRect.width),
      );
      final double maxPosY = math.max(
        0.0,
        1.0 - (effHeight / info.destRect.height),
      );

      final double newPosX = compItem.posX.clamp(-maxPosX, maxPosX);
      final double newPosY = compItem.posY.clamp(-maxPosY, maxPosY);

      final updatedItem = compItem.copyWith(
        scale: newScale,
        rotation: newRotation,
        posX: newPosX,
        posY: newPosY,
      );
      final updatedList = List<NailComponentItem>.from(
        _selectedVariant!.nailComponents,
      );
      updatedList[idx] = updatedItem;

      setState(() {
        _selectedVariant = _selectedVariant!.copyWith(
          nailComponents: updatedList,
        );
      });
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _dragMode = _DragMode.none;
  }

  void _deleteComponent(int componentItemId) {
    if (_selectedVariant == null) return;
    final updatedList = _selectedVariant!.nailComponents
        .where((c) => c.nailComponentId != componentItemId)
        .toList();
    setState(() {
      _selectedVariant = _selectedVariant!.copyWith(
        nailComponents: updatedList,
      );
      if (_selectedComponentId == componentItemId) {
        _selectedComponentId = null;
      }
    });
  }

  void _clearCurrentFingerComponents() {
    if (_selectedVariant == null) return;
    final updatedList = _selectedVariant!.nailComponents
        .where(
          (c) =>
              c.fingerIndex != _selectedFingerIndex &&
              _selectedFingerIndex != -1,
        )
        .toList();
    setState(() {
      _selectedVariant = _selectedVariant!.copyWith(
        nailComponents: _selectedFingerIndex == -1 ? [] : updatedList,
      );
      _selectedComponentId = null;
    });
  }

  void _clearAllComponents() {
    if (_selectedVariant == null) return;
    setState(() {
      _selectedVariant = _selectedVariant!.copyWith(nailComponents: []);
      _selectedComponentId = null;
    });
  }

  Future<void> _onSelectComponent(ComponentDetail newComponent) async {
    if (_selectedVariant == null) return;

    final targetFinger = _selectedFingerIndex != -1 ? _selectedFingerIndex : 1;

    final existingIdx = _selectedVariant!.nailComponents.indexWhere(
      (c) => c.nailComponentId == _selectedComponentId,
    );

    List<NailComponentItem> updatedComponents;
    int targetComponentId;

    if (existingIdx != -1) {
      final existingItem = _selectedVariant!.nailComponents[existingIdx];
      final updatedItem = existingItem.copyWith(
        component: newComponent,
        fingerIndex: targetFinger,
      );
      updatedComponents = List<NailComponentItem>.from(
        _selectedVariant!.nailComponents,
      );
      updatedComponents[existingIdx] = updatedItem;
      targetComponentId = existingItem.nailComponentId;
    } else {
      final newItem = NailComponentItem(
        nailComponentId: DateTime.now().microsecondsSinceEpoch,
        posX: 0.0,
        posY: 0.0,
        fingerIndex: targetFinger,
        scale: 0.5,
        rotation: 0.0,
        component: newComponent,
      );
      updatedComponents = List<NailComponentItem>.from(
        _selectedVariant!.nailComponents,
      )..add(newItem);
      targetComponentId = newItem.nailComponentId;
    }

    final updatedVariant = _selectedVariant!.copyWith(
      nailComponents: updatedComponents,
    );

    setState(() {
      _selectedVariant = updatedVariant;
      _selectedComponentId = targetComponentId;
      if (_selectedFingerIndex == -1) {
        _selectedFingerIndex = targetFinger;
      }
    });

    _zoomToFinger(targetFinger);

    final img = await NailVariantApiService.loadUiImageFromUrl(
      newComponent.imageUrl,
    );
    if (img != null && mounted) {
      setState(() {
        _selectedComponentImages[newComponent.componentId] = img;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    File? selectedFile;

    if (source == ImageSource.camera) {
      selectedFile = await SnapshotCameraScreen.open(context);
    } else {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (pickedFile != null) {
        selectedFile = File(pickedFile.path);
      }
    }

    if (selectedFile != null) {
      final rawBytes = await selectedFile.readAsBytes();
      final decodedImage = img.decodeImage(rawBytes);

      if (decodedImage != null) {
        final normalizedImage = img.bakeOrientation(decodedImage);
        final normalizedBytes = Uint8List.fromList(
          img.encodeJpg(normalizedImage),
        );

        final tempDir = Directory.systemTemp;
        final tempFile = File(
          '${tempDir.path}/normalized_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await tempFile.writeAsBytes(normalizedBytes);

        setState(() {
          _imageFile = tempFile;
          _imgWidth = normalizedImage.width.toDouble();
          _imgHeight = normalizedImage.height.toDouble();
          _isProcessing = true;
          _nailPolygons = [];
          _nailLabels = [];
          _nailPoseKeypoints = [];
        });

        await _processSelectedImage();
      }
    }
  }

  Future<void> _processSelectedImage() async {
    if (_imageFile == null) return;

    try {
      final imageBytes = await _imageFile!.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) return;

      setState(() {
        _imgWidth = decodedImage.width.toDouble();
        _imgHeight = decodedImage.height.toDouble();
      });

      final result = await _worker.processFrame(
        decodedImage,
        confThreshold: 0.50,
      );

      if (!mounted) return;

      setState(() {
        _nailPolygons = result.polygons;
        _nailPoseKeypoints = result.poseKeypoints;
        _nailLabels = result.fingerLabels;
        _showDebugPreview = false;
      });

      if (result.polygons.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không nhận diện được móng nào trong ảnh này.'),
          ),
        );
      }
    } catch (e) {
      debugPrint("⚠️ Lỗi Inference Worker: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showPhotoGuideSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.only(top: 40),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.tips_and_updates_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Mẹo chụp ảnh đẹp & chuẩn',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGuideItem(
                  icon: Icons.pan_tool_rounded,
                  title: 'Xòe bàn tay tự nhiên',
                  subtitle:
                      'Đặt bàn tay phẳng, các ngón tay xòe đều và hướng thẳng lên trên.',
                ),
                const SizedBox(height: 12),
                _buildGuideItem(
                  icon: Icons.wb_sunny_rounded,
                  title: 'Ánh sáng đầy đủ & rõ nét',
                  subtitle:
                      'Tránh chụp trong bóng tối, ngược sáng hoặc ảnh bị rung nhòe.',
                ),
                const SizedBox(height: 12),
                _buildGuideItem(
                  icon: Icons.crop_free_rounded,
                  title: 'Nền tương phản tốt',
                  subtitle:
                      'Đặt tay trên mặt phẳng trơn (bàn, ga trải) để Nailify tách móng chuẩn xác nhất.',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Đã hiểu',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF0F5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        title: const Text(
          'Snapshot Studio',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 15,
              color: AppColors.textPrimary,
            ),
          ),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Hướng dẫn chụp ảnh',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            onPressed: _showPhotoGuideSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isProcessing
          ? _buildProcessingLoadingScreen()
          : Column(
              children: [
                // 1. Khung hiển thị ảnh bàn tay + Canvas AR
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.primaryLight.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: _imageFile == null ||
                              _imgWidth == 0 ||
                              _imgHeight == 0
                          ? _buildEmptyStatePlaceholder()
                          : Stack(
                              children: [
                                Positioned.fill(
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: InteractiveViewer(
                                      transformationController:
                                          _transformationController,
                                      minScale: 0.8,
                                      maxScale: 6.0,
                                      panEnabled: _selectedComponentId == null,
                                      scaleEnabled:
                                          _selectedComponentId == null,
                                      child: SizedBox(
                                        width: _imgWidth,
                                        height: _imgHeight,
                                        child: GestureDetector(
                                          onTapDown: _handleTapDown,
                                          onPanStart: _handlePanStart,
                                          onPanUpdate: _handlePanUpdate,
                                          onPanEnd: _handlePanEnd,
                                          child: Stack(
                                            children: [
                                              Image.file(_imageFile!),
                                              if (_nailPolygons.isNotEmpty)
                                                Positioned.fill(
                                                  child: CustomPaint(
                                                    painter: _selectedVariant != null
                                                         ? AdvancedNailPainter(
                                                             polygons:
                                                                 _nailPolygons,
                                                             labels: _nailLabels,
                                                             poseKeypoints:
                                                                 _nailPoseKeypoints,
                                                             variant:
                                                                 _selectedVariant!,
                                                             nailShapeImage:
                                                                 _selectedShapeImage,
                                                             componentImages:
                                                                 _selectedComponentImages,
                                                             selectedFingerIndex:
                                                                 _selectedFingerIndex,
                                                             selectedComponentId:
                                                                 _selectedComponentId,
                                                           )
                                                         : null,
                                                     foregroundPainter: (_showDebugPreview || _showDebugOverlay)
                                                         ? NailDebugPainter(
                                                             polygons:
                                                                 _nailPolygons,
                                                             labels: _nailLabels,
                                                             poseKeypoints:
                                                                 _nailPoseKeypoints,
                                                           )
                                                         : null,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Top Floating Bar: Active Finger Indicator or Quick Guide Pill
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: _selectedFingerIndex != -1
                                      ? GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedFingerIndex = -1;
                                              _selectedComponentId = null;
                                            });
                                            _zoomToFinger(-1);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: AppColors.quizGradient,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.35),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.arrow_back_rounded,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  '${_getFingerName(_selectedFingerIndex)} • Đổi',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.55,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.touch_app_rounded,
                                                size: 13,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 5),
                                              Text(
                                                'Chạm móng để phóng to',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),

                                // Top Right Actions: Contour visibility toggle or Zoom Controls
                                 Positioned(
                                   top: 12,
                                   right: 12,
                                   child: Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       if (_nailPolygons.isNotEmpty) ...[
                                         GestureDetector(
                                           onTap: () {
                                             setState(() {
                                               _showDebugPreview =
                                                   !_showDebugPreview;
                                             });
                                           },
                                           child: Container(
                                             width: 38,
                                             height: 38,
                                             decoration: BoxDecoration(
                                               color: _showDebugPreview
                                                   ? AppColors.primary
                                                   : Colors.white.withValues(
                                                       alpha: 0.92,
                                                     ),
                                               shape: BoxShape.circle,
                                               boxShadow: [
                                                 BoxShadow(
                                                   color: Colors.black
                                                       .withValues(alpha: 0.1),
                                                   blurRadius: 8,
                                                   offset: const Offset(0, 2),
                                                 ),
                                               ],
                                             ),
                                             child: Icon(
                                               _showDebugPreview
                                                   ? Icons.visibility_rounded
                                                   : Icons.visibility_outlined,
                                               size: 19,
                                               color: _showDebugPreview
                                                   ? Colors.white
                                                   : AppColors.primary,
                                             ),
                                           ),
                                         ),
                                         const SizedBox(width: 8),
                                         GestureDetector(
                                           onTap: () {
                                             setState(() {
                                               _selectedFingerIndex = -1;
                                               _selectedComponentId = null;
                                             });
                                             _zoomToFinger(-1);
                                           },
                                           child: Container(
                                             width: 38,
                                             height: 38,
                                             decoration: BoxDecoration(
                                               color: Colors.white.withValues(
                                                 alpha: 0.92,
                                               ),
                                               shape: BoxShape.circle,
                                               boxShadow: [
                                                 BoxShadow(
                                                   color: Colors.black
                                                       .withValues(alpha: 0.1),
                                                   blurRadius: 8,
                                                   offset: const Offset(0, 2),
                                                 ),
                                               ],
                                             ),
                                             child: const Icon(
                                               Icons.center_focus_strong_rounded,
                                              size: 19,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Bottom Right: Floating Expand/Collapse Tool Button
                                if (_nailPolygons.isNotEmpty)
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _isCustomPanelCollapsed =
                                              !_isCustomPanelCollapsed;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.92,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.1),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _isCustomPanelCollapsed
                                                  ? Icons.palette_outlined
                                                  : Icons.keyboard_arrow_down_rounded,
                                              size: 16,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _isCustomPanelCollapsed
                                                  ? 'Tùy chọn'
                                                  : 'Thu gọn',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                ),

                // 2. Bảng tùy chỉnh Nail / Dáng móng / Bề mặt / Phụ kiện
                if (_imageFile != null && !_isProcessing)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Thanh gạt thu gọn/mở rộng panel
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate: (details) {
                              if (details.delta.dy > 3 &&
                                  !_isCustomPanelCollapsed) {
                                setState(() => _isCustomPanelCollapsed = true);
                              } else if (details.delta.dy < -3 &&
                                  _isCustomPanelCollapsed) {
                                setState(() => _isCustomPanelCollapsed = false);
                              }
                            },
                            onTap: () {
                              setState(() {
                                _isCustomPanelCollapsed =
                                    !_isCustomPanelCollapsed;
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.only(top: 10, bottom: 4),
                              child: Column(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _isCustomPanelCollapsed
                                            ? "Mở rộng bảng tùy chỉnh"
                                            : "Kéo xuống để xem toàn ảnh",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Icon(
                                        _isCustomPanelCollapsed
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: Colors.grey.shade500,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          AnimatedSize(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOutCubic,
                            child: _isCustomPanelCollapsed
                                ? const SizedBox.shrink()
                                : DefaultTabController(
                                    length: widget.lockVariantSelection ? 3 : 4,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // TabBar hiện đại với Segmented Tabs
                                        Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF6F8FB),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          padding: const EdgeInsets.all(3),
                                          child: TabBar(
                                            labelColor: Colors.white,
                                            unselectedLabelColor:
                                                AppColors.textSecondary,
                                            indicatorSize:
                                                TabBarIndicatorSize.tab,
                                            indicator: BoxDecoration(
                                              gradient: AppColors.quizGradient,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.3),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            dividerColor: Colors.transparent,
                                            labelStyle: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12.5,
                                            ),
                                            unselectedLabelStyle:
                                                const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                            tabs: [
                                              if (!widget.lockVariantSelection)
                                                const Tab(
                                                  icon: Icon(
                                                    Icons.palette_outlined,
                                                    size: 16,
                                                  ),
                                                  text: "Mẫu nail",
                                                  iconMargin:
                                                      EdgeInsets.only(bottom: 2),
                                                ),
                                              const Tab(
                                                icon: Icon(
                                                  Icons.pan_tool_alt_outlined,
                                                  size: 16,
                                                ),
                                                text: "Dáng móng",
                                                iconMargin:
                                                    EdgeInsets.only(bottom: 2),
                                              ),
                                              const Tab(
                                                icon: Icon(
                                                  Icons.gradient_outlined,
                                                  size: 16,
                                                ),
                                                text: "Bề mặt",
                                                iconMargin:
                                                    EdgeInsets.only(bottom: 2),
                                              ),
                                              const Tab(
                                                icon: Icon(
                                                  Icons.diamond_outlined,
                                                  size: 16,
                                                ),
                                                text: "Phụ kiện",
                                                iconMargin:
                                                    EdgeInsets.only(bottom: 2),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Danh sách items theo Tab
                                        SizedBox(
                                          height: 162,
                                          child: TabBarView(
                                            children: [
                                              if (!widget.lockVariantSelection)
                                                _buildVariantsList(),
                                              _buildShapesList(),
                                              _buildSurfacesList(),
                                              _buildComponentsList(),
                                            ],
                                          ),
                                        ),

                                        // Quick Action Bar: Chụp lại / Đổi ảnh
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            6,
                                            16,
                                            12,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () => _pickImage(
                                                    ImageSource.camera,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                          vertical: 11,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      gradient: AppColors
                                                          .quizGradient,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: AppColors
                                                              .primary
                                                              .withValues(
                                                                alpha: 0.25,
                                                              ),
                                                          blurRadius: 8,
                                                          offset: const Offset(
                                                            0,
                                                            3,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .camera_alt_rounded,
                                                          size: 17,
                                                          color: Colors.white,
                                                        ),
                                                        SizedBox(width: 6),
                                                        Text(
                                                          'Chụp ảnh mới',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 13,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () => _pickImage(
                                                    ImageSource.gallery,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                          vertical: 11,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                      border: Border.all(
                                                        color: AppColors
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                        width: 1.2,
                                                      ),
                                                    ),
                                                    child: const Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .photo_library_rounded,
                                                          size: 17,
                                                          color:
                                                              AppColors.primary,
                                                        ),
                                                        SizedBox(width: 6),
                                                        Text(
                                                          'Chọn từ máy',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 13,
                                                            color: AppColors
                                                                .primary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
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

  Widget _buildProcessingLoadingScreen() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF7FB), Color(0xFFFDFBFE), Color(0xFFFFF0F5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1400),
            tween: Tween<double>(begin: 0.95, end: 1.05),
            curve: Curves.easeInOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 125,
                    height: 125,
                    decoration: BoxDecoration(
                      gradient: AppColors.quizGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 95,
                      height: 95,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 46,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text(
            'NAILIFY ĐANG PHÂN TÍCH BÀN TAY',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryDark,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Đang nhận diện vị trí 5 móng & khớp ngón tay...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: const LinearProgressIndicator(
                minHeight: 5,
                color: AppColors.primary,
                backgroundColor: Color(0xFFF1E4EC),
              ),
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildEmptyStatePlaceholder() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFFDFE), Color(0xFFFFF5F9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Aura icon container
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryLight,
                  AppColors.primary.withValues(alpha: 0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.pan_tool_outlined,
              size: 46,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Thử Móng Nghệ Thuật',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chụp hoặc chọn ảnh bàn tay để Nailify tự động nhận diện móng và ướm thử những thiết kế xinh đẹp nhất!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // 3 Quick Tips in Pill chips
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTipPill(Icons.flare_rounded, 'Đủ sáng'),
              const SizedBox(width: 8),
              _buildTipPill(Icons.pan_tool_rounded, 'Xòe 5 ngón'),
              const SizedBox(width: 8),
              _buildTipPill(Icons.straighten_rounded, 'Hướng lên'),
            ],
          ),

          const SizedBox(height: 26),

          // 2 Action Buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text(
                    'Chụp ảnh',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 3,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text(
                    'Chọn từ máy',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantsList() {
    if (_isLoadingVariants) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_apiVariants.isEmpty) {
      return Center(
        child: Text(
          "Không có mẫu nào",
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      itemCount: _apiVariants.length,
      itemBuilder: (context, index) {
        final variant = _apiVariants[index];
        final isSelected =
            _selectedVariant?.nailVariantId == variant.nailVariantId;
        return _buildSelectorItem(
          title: variant.name,
          imageUrl: variant.imageUrl,
          isSelected: isSelected,
          onTap: () => _onSelectVariant(variant),
        );
      },
    );
  }

  Widget _buildShapesList() {
    if (_isLoadingCustomization) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_apiShapes.isEmpty) {
      return Center(
        child: Text(
          "Không có dáng móng nào",
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      itemCount: _apiShapes.length,
      itemBuilder: (context, index) {
        final shape = _apiShapes[index];
        final isSelected =
            _selectedVariant?.nailShape.nailShapeId == shape.nailShapeId;
        return _buildSelectorItem(
          title: shape.name,
          imageUrl: shape.imageUrl,
          isSelected: isSelected,
          onTap: () => _onSelectShape(shape),
        );
      },
    );
  }

  Widget _buildSurfacesList() {
    if (_isLoadingCustomization) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_apiSurfaces.isEmpty) {
      return Center(
        child: Text(
          "Không có bề mặt nào",
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      itemCount: _apiSurfaces.length,
      itemBuilder: (context, index) {
        final surface = _apiSurfaces[index];
        final isSelected =
            _selectedVariant?.nailSurface.nailSurfaceId ==
            surface.nailSurfaceId;
        return _buildSelectorItem(
          title: surface.name,
          icon: Icons.gradient_rounded,
          isSelected: isSelected,
          onTap: () => _onSelectSurface(surface),
        );
      },
    );
  }

  Widget _buildComponentsList() {
    if (_isLoadingCustomization) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_apiComponents.isEmpty) {
      return Center(
        child: Text(
          "Không có phụ kiện nào",
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      );
    }

    return Column(
      children: [
        // 1. Finger Selector Chips + Clear Action Buttons Bar
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFingerChip(-1, "Tất cả"),
                _buildFingerChip(1, "Ngón cái"),
                _buildFingerChip(2, "Ngón trỏ"),
                _buildFingerChip(3, "Ngón giữa"),
                _buildFingerChip(4, "Ngón áp út"),
                _buildFingerChip(5, "Ngón út"),
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _clearCurrentFingerComponents,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cleaning_services_rounded,
                          size: 13,
                          color: Colors.orange.shade800,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Xóa ngón này",
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _clearAllComponents,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_sweep_rounded,
                          size: 14,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Xóa hết",
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. Accessory Items List
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            itemCount: _apiComponents.length,
            itemBuilder: (context, index) {
              final comp = _apiComponents[index];
              return _buildSelectorItem(
                title: comp.name,
                imageUrl: comp.imageUrl,
                isSelected: false,
                onTap: () => _onSelectComponent(comp),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFingerChip(int fingerIdx, String label) {
    final bool isSelected = _selectedFingerIndex == fingerIdx;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        onTap: () {
          setState(() => _selectedFingerIndex = fingerIdx);
          _zoomToFinger(fingerIdx);
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.quizGradient : null,
            color: isSelected ? null : const Color(0xFFF1F3F6),
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorItem({
    required String title,
    String? imageUrl,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 88,
        margin: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 4.0),
        padding: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF0F6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: (imageUrl != null && imageUrl.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.image_not_supported_rounded,
                              size: 26,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Icon(
                          icon ?? Icons.auto_awesome_rounded,
                          size: 28,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.pink.shade300,
                        ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 78,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    gradient: AppColors.quizGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getFingerName(int index) {
    switch (index) {
      case 1:
        return 'Ngón cái';
      case 2:
        return 'Ngón trỏ';
      case 3:
        return 'Ngón giữa';
      case 4:
        return 'Ngón áp út';
      case 5:
        return 'Ngón út';
      default:
        return 'Tất cả móng';
    }
  }
}