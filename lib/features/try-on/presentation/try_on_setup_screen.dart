import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../nails/data/models/customer_nail_models.dart';
import '../../nails/data/models/nail_shape_model.dart';
import '../../nails/data/models/nail_surface_model.dart';
import '../../nails/data/repositories/customer_nail_repository.dart';
import '../../nails/data/repositories/nail_component_repository.dart';
import '../../nails/services/ar_try_on_service.dart';
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

class TryOnSetupScreen extends StatefulWidget {
  final CustomerNailModel? customerNail;

  const TryOnSetupScreen({super.key, this.customerNail});

  @override
  State<TryOnSetupScreen> createState() => _TryOnSetupScreenState();
}

class _TryOnSetupScreenState extends State<TryOnSetupScreen> {
  late final TryOnSetupService _setupService;
  late final NailComponentRepository _componentRepository;
  late final CustomerNailRepository _customerNailRepository;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _launching = false;
  final bool _showShapeSection = true;
  final bool _showSurfaceSection = true;
  final bool _showColorSection = true;
  final bool _showPlacementSection = true;
  final bool _showSystemComponents = true;
  final bool _showCustomerComponents = true;
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
      final results = await Future.wait([
        _setupService.fetchTryOnData(),
        if (widget.customerNail != null)
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
      }

      setState(() {
        _tryOnData = data;
        _customerNail = customerNail;
        _selectedNailShape = _resolveShape(data.nailShapes, customerNail);
        _selectedNailSurface = _resolveSurface(data.nailSurfaces, customerNail);
        _fingerColors.clear();
        _fingerColors.addAll(initialColors);
        _fingerGradients
          ..clear()
          ..addAll(initialGradients);
        _placements
          ..clear()
          ..addAll(_buildDrafts(customerNail, data.combinedComponents));
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

  void _navigateToMethodSelection() {
    final preview = _buildPreviewNail();
    if (preview == null) {
      _showMessage('Vui lòng chọn dáng móng.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TryOnMethodSelectionScreen(previewNail: preview),
      ),
    );
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
    if (nail == null || shape == null) {
      _showMessage('Vui lòng tạo mẫu móng và chọn dáng móng.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _customerNailRepository.updateCustomerNail(
        customerNailId: nail.customerNailId,
        name: nail.name,
        nailShapeId: shape.nailShapeId,
        nailSurfaceId: _selectedNailSurface?.nailSurfaceId,
        customColor: _buildColorJson(),
        isPublic: nail.isPublic,
      );

      for (final id in _deletedPlacementIds) {
        await _componentRepository.deleteCustomerNailComponent(id);
      }

      for (final placement in _placements) {
        final payload = placement.toPayload(nail.customerNailId);
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
        nail.customerNailId,
      );
      setState(() => _customerNail = fresh);
      _showMessage('Đã lưu thiết lập thử móng.');
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
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              )
            ],
          ),
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: _launching ? null : _navigateToMethodSelection,
                icon: const Icon(Icons.camera_alt, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.pink.shade50,
                  foregroundColor: Colors.pink,
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_customerNail != null && _selectedNailShape != null && !_isSaving) ? _save : null,
                  icon: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Icon(Icons.save),
                  label: const Text('Lưu thiết kế'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
          // Phần trên: Bảng Preview cố định
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
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
                onToggleDetailFinger: _togglePreviewDetailFinger,
              ),
            ),
          ),
          
          // Phần dưới: Điều khiển công cụ (Scrollable)
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  )
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. TabBar
                  const TabBar(
                    labelColor: Colors.pink,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.pink,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelStyle: TextStyle(fontWeight: FontWeight.bold),
                    tabs: [
                      Tab(text: "Dáng móng"),
                      Tab(text: "Bề mặt"),
                      Tab(text: "Màu sắc"),
                      Tab(text: "Phụ kiện"),
                    ],
                  ),
                  
                  // 2. Nội dung Tab
                  Expanded(
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: _buildShapeTool(data),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: _buildSurfaceTool(data),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: _buildColorTool(),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: _buildComponentsTab(data),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FilledButton.icon(
                onPressed: _selectedComponent == null ? null : _addSelectedComponent,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Thêm vào móng'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.pink,
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
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(text: 'System'),
                Tab(text: 'My Components'),
              ],
              indicatorSize: TabBarIndicatorSize.tab,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 170, // Đủ chỗ cho Grid 160px
            child: TabBarView(
              children: [
                ComponentGrid(
                  title: '',
                  components: data.combinedComponents.where((item) => !item.isCustomerComponent).toList(),
                  selectedComponent: _selectedComponent,
                  onSelected: (component) => setState(() => _selectedComponent = component),
                ),
                ComponentGrid(
                  title: '',
                  components: data.combinedComponents.where((item) => item.isCustomerComponent).toList(),
                  selectedComponent: _selectedComponent,
                  onSelected: (component) => setState(() => _selectedComponent = component),
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

