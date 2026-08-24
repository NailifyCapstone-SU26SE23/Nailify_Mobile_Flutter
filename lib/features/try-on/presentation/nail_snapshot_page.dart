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
import '../services/roboflow_cloud_service.dart';

enum _DragMode { none, move, scaleRotate }

class NailSnapshotPage extends StatefulWidget {
  const NailSnapshotPage({super.key});

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

  Duration? _lastInferenceDuration;

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
  int?
  _selectedComponentId; // Currently active accessory item ID for Bounding Box handles
  _DragMode _dragMode = _DragMode.none;

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
    _fetchApiVariants();
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

  void _handleTapDown(TapDownDetails details) {
    if (_selectedVariant == null) return;
    final Offset tapPos = _transformationController.toScene(
      details.localPosition,
    );
    final transforms = _getFingerTransforms();

    // 1. Check Delete handle ('X') or Scale/Rotate handle of selected component
    if (_selectedComponentId != null) {
      for (final compItem in _selectedVariant!.nailComponents) {
        if (compItem.nailComponentId == _selectedComponentId) {
          final info = _findTransformForComponent(compItem, transforms);
          if (info != null) {
            final charmImage =
                _selectedComponentImages[compItem.component.componentId];
            final double charmWidth = info.destRect.width * compItem.scale;
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
              -charmWidth / 2 - 3,
              charmHeight / 2 + 3,
            );
            final Offset deleteHandleCanvas =
                charmCanvasCenter + _rotateVector(blLocal, totalAngle);

            final Offset trLocal = Offset(
              charmWidth / 2 + 3,
              -charmHeight / 2 - 3,
            );
            final Offset trHandleCanvas =
                charmCanvasCenter + _rotateVector(trLocal, totalAngle);

            if ((tapPos - deleteHandleCanvas).distance <= 24.0) {
              _deleteComponent(compItem.nailComponentId);
              return;
            }

            if ((tapPos - trHandleCanvas).distance <= 24.0) {
              _dragMode = _DragMode.scaleRotate;
              return;
            }
          }
        }
      }
    }

    // 2. Check any placed charm
    for (final compItem in _selectedVariant!.nailComponents.reversed) {
      final info = _findTransformForComponent(compItem, transforms);
      if (info != null) {
        final charmLocalX =
            info.destRect.center.dx + compItem.posX * (info.destRect.width / 2);
        final charmLocalY =
            info.destRect.center.dy +
            compItem.posY * (info.destRect.height / 2);
        final Offset charmCanvasCenter = info.localToCanvas(
          Offset(charmLocalX, charmLocalY),
        );

        final double charmWidth = info.destRect.width * compItem.scale;
        if ((tapPos - charmCanvasCenter).distance <=
            math.max(charmWidth / 2, 35.0)) {
          setState(() {
            _selectedComponentId = compItem.nailComponentId;
            if (compItem.fingerIndex != -1) {
              _selectedFingerIndex = compItem.fingerIndex;
            }
          });
          _dragMode = _DragMode.move;
          return;
        }
      }
    }

    // 3. Check inside fingernail polygon
    for (final info in transforms) {
      if (_isPointInPolygon(tapPos, info.polygonPoints)) {
        setState(() {
          _selectedFingerIndex = info.fingerIndex;
          _selectedComponentId = null;
        });
        _zoomToFinger(info.fingerIndex);
        return;
      }
    }

