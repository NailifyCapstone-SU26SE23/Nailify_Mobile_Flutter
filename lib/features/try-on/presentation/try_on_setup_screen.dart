import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../quiz/data/datasources/quiz_repository.dart';
import '../../../core/di/injection.dart';
import '../../nails/data/models/customer_nail_models.dart';
import '../../nails/data/models/nail_shape_model.dart';
import '../../nails/data/models/nail_surface_model.dart';
import '../../nails/data/repositories/customer_nail_repository.dart';
import '../../nails/data/repositories/nail_component_repository.dart';
import '../models/placed_component_draft.dart';
import '../models/try_on_data.dart';
import '../services/try_on_setup_service.dart';
import '../utils/try_on_setup_helpers.dart';
import '../widgets/component_grid.dart';
import '../widgets/nail_shape_selector.dart';
import '../widgets/nail_surface_selector.dart';
import '../widgets/try_on_color_selector.dart';
import '../widgets/try_on_placement_controls.dart';
import '../widgets/try_on_preview_board.dart';
import 'try_on_method_selection_screen.dart';
import 'snapshot_preview_screen.dart';

class TryOnSetupScreen extends StatefulWidget {
  final CustomerNailModel? customerNail;
  final Map<String, dynamic>? recommendedData;

  const TryOnSetupScreen({super.key, this.customerNail, this.recommendedData});

  @override
  State<TryOnSetupScreen> createState() => _TryOnSetupScreenState();
}

class _TryOnSetupScreenState extends State<TryOnSetupScreen> {
  late final TryOnSetupService _setupService;
  late final NailComponentRepository _componentRepository;
  late final CustomerNailRepository _customerNailRepository;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSelectorExpanded = true;
  final bool _launching = false;
  String? _error;
  TryOnData? _tryOnData;
  CustomerNailModel? _customerNail;

  NailShapeModel? _selectedNailShape;
  NailSurfaceModel? _selectedNailSurface;
  final Map<int, String> _fingerColors = {
    1: '#FF4081',
    2: '#FF4081',
    3: '#FF4081',
    4: '#FF4081',
    5: '#FF4081',
  };
  final Map<int, List<String>?> _fingerGradients = {
    1: null,
    2: null,
    3: null,
    4: null,
    5: null,
  };
  CombinedComponent? _selectedComponent;
  int _selectedFingerIndex = -1;
  int? _previewDetailFingerIndex;
  int? _selectedPlacementId;
  final List<PlacedComponentDraft> _placements = [];
  final Set<int> _deletedPlacementIds = {};

