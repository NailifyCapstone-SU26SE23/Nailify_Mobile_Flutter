import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../nails/data/models/customer_nail_models.dart';
import '../../nails/data/models/nail_shape_model.dart';
import '../../nails/data/models/nail_surface_model.dart';
import '../../nails/data/repositories/customer_nail_repository.dart';
import '../../nails/data/repositories/nail_component_repository.dart';
import '../../nails/services/ar_try_on_service.dart';
import '../../../core/network/api_client.dart';
import '../../quiz/data/datasources/quiz_repository.dart';
import '../models/placed_component_draft.dart';
import '../models/try_on_data.dart';
import '../services/try_on_setup_service.dart';
import '../utils/try_on_setup_helpers.dart';
import '../widgets/component_grid.dart';
import '../widgets/nail_shape_selector.dart';
import '../widgets/nail_surface_selector.dart';
import '../widgets/try_on_action_bar.dart';
import '../widgets/try_on_color_selector.dart';
import '../widgets/try_on_placement_controls.dart';
import '../widgets/try_on_preview_board.dart';

class TryOnSetupScreen extends StatefulWidget {
  final CustomerNailModel? customerNail;
  final Map<String, dynamic>? recommendedData;

  const TryOnSetupScreen({super.key, this.customerNail, this.recommendedData});

  @override
  State<TryOnSetupScreen> createState() => _TryOnSetupScreenState();
}