    // 4. Background tap
    setState(() {
      _selectedComponentId = null;
    });
  }

  void _handlePanStart(DragStartDetails details) {
    if (_selectedComponentId == null || _selectedVariant == null) return;
    final Offset tapPos = _transformationController.toScene(
      details.localPosition,
    );
    final transforms = _getFingerTransforms();

    for (final compItem in _selectedVariant!.nailComponents) {
      if (compItem.nailComponentId == _selectedComponentId) {
        final info = _findTransformForComponent(compItem, transforms);
        if (info != null) {
          final charmImage =
              _selectedComponentImages[compItem.component.componentId];
          final double charmWidth = info.destRect.width * compItem.scale;
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
            charmWidth / 2 + 3,
            -charmHeight / 2 - 3,
          );
          final Offset trHandleCanvas =
              charmCanvasCenter + _rotateVector(trLocal, totalAngle);

          if ((tapPos - trHandleCanvas).distance <= 32.0) {
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
    final int idx = _selectedVariant!.nailComponents.indexWhere(
      (c) => c.nailComponentId == _selectedComponentId,
    );
    if (idx == -1) return;

    final compItem = _selectedVariant!.nailComponents[idx];
    final info = _findTransformForComponent(compItem, transforms);
    if (info == null) return;

    final Offset currentPos = _transformationController.toScene(
      details.localPosition,
    );
    final Offset previousPos = _transformationController.toScene(
      details.localPosition - details.delta,
    );
    final Offset delta = currentPos - previousPos;

    if (_dragMode == _DragMode.move) {
      final Offset localDelta =
          info.canvasToLocal(delta) - info.canvasToLocal(Offset.zero);
      final double newPosX =
          (compItem.posX + localDelta.dx / (info.destRect.width / 2)).clamp(
            -10.0,
            10.0,
          );
      final double newPosY =
          (compItem.posY + localDelta.dy / (info.destRect.height / 2)).clamp(
            -10.0,
            10.0,
          );

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

      final double baseRadius = info.destRect.width / 2;
      final double newScale = (dist / baseRadius).clamp(0.2, 3.0);

      final double touchAngle = math.atan2(relTouch.dy, relTouch.dx);
      final double newRotation =
          ((touchAngle - info.angle) * 180.0 / math.pi) + 45.0;

      final updatedItem = compItem.copyWith(
        scale: newScale,
        rotation: newRotation,
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

    final newItem = NailComponentItem(
      nailComponentId: DateTime.now().microsecondsSinceEpoch,
      posX: 0.0,
      posY: 0.0,
      fingerIndex: _selectedFingerIndex,
      scale: 0.5,
      rotation: 0.0,
      component: newComponent,
    );

    final updatedComponents = List<NailComponentItem>.from(
      _selectedVariant!.nailComponents,
    )..add(newItem);

    final updatedVariant = _selectedVariant!.copyWith(
      nailComponents: updatedComponents,
    );

    setState(() {
      _selectedVariant = updatedVariant;
      _selectedComponentId = newItem.nailComponentId;
    });

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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      final rawBytes = await pickedFile.readAsBytes();
      final decodedImage = img.decodeImage(rawBytes);

      if (decodedImage != null) {
        // 📌 FIX EXIF ROTATION BUG: Bake EXIF orientation directly into physical pixel matrix!
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
        confThreshold: 0.20,
      );

      if (!mounted) return;

      setState(() {
        _nailPolygons = result.polygons;
        _nailPoseKeypoints = result.poseKeypoints;
        _lastInferenceDuration = result.inferenceTime;
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

  Future<void> _processSelectedImageOnline() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn hoặc chụp ảnh trước!')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final imageBytes = await _imageFile!.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);

      if (decodedImage != null) {
        setState(() {
          _imgWidth = decodedImage.width.toDouble();
          _imgHeight = decodedImage.height.toDouble();
        });
      }

      final result = await RoboflowCloudService.detectNailsOnline(imageBytes);

      if (!mounted) return;

      setState(() {
        _nailPolygons = result.polygons;
        _nailLabels = result.labels;
        _nailPoseKeypoints = result.poseKeypoints;
        _lastInferenceDuration = result.inferenceTime;
      });

      if (result.polygons.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Roboflow Cloud không tìm thấy móng nào.'),
          ),
        );
      }
    } catch (e) {
      debugPrint("⚠️ Lỗi Roboflow Online API: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Snapshot Try-On AI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.textPrimary,
          ),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Column(
        children: [
          // 1. Khung hiển thị ảnh bàn tay
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _imageFile == null || _imgWidth == 0 || _imgHeight == 0
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
                                scaleEnabled: _selectedComponentId == null,
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
                                              painter: _showDebugOverlay
                                                  ? NailDebugPainter(
                                                      polygons: _nailPolygons,
                                                      labels: _nailLabels,
                                                      poseKeypoints:
                                                          _nailPoseKeypoints,
                                                    )
                                                  : (_selectedVariant != null
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
                                                        : null),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_nailPolygons.isNotEmpty)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: FloatingActionButton.small(
                                heroTag: 'resetZoomBtn',
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.9,
                                ),
                                foregroundColor: AppColors.primary,
                                elevation: 2,
                                onPressed: () {
                                  setState(() => _selectedFingerIndex = -1);
                                  _zoomToFinger(-1);
                                },
                                child: const Icon(
                                  Icons.center_focus_strong,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),

          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: Color(0xFFFFF0F5),
              ),
            ),

          // 2. Bảng tùy chỉnh (chỉ hiện khi đã chọn ảnh)
          if (_imageFile != null && !_isProcessing)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DefaultTabController(
                      length: 4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const TabBar(
                            labelColor: AppColors.primary,
                            unselectedLabelColor: Colors.black54,
                            indicatorColor: AppColors.primary,
                            indicatorSize: TabBarIndicatorSize.label,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            unselectedLabelStyle: TextStyle(fontSize: 13),
                            tabs: [
                              Tab(text: "Mẫu"),
                              Tab(text: "Dáng móng"),
                              Tab(text: "Bề mặt"),
                              Tab(text: "Phụ kiện"),
                            ],
                          ),
                          SizedBox(
                            height: 155,
                            child: TabBarView(
                              children: [
                                _buildVariantsList(),
                                _buildShapesList(),
                                _buildSurfacesList(),
                                _buildComponentsList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. Hai nút Chụp ảnh & Chọn từ máy
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _pickImage(ImageSource.camera),
                              icon: const Icon(
                                Icons.camera_alt_outlined,
                                size: 20,
                              ),
                              label: const Text(
                                'Chụp ảnh',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
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
                              icon: const Icon(
                                Icons.photo_library_outlined,
                                size: 20,
                              ),
                              label: const Text(
                                'Chọn từ máy',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
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
    );
  }

  Widget _buildEmptyStatePlaceholder() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.back_hand_outlined,
              size: 56,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Thử móng AI theo ảnh bàn tay',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chụp hoặc chọn 1 bức ảnh bàn tay của bạn để AI tự động nhận diện và thử các mẫu móng xinh đẹp!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Chụp ảnh'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Chọn từ máy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
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

  Widget _buildVariantsList() {
    if (_isLoadingVariants) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_apiVariants.isEmpty) {
      return const Center(child: Text("Không có mẫu nào"));
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
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
      return const Center(child: CircularProgressIndicator());
    }
    if (_apiShapes.isEmpty) {
      return const Center(child: Text("Không có dáng móng nào"));
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
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
      return const Center(child: CircularProgressIndicator());
    }
    if (_apiSurfaces.isEmpty) {
      return const Center(child: Text("Không có bề mặt nào"));
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _apiSurfaces.length,
      itemBuilder: (context, index) {
        final surface = _apiSurfaces[index];
        final isSelected =
            _selectedVariant?.nailSurface.nailSurfaceId ==
            surface.nailSurfaceId;
        return _buildSelectorItem(
          title: surface.name,
          icon: Icons.layers,
          isSelected: isSelected,
          onTap: () => _onSelectSurface(surface),
        );
      },
    );
  }

  Widget _buildComponentsList() {
    if (_isLoadingCustomization) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_apiComponents.isEmpty) {
      return const Center(child: Text("Không có phụ kiện nào"));
    }

    return Column(
      children: [
        // 1. Finger Selector Chips + Clear Action Buttons Bar
        Container(
          height: 38,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFingerChip(-1, "Tất cả"),
                _buildFingerChip(1, "Ngón cái"),
                _buildFingerChip(2, "Ngón trỏ"),
                _buildFingerChip(3, "Ngón giữa"),
                _buildFingerChip(4, "Ngón áp út"),
                _buildFingerChip(5, "Ngón út"),
                const VerticalDivider(width: 12, indent: 6, endIndent: 6),
                IconButton(
                  onPressed: _clearCurrentFingerComponents,
                  icon: const Icon(
                    Icons.cleaning_services,
                    size: 16,
                    color: Colors.orange,
                  ),
                  tooltip: "Xóa phụ kiện ngón này",
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                IconButton(
                  onPressed: _clearAllComponents,
                  icon: const Icon(
                    Icons.delete_sweep,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                  tooltip: "Xóa tất cả phụ kiện",
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
        ),

        // 2. Accessory Items List
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
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
      padding: const EdgeInsets.only(right: 4.0),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
        selected: isSelected,
        selectedColor: const Color(0xFFFF4081),
        backgroundColor: Colors.grey.shade200,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        onSelected: (val) {
          if (val) {
            setState(() => _selectedFingerIndex = fingerIdx);
            _zoomToFinger(fingerIdx);
          }
        },
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 12.0),
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF4081) : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  imageUrl,
                  width: 45,
                  height: 45,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.image_not_supported, size: 30),
                ),
              )
            else if (icon != null)
              Icon(icon, size: 40, color: Colors.pink.shade300)
            else
              const Icon(Icons.brush, size: 40),
            const SizedBox(height: 4),
            SizedBox(
              width: 70,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