  @override
  void initState() {
    super.initState();
    _setupService = getIt<TryOnSetupService>();
    _componentRepository = getIt<NailComponentRepository>();
    _customerNailRepository = getIt<CustomerNailRepository>();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('[TryOnSetupScreen] _fetchData started. widget.customerNail=${widget.customerNail?.customerNailId}, widget.recommendedData=${widget.recommendedData != null}');
      final results = await Future.wait([
        _setupService.fetchTryOnData(),
        if (widget.customerNail != null)
          _customerNailRepository.getCustomerNailById(
            widget.customerNail!.customerNailId,
          ),
      ]);
      debugPrint('[TryOnSetupScreen] fetchTryOnData completed.');
      final data = results.first as TryOnData;
      final customerNail = widget.customerNail == null
          ? null
          : results.length > 1
          ? results[1] as CustomerNailModel
          : widget.customerNail;

      final customColorJson = customerNail?.customColor;
      final Map<int, String> initialColors = {
        1: '#FF4081',
        2: '#FF4081',
        3: '#FF4081',
        4: '#FF4081',
        5: '#FF4081',
      };
      final Map<int, List<String>?> initialGradients = {
        1: null,
        2: null,
        3: null,
        4: null,
        5: null,
      };
      if (customColorJson != null) {
        final decoded = decodeTryOnConfig(customColorJson);
        if (decoded['mode'] == 'perFinger' || decoded['Mode'] == 'perFinger') {
          final fingers = decoded['fingers'] ?? decoded['Fingers'];
          if (fingers is List) {
            for (final finger in fingers) {
              if (finger is Map) {
                final fIdx = asTryOnInt(
                  finger['fingerIndex'] ?? finger['FingerIndex'],
                );
                final color = finger['color'] ?? finger['Color'];
                if (fIdx >= 1 && fIdx <= 5 && color is String) {
                  initialColors[fIdx] = color;
                }
                final gradient = finger['gradient'] ?? finger['Gradient'];
                if (fIdx >= 1 &&
                    fIdx <= 5 &&
                    gradient is Map &&
                    gradient['enabled'] == true) {
                  final stops = gradient['stops'];
                  if (stops is List) {
                    initialGradients[fIdx] = stops
                        .map((item) => item.toString())
                        .take(3)
                        .toList();
                  }
                }
              }
            }
          }
        } else {
          final singleColor = decoded['color'] ?? decoded['Color'] ?? '#FF4081';
          for (var i = 1; i <= 5; i++) {
            initialColors[i] = singleColor;
          }
        }
      }

      // If coming from Perfect Match, compute recommended overrides
      NailShapeModel? finalShape = _resolveShape(data.nailShapes, customerNail);
      NailSurfaceModel? finalSurface = _resolveSurface(data.nailSurfaces, customerNail);
      Map<int, String> finalColors = Map.from(initialColors);
      Map<int, List<String>?> finalGradients = Map.from(initialGradients);
      List<PlacedComponentDraft> finalPlacements = _buildDrafts(customerNail, data.combinedComponents);
      CombinedComponent? finalSelectedComponent;

      final recData = widget.recommendedData;
      if (recData != null) {
        debugPrint('[TryOnSetupScreen] Processing recommendedData: $recData');
        try {
          // Resolve shape safely
          if (recData['nailShape'] is Map) {
            final recShapeId = (recData['nailShape'] as Map)['nailShapeId'];
            finalShape = data.nailShapes.firstWhereOrNull((s) => s.nailShapeId == recShapeId) ?? finalShape;
            debugPrint('[TryOnSetupScreen] Resolved shape: ${finalShape?.name}');
          }

          // Resolve surface safely
          if (recData['nailSurface'] is Map) {
            final recSurfaceId = (recData['nailSurface'] as Map)['nailSurfaceId'];
            finalSurface = data.nailSurfaces.firstWhereOrNull((s) => s.nailSurfaceId == recSurfaceId) ?? finalSurface;
            debugPrint('[TryOnSetupScreen] Resolved surface: ${finalSurface?.name}');
          }

          // Colors & Gradients safely
          final colorsRaw = recData['colors'];
          if (colorsRaw is List && colorsRaw.isNotEmpty) {
            final primaryHex = colorsRaw.first.toString();
            for (var i = 1; i <= 5; i++) {
              finalColors[i] = primaryHex;
            }
            if (colorsRaw.length >= 2) {
              final stops = colorsRaw.map((e) => e.toString()).take(3).toList();
              for (var i = 1; i <= 5; i++) {
                finalGradients[i] = stops;
              }
            }
            debugPrint('[TryOnSetupScreen] Resolved colors: $finalColors');
          }

          // Placements safely
          final componentsRaw = recData['components'];
          if (componentsRaw is List) {
            final resolved = <PlacedComponentDraft>[];
            int localId = DateTime.now().microsecondsSinceEpoch;
            for (final comp in componentsRaw) {
              if (comp is! Map) continue;
              final compId = comp['componentId'];
              final matched = data.combinedComponents.firstWhereOrNull(
                (c) => !c.isCustomerComponent && c.componentId == compId,
              );
              if (matched != null) {
                finalSelectedComponent ??= matched;
                for (var fIdx = 1; fIdx <= 5; fIdx++) {
                  resolved.add(PlacedComponentDraft(
                    localId: localId++,
                    component: matched,
                    componentId: matched.componentId,
                    customerComponentId: matched.customerComponentId,
                    name: matched.name,
                    imageUrl: matched.imageUrl,
                    fingerIndex: fIdx,
                    posX: 0,
                    posY: 0,
                    scale: 0.5,
                    rotation: 0,
                  ));
                }
              }
            }
            if (resolved.isNotEmpty) finalPlacements = resolved;
            debugPrint('[TryOnSetupScreen] Resolved placements count: ${finalPlacements.length}');
          }
        } catch (innerErr) {
          debugPrint('[TryOnSetupScreen] Inner parsing error: $innerErr');
        }
      }

      debugPrint('[TryOnSetupScreen] Setting state now...');
      setState(() {
        _tryOnData = data;
        _customerNail = customerNail;
        _selectedNailShape = finalShape;
        _selectedNailSurface = finalSurface;
        _selectedComponent = finalSelectedComponent;
        _fingerColors.clear();
        _fingerColors.addAll(finalColors);
        _fingerGradients
          ..clear()
          ..addAll(finalGradients);
        _placements
          ..clear()
          ..addAll(finalPlacements);
        _selectedPlacementId = _placements.isEmpty
            ? null
            : _placements.first.localId;
        _isLoading = false;
      });
      debugPrint('[TryOnSetupScreen] _fetchData finished setting state.');
    } catch (error) {
      debugPrint('[TryOnSetupScreen] Outer error in _fetchData: $error');
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  void _applyRecommendedData(Map<String, dynamic> recData) {
    if (_tryOnData == null) return;
    final data = _tryOnData!;

    // Resolve shape
    NailShapeModel? resolvedShape = _resolveShape(data.nailShapes, _customerNail);
    if (recData['nailShape'] is Map) {
      final recShapeId = (recData['nailShape'] as Map)['nailShapeId'];
      resolvedShape = data.nailShapes.firstWhereOrNull((s) => s.nailShapeId == recShapeId) ?? resolvedShape;
    }

    // Resolve surface
    NailSurfaceModel? resolvedSurface = _resolveSurface(data.nailSurfaces, _customerNail);
    if (recData['nailSurface'] is Map) {
      final recSurfaceId = (recData['nailSurface'] as Map)['nailSurfaceId'];
      resolvedSurface = data.nailSurfaces.firstWhereOrNull((s) => s.nailSurfaceId == recSurfaceId) ?? resolvedSurface;
    }

    // Colors & Gradients — safe casts
    final Map<int, String> initialColors = {for (var i = 1; i <= 5; i++) i: '#FF4081'};
    final Map<int, List<String>?> initialGradients = {for (var i = 1; i <= 5; i++) i: null};
    final colorsRaw = recData['colors'];
    if (colorsRaw is List && colorsRaw.isNotEmpty) {
      final primaryHex = colorsRaw.first.toString();
      for (var i = 1; i <= 5; i++) {
        initialColors[i] = primaryHex;
      }
      if (colorsRaw.length >= 2) {
        final stops = colorsRaw.map((e) => e.toString()).take(3).toList();
        for (var i = 1; i <= 5; i++) {
          initialGradients[i] = stops;
        }
      }
    }

    // Placements — safe casts
    final List<PlacedComponentDraft> resolvedPlacements = [];
    CombinedComponent? resolvedSelectedComponent;
    final componentsRaw = recData['components'];
    if (componentsRaw is List) {
      int localIdCounter = DateTime.now().microsecondsSinceEpoch;
      for (final comp in componentsRaw) {
        if (comp is! Map) continue;
        final compId = comp['componentId'];
        final matchedComponent = data.combinedComponents.firstWhereOrNull(
          (c) => !c.isCustomerComponent && c.componentId == compId,
        );
        if (matchedComponent != null) {
          resolvedSelectedComponent ??= matchedComponent;
          for (var fIdx = 1; fIdx <= 5; fIdx++) {
            resolvedPlacements.add(
              PlacedComponentDraft(
                localId: localIdCounter++,
                component: matchedComponent,
                componentId: matchedComponent.componentId,
                customerComponentId: matchedComponent.customerComponentId,
                name: matchedComponent.name,
                imageUrl: matchedComponent.imageUrl,
                fingerIndex: fIdx,
                posX: 0,
                posY: 0,
                scale: 0.5,
                rotation: 0,
              ),
            );
          }
        }
      }
    }

    setState(() {
      _selectedNailShape = resolvedShape;
      _selectedNailSurface = resolvedSurface;
      _selectedComponent = resolvedSelectedComponent;
      _fingerColors.clear();
      _fingerColors.addAll(initialColors);
      _fingerGradients
        ..clear()
        ..addAll(initialGradients);
      _placements
        ..clear()
        ..addAll(resolvedPlacements);
      _selectedPlacementId = _placements.isEmpty ? null : _placements.first.localId;
    });
  }

  Future<void> _reGenerateDesign() async {
    setState(() => _isSaving = true);
    try {
      final quizRepo = QuizRepository(getIt<ApiClient>());
      final res = await quizRepo.getCustomerNailComposition();
      if (mounted) {
        _applyRecommendedData(res);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo lại thiết kế móng phù hợp mới!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tạo lại thiết kế: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _applyToAllFingers() {
    final srcIdx = _selectedFingerIndex;
    if (srcIdx == -1) return;

    final currentColor = _fingerColors[srcIdx] ?? '#FF4081';
    final currentGradient = _fingerGradients[srcIdx];
    final srcPlacements = _placements
        .where((p) => placementMatchesFinger(p.fingerIndex, srcIdx))
        .toList();

    setState(() {
      for (var i = 1; i <= 5; i++) {
        _fingerColors[i] = currentColor;
        _fingerGradients[i] = currentGradient == null ? null : [...currentGradient];
      }

      _placements.removeWhere((p) => !placementMatchesFinger(p.fingerIndex, srcIdx));

      int localIdCounter = DateTime.now().microsecondsSinceEpoch;
      for (var fIdx = 1; fIdx <= 5; fIdx++) {
        if (fIdx == srcIdx) continue;
        for (final p in srcPlacements) {
          _placements.add(
            PlacedComponentDraft(
              localId: localIdCounter++,
              component: p.component,
              componentId: p.componentId,
              customerComponentId: p.customerComponentId,
              name: p.name,
              imageUrl: p.imageUrl,
              fingerIndex: fIdx,
              posX: p.posX,
              posY: p.posY,
              scale: p.scale,
              rotation: p.rotation,
            ),
          );
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã áp dụng mẫu thiết kế của ngón này cho tất cả các ngón!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  NailShapeModel? _resolveShape(
    List<NailShapeModel> shapes,
    CustomerNailModel? nail,
  ) {
    if (nail == null) return shapes.isEmpty ? null : shapes.first;
    return shapes
            .where((shape) => shape.nailShapeId == nail.nailShapeId)
            .firstOrNull ??
        nail.nailShape ??
        (shapes.isEmpty ? null : shapes.first);
  }

  NailSurfaceModel? _resolveSurface(
    List<NailSurfaceModel> surfaces,
    CustomerNailModel? nail,
  ) {
    if (nail == null) return surfaces.isEmpty ? null : surfaces.first;
    return surfaces
            .where((surface) => surface.nailSurfaceId == nail.nailSurfaceId)
            .firstOrNull ??
        nail.nailSurface ??
        (surfaces.isEmpty ? null : surfaces.first);
  }

  List<PlacedComponentDraft> _buildDrafts(
    CustomerNailModel? nail,
    List<CombinedComponent> components,
  ) {
    if (nail == null) return const [];
    return nail.customerNailComponents.map((item) {
      final component = components.firstWhereOrNull((component) {
        if (item.customerComponentId != null) {
          return component.isCustomerComponent &&
              component.customerComponentId == item.customerComponentId;
        }
        if (item.componentId != null) {
          return !component.isCustomerComponent &&
              component.componentId == item.componentId;
        }
        return false;
      });
      return PlacedComponentDraft.fromCustomerNailComponent(
        item,
        component: component,
      );
    }).toList();
  }

  void _addSelectedComponent() {
    final component = _selectedComponent;
    if (component == null) return;
    final targetFingers = _selectedFingerIndex == -1
        ? [1, 2, 3, 4, 5]
        : [_selectedFingerIndex];
    final createdAt = DateTime.now().microsecondsSinceEpoch;
    final drafts = [
      for (var index = 0; index < targetFingers.length; index++)
        PlacedComponentDraft(
          localId: createdAt + index,
          component: component,
          componentId: component.componentId,
          customerComponentId: component.customerComponentId,
          name: component.name,
          imageUrl: component.imageUrl,
          fingerIndex: targetFingers[index],
          posX: 0,
          posY: 0,
          scale: 0.5,
          rotation: 0,
        ),
    ];
    setState(() {
      _placements.addAll(drafts);
      _selectedPlacementId = drafts.last.localId;
    });
  }

  void _removeSelectedPlacement() {
    final selected = _selectedPlacement;
    if (selected == null) return;
    setState(() {
      if (selected.customerNailComponentId != null) {
        _deletedPlacementIds.add(selected.customerNailComponentId!);
      }
      _placements.removeWhere((item) => item.localId == selected.localId);
      _selectedPlacementId = _placements.isEmpty
          ? null
          : _placements.last.localId;
    });
  }

  DateTime? _lastScaleWarningTime;
  void _showScaleWarning() {
    final now = DateTime.now();
    if (_lastScaleWarningTime == null ||
        now.difference(_lastScaleWarningTime!) > const Duration(seconds: 4)) {
      _lastScaleWarningTime = now;
      _showMessage('Kích thước phụ kiện lớn hơn bề ngang móng, vui lòng thu nhỏ lại.');
    }
  }

  void _updatePlacement(PlacedComponentDraft updated) {
    final index = _placements.indexWhere((p) => p.localId == updated.localId);
    if (index != -1) {
      setState(() {
        _placements[index] = updated;
      });
      if (updated.scale > 1.2) {
        _showScaleWarning();
      }
    }
  }

  void _deletePlacementById(int localId) {
    setState(() {
      final index = _placements.indexWhere((p) => p.localId == localId);
      if (index != -1) {
        final placement = _placements[index];
        if (placement.customerNailComponentId != null) {
          _deletedPlacementIds.add(placement.customerNailComponentId!);
        }
        _placements.removeAt(index);
      }
      if (_selectedPlacementId == localId) {
        _selectedPlacementId = _placements.isEmpty ? null : _placements.last.localId;
      }
    });
  }

  void _nudge({
    double dx = 0,
    double dy = 0,
    double scale = 0,
    double rotation = 0,
  }) {
    final index = _selectedPlacementIndex;
    if (index == -1) return;
    final current = _placements[index];
    setState(() {
      _placements[index] = current.copyWith(
        posX: (current.posX + dx).clamp(-0.5, 0.5).toDouble(),
        posY: (current.posY + dy).clamp(-0.5, 0.5).toDouble(),
        scale: (current.scale + scale).clamp(0.1, 1.5).toDouble(),
        rotation: current.rotation + rotation,
      );
    });
  }

  void _togglePreviewDetailFinger(int fingerIndex) {
    setState(() {
      _previewDetailFingerIndex = _previewDetailFingerIndex == fingerIndex
          ? null
          : fingerIndex;
      _selectedFingerIndex = _previewDetailFingerIndex ?? -1;
    });
  }

  Future<void> _navigateToMethodSelection() async {
    final preview = _buildPreviewNail();
    if (preview == null) {
      _showMessage('Vui lòng chọn dáng móng.');
      return;
    }
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => TryOnMethodSelectionScreen(
          previewNail: preview,
          tryOnData: _tryOnData!,
          selectedShape: _selectedNailShape,
          selectedSurface: _selectedNailSurface,
          fingerColors: _fingerColors,
          fingerGradients: _fingerGradients,
          placements: _placements,
        ),
      ),
    );

    if (result is SnapshotEditorResult) {
      setState(() {
        _selectedNailShape = result.selectedShape;
        _selectedNailSurface = result.selectedSurface;
        _fingerColors.clear();
        _fingerColors.addAll(result.fingerColors);
        _fingerGradients.clear();
        _fingerGradients.addAll(result.fingerGradients);
        _placements.clear();
        _placements.addAll(result.placements);
        _selectedPlacementId = _placements.isEmpty ? null : _placements.first.localId;
      });
    }
  }

  String _buildColorJson() {
    return jsonEncode({
      'mode': 'perFinger',
      'color': null,
      'gradient': null,
      'fingers': [
        for (var i = 1; i <= 5; i++)
          {
            'fingerIndex': i,
            'color': _fingerColors[i] ?? '#FF4081',
            'gradient': _fingerGradients[i] == null
                ? null
                : {
                    'enabled': true,
                    'type': 'linear',
                    'stops': _fingerGradients[i],
                    'stopCount': _fingerGradients[i]!.length,
                  },
          },
      ],
    });
  }

  Future<void> _save() async {
    final shape = _selectedNailShape;
    if (shape == null) {
      _showMessage('Vui lòng chọn dáng móng.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      int targetNailId;
      String targetName = 'My Custom Design';

      if (_customerNail == null) {
        // Create new design first
        targetNailId = await _customerNailRepository.createCustomerNail(
          name: targetName,
          isPublic: false,
        );
      } else {
        targetNailId = _customerNail!.customerNailId;
        targetName = _customerNail!.name;
      }

      await _customerNailRepository.updateCustomerNail(
        customerNailId: targetNailId,
        name: targetName,
        nailShapeId: shape.nailShapeId,
        nailSurfaceId: _selectedNailSurface?.nailSurfaceId,
        customColor: _buildColorJson(),
        isPublic: _customerNail?.isPublic ?? false,
      );

      for (final id in _deletedPlacementIds) {
        await _componentRepository.deleteCustomerNailComponent(id);
      }

      for (final placement in _placements) {
        final payload = placement.toPayload(targetNailId);
        if (placement.customerNailComponentId == null) {
          await _componentRepository.createCustomerNailComponent(
            customerNailId: payload.customerNailId,
            componentId: payload.componentId,
            customerComponentId: payload.customerComponentId,
            posX: payload.posX,
            posY: payload.posY,
            fingerIndex: payload.fingerIndex,
            configJson: payload.configJson,
          );
        } else {
          await _componentRepository.updateCustomerNailComponent(
            customerNailComponentId: placement.customerNailComponentId!,
            customerNailId: payload.customerNailId,
            componentId: payload.componentId,
            customerComponentId: payload.customerComponentId,
            posX: payload.posX,
            posY: payload.posY,
            fingerIndex: payload.fingerIndex,
            configJson: payload.configJson,
          );
        }
      }

      _deletedPlacementIds.clear();
      final fresh = await _customerNailRepository.getCustomerNailById(targetNailId);
      setState(() => _customerNail = fresh);
      if (mounted) _showMessage('Đã lưu thiết lập thử móng.');
      await _fetchData();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  CustomerNailModel? _buildPreviewNail() {
    final shape = _selectedNailShape;
    if (shape == null) return null;
    final nail = _customerNail;
    return CustomerNailModel(
      customerNailId: nail?.customerNailId ?? 0,
      name: nail?.name ?? 'Custom Nail',
      imageUrl: nail?.imageUrl ?? '',
      nailShapeId: shape.nailShapeId,
      nailSurfaceId: _selectedNailSurface?.nailSurfaceId ?? nail?.nailSurfaceId,
      price: nail?.price,
      customColor: _buildColorJson(),
      duration: nail?.duration,
      isPublic: nail?.isPublic ?? false,
      nailShape: shape,
      nailSurface: _selectedNailSurface ?? nail?.nailSurface,
      customerNailComponents: _placements
          .map(
            (placement) =>
                placement.toCustomerNailComponent(nail?.customerNailId ?? 0),
          )
          .toList(),
    );
  }

  String get _activeFingerColor {
    return _selectedFingerIndex == -1
        ? (_fingerColors[2] ?? '#FF4081')
        : (_fingerColors[_selectedFingerIndex] ?? '#FF4081');
  }

  List<String>? get _activeFingerGradient {
    return _selectedFingerIndex == -1
        ? _fingerGradients[2]
        : _fingerGradients[_selectedFingerIndex];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      appBar: AppBar(
        title: Text(_customerNail == null ? 'Thiết kế móng' : _customerNail!.name),
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildBody()),
          if (_launching)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x99FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _launching ? null : _navigateToMethodSelection,
                icon: const Icon(Icons.camera_alt_rounded, size: 24),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFCE4EC),
                  foregroundColor: const Color(0xFFE91E63),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              if (widget.recommendedData?['fromPerfectMatch'] == true) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _reGenerateDesign,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFE91E63),
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    'Gen lại',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE91E63),
                    side: const BorderSide(color: Color(0xFFFFD1E1), width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_selectedNailShape != null && !_isSaving) ? _save : null,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 20),
                  label: const Text('Lưu thiết kế', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade400,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: (_selectedNailShape != null && !_isSaving) ? 2 : 0,
                    shadowColor: const Color(0xFFE91E63).withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildErrorWidget();
    final data = _tryOnData;
    if (data == null) return const Center(child: Text('No data available'));

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          // Phần trên: Bảng Preview cố định (sử dụng Expanded để tự động giãn nở khi panel thu lại)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0, bottom: 8.0),
              child: TryOnPreviewBoard(
                nail: _customerNail,
                selectedShape: _selectedNailShape,
                selectedSurface: _selectedNailSurface,
                selectedColor: _activeFingerColor,
                gradientStops: _activeFingerGradient,
                fingerColors: _fingerColors,
                fingerGradients: _fingerGradients,
                selectedFingerIndex: _selectedFingerIndex,
                detailFingerIndex: _previewDetailFingerIndex,
                placements: _placements,
                selectedPlacementId: _selectedPlacementId,
                onSelectPlacement: (id) => setState(() => _selectedPlacementId = id),
                onUpdatePlacement: _updatePlacement,
                onDeletePlacement: _deletePlacementById,
                onToggleDetailFinger: _togglePreviewDetailFinger,
                onApplyToAll: _applyToAllFingers,
              ),
            ),
          ),

          // Phần dưới: Điều khiển công cụ (AnimatedContainer để co giãn chiều cao mượt mà)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: double.infinity,
            height: _isSelectorExpanded ? 220 : 108,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(left: 16, top: 12, bottom: 12, right: 8),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TabBar(
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.grey.shade600,
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          tabs: const [
                            Tab(text: 'Dáng móng'),
                            Tab(text: 'Bề mặt'),
                            Tab(text: 'Màu sắc'),
                            Tab(text: 'Phụ kiện'),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _isSelectorExpanded = !_isSelectorExpanded),
                      icon: Icon(
                        _isSelectorExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                        color: const Color(0xFFE91E63),
                        size: 26,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFFCE4EC),
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),

                if (!_isSelectorExpanded)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12, left: 16, right: 16),
                    child: Text(
                      'Bấm nút mũi tên bên phải để hiển thị bảng thiết kế móng',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ),

                // Nội dung Tab (chỉ hiển thị khi panel được mở rộng)
                if (_isSelectorExpanded)
                  Expanded(
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _buildShapeTool(data),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _buildSurfaceTool(data),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _buildColorTool(),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _buildComponentsTab(data),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentsTab(TryOnData data) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildComponentsTool(data),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        _buildPlacementTool(),
      ],
    );
  }

  Widget _buildPlacementTool() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedPlacement?.name ?? 'Chưa chọn phụ kiện trên móng',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _selectedPlacement != null ? const Color(0xFFE91E63) : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FilledButton.icon(
                onPressed: _selectedComponent == null ? null : _addSelectedComponent,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Thêm vào móng', style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        TryOnPlacementControls(
          selectedPlacement: _selectedPlacement,
          onMoveLeft: () => _nudge(dx: -0.04),
          onMoveRight: () => _nudge(dx: 0.04),
          onMoveUp: () => _nudge(dy: -0.04),
          onMoveDown: () => _nudge(dy: 0.04),
          onScaleDown: () => _nudge(scale: -0.05),
          onScaleUp: () => _nudge(scale: 0.05),
          onRotateLeft: () => _nudge(rotation: -10),
          onRotateRight: () => _nudge(rotation: 10),
          onRemove: _removeSelectedPlacement,
        ),
      ],
    );
  }