class _TryOnSetupScreenState extends State<TryOnSetupScreen>
    with SingleTickerProviderStateMixin {
  late final TryOnSetupService _setupService;
  late final NailComponentRepository _componentRepository;
  late final CustomerNailRepository _customerNailRepository;
  late final QuizRepository _quizRepo;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSelectorExpanded = true;
  bool _launching = false;
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
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    _setupService = getIt<TryOnSetupService>();
    _componentRepository = getIt<NailComponentRepository>();
    _customerNailRepository = getIt<CustomerNailRepository>();
    _quizRepo = QuizRepository(getIt<ApiClient>());
    _fetchData();
  }

  void _handleTabChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _setupService.fetchTryOnData(),
        if ((widget.customerNail?.customerNailId ?? 0) > 0)
          _customerNailRepository.getCustomerNailById(
            widget.customerNail!.customerNailId,
          ),
      ]);
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
      } else if (widget.recommendedData != null) {
        final recColors = widget.recommendedData!['colors'];
        if (recColors is List && recColors.isNotEmpty) {
          for (var i = 1; i <= 5; i++) {
            final colorHex = recColors[(i - 1) % recColors.length]
                .toString()
                .trim();
            if (colorHex.startsWith('#')) {
              initialColors[i] = colorHex;
            }
          }
        } else {
          final recColor = widget.recommendedData!['color'];
          if (recColor is String && recColor.startsWith('#')) {
            for (var i = 1; i <= 5; i++) {
              initialColors[i] = recColor;
            }
          }
        }
      }

      NailShapeModel? selectedShape;
      if (customerNail != null) {
        selectedShape = _resolveShape(data.nailShapes, customerNail);
      } else if (widget.recommendedData != null) {
        final shapeData = widget.recommendedData!['nailShape'];
        final shapeId = shapeData != null
            ? asTryOnInt(shapeData['nailShapeId'] ?? shapeData['id'])
            : null;
        if (shapeId != null && shapeId > 0) {
          selectedShape = data.nailShapes.firstWhereOrNull(
            (s) => s.nailShapeId == shapeId,
          );
        }
        if (selectedShape == null && shapeData != null) {
          final shapeName = shapeData['name']?.toString().toLowerCase();
          if (shapeName != null) {
            selectedShape = data.nailShapes.firstWhereOrNull(
              (s) => s.name.toLowerCase() == shapeName,
            );
          }
        }
      }
      selectedShape ??= data.nailShapes.isEmpty ? null : data.nailShapes.first;

      NailSurfaceModel? selectedSurface;
      if (customerNail != null) {
        selectedSurface = _resolveSurface(data.nailSurfaces, customerNail);
      } else if (widget.recommendedData != null) {
        final surfaceData = widget.recommendedData!['nailSurface'];
        final surfaceId = surfaceData != null
            ? asTryOnInt(surfaceData['nailSurfaceId'] ?? surfaceData['id'])
            : null;
        if (surfaceId != null && surfaceId > 0) {
          selectedSurface = data.nailSurfaces.firstWhereOrNull(
            (s) => s.nailSurfaceId == surfaceId,
          );
        }
        if (selectedSurface == null && surfaceData != null) {
          final surfaceName = surfaceData['name']?.toString().toLowerCase();
          if (surfaceName != null) {
            selectedSurface = data.nailSurfaces.firstWhereOrNull(
              (s) => s.name.toLowerCase() == surfaceName,
            );
          }
        }
      }
      selectedSurface ??= data.nailSurfaces.isEmpty
          ? null
          : data.nailSurfaces.first;

      final List<PlacedComponentDraft> initialPlacements = [];
      if (customerNail != null) {
        initialPlacements.addAll(
          _buildDrafts(customerNail, data.combinedComponents),
        );
      } else if (widget.recommendedData != null) {
        final recComponents = widget.recommendedData!['components'];
        if (recComponents is List) {
          final componentCreatedAt = DateTime.now().microsecondsSinceEpoch;
          for (var index = 0; index < recComponents.length; index++) {
            final compMap = recComponents[index];
            if (compMap is Map) {
              final compId = asTryOnInt(
                compMap['componentId'] ?? compMap['id'],
              );
              final custCompId = asTryOnInt(compMap['customerComponentId']);

              final matchedComp = data.combinedComponents.firstWhereOrNull((c) {
                if (custCompId > 0) {
                  return c.isCustomerComponent &&
                      c.customerComponentId == custCompId;
                }
                if (compId > 0) {
                  return !c.isCustomerComponent && c.componentId == compId;
                }
                return false;
              });

              if (matchedComp != null) {
                final fIndex = asTryOnInt(
                  compMap['fingerIndex'] ?? compMap['FingerIndex'],
                  fallback: 3,
                );
                final normFinger = normalizeFingerIndexFromApi(fIndex);

                initialPlacements.add(
                  PlacedComponentDraft(
                    localId: componentCreatedAt + index,
                    component: matchedComp,
                    componentId: matchedComp.componentId,
                    customerComponentId: matchedComp.customerComponentId,
                    name: matchedComp.name,
                    imageUrl: matchedComp.imageUrl,
                    fingerIndex: normFinger,
                    posX: asTryOnDouble(
                      compMap['posX'] ?? compMap['PosX'],
                      fallback: 0,
                    ),
                    posY: asTryOnDouble(
                      compMap['posY'] ?? compMap['PosY'],
                      fallback: 0,
                    ),
                    scale: asTryOnDouble(
                      compMap['scale'] ?? compMap['Scale'],
                      fallback: 0.5,
                    ),
                    rotation: asTryOnDouble(
                      compMap['rotation'] ?? compMap['Rotation'],
                      fallback: 0,
                    ),
                  ),
                );
              }
            }
          }
        }
      }

      setState(() {
        _tryOnData = data;
        _customerNail = customerNail;
        _selectedNailShape = selectedShape;
        _selectedNailSurface = selectedSurface;
        _fingerColors.clear();
        _fingerColors.addAll(initialColors);
        _fingerGradients
          ..clear()
          ..addAll(initialGradients);
        _placements
          ..clear()
          ..addAll(initialPlacements);
        _selectedPlacementId = _placements.isEmpty
            ? null
            : _placements.first.localId;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
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
    _deletePlacement(selected.localId);
  }

  void _updatePlacement(PlacedComponentDraft placement) {
    final index = _placements.indexWhere(
      (item) => item.localId == placement.localId,
    );
    if (index == -1) return;
    setState(() {
      _placements[index] = placement;
      _selectedPlacementId = placement.localId;
    });
  }

  void _deletePlacement(int localId) {
    final index = _placements.indexWhere((item) => item.localId == localId);
    if (index == -1) return;
    final selected = _placements[index];
    setState(() {
      if (selected.customerNailComponentId != null) {
        _deletedPlacementIds.add(selected.customerNailComponentId!);
      }
      _placements.removeAt(index);
      _selectedPlacementId = _placements.isEmpty
          ? null
          : _placements.last.localId;
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

  Future<void> _regenerateDesign() async {
    setState(() => _launching = true);
    try {
      final res = await _quizRepo.getCustomerNailComposition();
      final data = _tryOnData;
      if (data == null) return;

      final Map<int, String> newColors = {
        1: '#FF4081',
        2: '#FF4081',
        3: '#FF4081',
        4: '#FF4081',
        5: '#FF4081',
      };
      final Map<int, List<String>?> newGradients = {
        1: null,
        2: null,
        3: null,
        4: null,
        5: null,
      };

      final recColors = res['colors'];
      if (recColors is List && recColors.isNotEmpty) {
        for (var i = 1; i <= 5; i++) {
          final colorHex = recColors[(i - 1) % recColors.length]
              .toString()
              .trim();
          if (colorHex.startsWith('#')) {
            newColors[i] = colorHex;
          }
        }
      } else {
        final recColor = res['color'];
        if (recColor is String && recColor.startsWith('#')) {
          for (var i = 1; i <= 5; i++) {
            newColors[i] = recColor;
          }
        }
      }

      NailShapeModel? selectedShape;
      final shapeData = res['nailShape'];
      final shapeId = shapeData != null
          ? asTryOnInt(shapeData['nailShapeId'] ?? shapeData['id'])
          : null;
      if (shapeId != null && shapeId > 0) {
        selectedShape = data.nailShapes.firstWhereOrNull(
          (s) => s.nailShapeId == shapeId,
        );
      }
      if (selectedShape == null && shapeData != null) {
        final shapeName = shapeData['name']?.toString().toLowerCase();
        if (shapeName != null) {
          selectedShape = data.nailShapes.firstWhereOrNull(
            (s) => s.name.toLowerCase() == shapeName,
          );
        }
      }
      selectedShape ??=
          _selectedNailShape ??
          (data.nailShapes.isEmpty ? null : data.nailShapes.first);

      NailSurfaceModel? selectedSurface;
      final surfaceData = res['nailSurface'];
      final surfaceId = surfaceData != null
          ? asTryOnInt(surfaceData['nailSurfaceId'] ?? surfaceData['id'])
          : null;
      if (surfaceId != null && surfaceId > 0) {
        selectedSurface = data.nailSurfaces.firstWhereOrNull(
          (s) => s.nailSurfaceId == surfaceId,
        );
      }
      if (selectedSurface == null && surfaceData != null) {
        final surfaceName = surfaceData['name']?.toString().toLowerCase();
        if (surfaceName != null) {
          selectedSurface = data.nailSurfaces.firstWhereOrNull(
            (s) => s.name.toLowerCase() == surfaceName,
          );
        }
      }
      selectedSurface ??=
          _selectedNailSurface ??
          (data.nailSurfaces.isEmpty ? null : data.nailSurfaces.first);

      final List<PlacedComponentDraft> newPlacements = [];
      final recComponents = res['components'];
      if (recComponents is List) {
        final componentCreatedAt = DateTime.now().microsecondsSinceEpoch;
        for (var index = 0; index < recComponents.length; index++) {
          final compMap = recComponents[index];
          if (compMap is Map) {
            final compId = asTryOnInt(compMap['componentId'] ?? compMap['id']);
            final custCompId = asTryOnInt(compMap['customerComponentId']);

            final matchedComp = data.combinedComponents.firstWhereOrNull((c) {
              if (custCompId > 0) {
                return c.isCustomerComponent &&
                    c.customerComponentId == custCompId;
              }
              if (compId > 0) {
                return !c.isCustomerComponent && c.componentId == compId;
              }
              return false;
            });

            if (matchedComp != null) {
              final fIndex = asTryOnInt(
                compMap['fingerIndex'] ?? compMap['FingerIndex'],
                fallback: 3,
              );
              final normFinger = normalizeFingerIndexFromApi(fIndex);

              newPlacements.add(
                PlacedComponentDraft(
                  localId: componentCreatedAt + index,
                  component: matchedComp,
                  componentId: matchedComp.componentId,
                  customerComponentId: matchedComp.customerComponentId,
                  name: matchedComp.name,
                  imageUrl: matchedComp.imageUrl,
                  fingerIndex: normFinger,
                  posX: asTryOnDouble(
                    compMap['posX'] ?? compMap['PosX'],
                    fallback: 0,
                  ),
                  posY: asTryOnDouble(
                    compMap['posY'] ?? compMap['PosY'],
                    fallback: 0,
                  ),
                  scale: asTryOnDouble(
                    compMap['scale'] ?? compMap['Scale'],
                    fallback: 0.5,
                  ),
                  rotation: asTryOnDouble(
                    compMap['rotation'] ?? compMap['Rotation'],
                    fallback: 0,
                  ),
                ),
              );
            }
          }
        }
      }

      setState(() {
        _selectedNailShape = selectedShape;
        _selectedNailSurface = selectedSurface;
        _fingerColors.clear();
        _fingerColors.addAll(newColors);
        _fingerGradients.clear();
        _fingerGradients.addAll(newGradients);
        _placements.clear();
        _placements.addAll(newPlacements);
        _selectedPlacementId = _placements.isEmpty
            ? null
            : _placements.first.localId;
      });
      _showMessage('Đã tạo lại thiết kế mới.');
    } catch (e) {
      _showMessage('Lỗi khi tạo lại thiết kế: ${e.toString()}');
    } finally {
      setState(() => _launching = false);
    }
  }

  Future<void> _launchTryOn({required bool photo}) async {
    final preview = _buildPreviewNail();
    if (preview == null) {
      _showMessage('Vui lòng chọn dáng móng.');
      return;
    }

    setState(() => _launching = true);
    try {
      final service = getIt<ArTryOnService>();
      final available = await service.isAvailable();
      if (!available) {
        throw UnsupportedError(
          'Virtual try-on is not available on this build.',
        );
      }
      if (photo) {
        await service.launchCustomerPhoto(preview, context: context);
      } else {
        await service.launchCustomerLive(preview, context: context);
      }
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _launching = false);
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
    final nail = _customerNail;
    final shape = _selectedNailShape;
    if (shape == null) {
      _showMessage('Vui lòng tạo mẫu móng và chọn dáng móng.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      var customerNailId = nail?.customerNailId ?? 0;
      final isNewCustomerNail = customerNailId <= 0;
      final nailName = nail?.name.trim().isNotEmpty == true
          ? nail!.name
          : 'Custom Nail';

      if (customerNailId <= 0) {
        customerNailId = await _customerNailRepository.createCustomerNail(
          name: nailName,
        );
      }

      await _customerNailRepository.updateCustomerNail(
        customerNailId: customerNailId,
        name: nailName,
        nailShapeId: shape.nailShapeId,
        nailSurfaceId: _selectedNailSurface?.nailSurfaceId,
        customColor: _buildColorJson(),
      );

      for (final id in _deletedPlacementIds) {
        await _componentRepository.deleteCustomerNailComponent(id);
      }

      for (final placement in _placements) {
        final payload = placement.toPayload(customerNailId);
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
      final fresh = await _customerNailRepository.getCustomerNailById(
        customerNailId,
      );
      setState(() => _customerNail = fresh);
      _showMessage('Đã lưu thiết lập thử móng.');
      if ((widget.customerNail?.customerNailId ?? 0) > 0) {
        await _fetchData();
      }
      if (mounted) {
        if (isNewCustomerNail) {
          context.go('/my-studio');
        } else {
          Navigator.of(context).pop(true);
        }
      }
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
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      appBar: AppBar(
        title: Text(
          _customerNail == null ? 'Thiết kế móng' : _customerNail!.name,
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_launching)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x99FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      bottomNavigationBar: TryOnActionBar(
        canSave: _selectedNailShape != null,
        isSaving: _isSaving,
        isLaunching: _launching,
        onSave: _save,
        onLiveTryOn: () => _launchTryOn(photo: false),
        onPhotoTryOn: () => _launchTryOn(photo: true),
        onRegenerate: widget.recommendedData != null ? _regenerateDesign : null,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildErrorWidget();
    final data = _tryOnData;
    if (data == null) return const Center(child: Text('No data available'));

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              top: 16.0,
              left: 16.0,
              right: 16.0,
              bottom: 8.0,
            ),
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
              onSelectPlacement: (id) =>
                  setState(() => _selectedPlacementId = id),
              onUpdatePlacement: _updatePlacement,
              onDeletePlacement: _deletePlacement,
              onToggleDetailFinger: _togglePreviewDetailFinger,
            ),
          ),
        ),

        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: double.infinity,
          height: _isSelectorExpanded ? 260 : 108,
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
                      margin: const EdgeInsets.only(
                        left: 16,
                        top: 12,
                        bottom: 12,
                        right: 8,
                      ),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFE91E63,
                              ).withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey.shade600,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
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
                    onPressed: () => setState(
                      () => _isSelectorExpanded = !_isSelectorExpanded,
                    ),
                    icon: Icon(
                      _isSelectorExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      color: const Color(0xFFE91E63),
                      size: 26,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFCE4EC),
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
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

              if (_isSelectorExpanded)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _buildActiveTabContent(data),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTabContent(TryOnData data) {
    switch (_tabController.index) {
      case 0:
        return _buildShapeTool(data);
      case 1:
        return _buildSurfaceTool(data);
      case 2:
        return _buildColorTool();
      case 3:
        return _buildComponentsTab(data);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildComponentsTab(TryOnData data) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Nửa trên: Danh sách phụ kiện
        _buildComponentsTool(data),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        // Nửa dưới: Remote D-Pad
        _buildPlacementTool(),
      ],
    );
  }

  Widget _buildPlacementTool() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedPlacement?.name ?? 'Chưa chọn phụ kiện trên móng',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _selectedPlacement != null
                          ? const Color(0xFFE91E63)
                          : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _selectedComponent == null
                      ? null
                      : _addSelectedComponent,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'Thêm vào móng',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
      ),
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
            _fingerGradients[_selectedFingerIndex] = gradient == null
                ? null
                : [...gradient];
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
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              tabs: const [
                Tab(text: 'Mẫu hệ thống'),
                Tab(text: 'Phụ kiện của tôi'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 170, // Đủ chỗ cho Grid 160px
            child: TabBarView(
              children: [
                ComponentGrid(
                  title: '',
                  components: data.combinedComponents
                      .where((item) => !item.isCustomerComponent)
                      .toList(),
                  selectedComponent: _selectedComponent,
                  onSelected: (component) =>
                      setState(() => _selectedComponent = component),
                ),
                ComponentGrid(
                  title: '',
                  components: data.combinedComponents
                      .where((item) => item.isCustomerComponent)
                      .toList(),
                  selectedComponent: _selectedComponent,
                  onSelected: (component) =>
                      setState(() => _selectedComponent = component),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