  Widget _buildShapeTool(TryOnData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: NailShapeSelector(
        shapes: data.nailShapes,
        selectedShape: _selectedNailShape,
        showTitle: false,
        onSelected: (shape) => setState(() => _selectedNailShape = shape),
      ),
    );
  }

  Widget _buildSurfaceTool(TryOnData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: NailSurfaceSelector(
        surfaces: data.nailSurfaces,
        selectedSurface: _selectedNailSurface,
        onSelected: (surface) => setState(() => _selectedNailSurface = surface),
      ),
    );
  }

  Widget _buildColorTool() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TryOnColorSelector(
        selectedColor: _activeFingerColor,
        gradientStops: _activeFingerGradient,
        showTitle: false,
        onColorSelected: (color) => setState(() {
          if (_selectedFingerIndex == -1) {
            for (var i = 1; i <= 5; i++) {
              _fingerColors[i] = color;
            }
          } else {
            _fingerColors[_selectedFingerIndex] = color;
          }
        }),
        onGradientChanged: (gradient) => setState(() {
          if (_selectedFingerIndex == -1) {
            for (var i = 1; i <= 5; i++) {
              _fingerGradients[i] = gradient == null ? null : [...gradient];
            }
          } else {
            _fingerGradients[_selectedFingerIndex] = gradient == null ? null : [...gradient];
          }
        }),
      ),
    );
  }

  Widget _buildComponentsTool(TryOnData data) {
    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: const Color(0xFFE91E63),
              unselectedLabelColor: Colors.grey.shade600,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              tabs: const [
                Tab(text: 'Mẫu hệ thống'),
                Tab(text: 'Phụ kiện của tôi'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130, // Optimized height matching compact 120px ComponentGrid
            child: TabBarView(
              children: [
                ComponentGrid(
                  title: '',
                  components: data.combinedComponents.where((item) => !item.isCustomerComponent).toList(),
                  selectedComponent: _selectedComponent,
                  onSelected: (component) {
                    setState(() {
                      _selectedComponent = component;
                    });
                    _addSelectedComponent();
                  },
                ),
                ComponentGrid(
                  title: '',
                  components: data.combinedComponents.where((item) => item.isCustomerComponent).toList(),
                  selectedComponent: _selectedComponent,
                  onSelected: (component) {
                    setState(() {
                      _selectedComponent = component;
                    });
                    _addSelectedComponent();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error ?? '', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
        ],
      ),
    );
  }

  int get _selectedPlacementIndex {
    return _placements.indexWhere(
      (item) => item.localId == _selectedPlacementId,
    );
  }

  PlacedComponentDraft? get _selectedPlacement {
    final index = _selectedPlacementIndex;
    return index == -1 ? null : _placements[index];
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}