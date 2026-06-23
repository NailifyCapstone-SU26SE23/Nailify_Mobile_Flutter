import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../nails/data/models/customer_nail_models.dart';
import '../../nails/data/models/nail_shape_model.dart';
import '../../nails/data/repositories/customer_nail_repository.dart';
import '../../nails/data/repositories/nail_component_repository.dart';
import '../../nails/services/ar_try_on_service.dart';
import '../models/placed_component_draft.dart';
import '../models/try_on_data.dart';
import '../services/try_on_setup_service.dart';
import '../utils/try_on_setup_helpers.dart';
import '../widgets/component_grid.dart';
import '../widgets/nail_shape_selector.dart';
import '../widgets/try_on_action_bar.dart';
import '../widgets/try_on_color_selector.dart';
import '../widgets/try_on_finger_selector.dart';
import '../widgets/try_on_placement_controls.dart';
import '../widgets/try_on_preview_board.dart';

class TryOnSetupScreen extends StatefulWidget {
  final CustomerNailModel? customerNail;

  const TryOnSetupScreen({
    super.key,
    this.customerNail,
  });

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
  bool _showShapeSection = true;
  bool _showColorSection = true;
  bool _showPlacementSection = true;
  bool _showSystemComponents = true;
  bool _showCustomerComponents = true;
  String? _error;
  TryOnData? _tryOnData;
  CustomerNailModel? _customerNail;

  NailShapeModel? _selectedNailShape;
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
  int _selectedFingerIndex = 1;
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
          _customerNailRepository.getCustomerNailById(widget.customerNail!.customerNailId),
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
                final fIdx = asTryOnInt(finger['fingerIndex'] ?? finger['FingerIndex']);
                final color = finger['color'] ?? finger['Color'];
                if (fIdx >= 1 && fIdx <= 5 && color is String) {
                  initialColors[fIdx] = color;
                }
                final gradient = finger['gradient'] ?? finger['Gradient'];
                if (fIdx >= 1 && fIdx <= 5 && gradient is Map && gradient['enabled'] == true) {
                  final stops = gradient['stops'];
                  if (stops is List) {
                    initialGradients[fIdx] =
                        stops.map((item) => item.toString()).take(3).toList();
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
        _fingerColors.clear();
        _fingerColors.addAll(initialColors);
        _fingerGradients
          ..clear()
          ..addAll(initialGradients);
        _placements
          ..clear()
          ..addAll(_buildDrafts(customerNail, data.combinedComponents));
        _selectedPlacementId = _placements.isEmpty ? null : _placements.first.localId;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  NailShapeModel? _resolveShape(List<NailShapeModel> shapes, CustomerNailModel? nail) {
    if (nail == null) return shapes.isEmpty ? null : shapes.first;
    return shapes.where((shape) => shape.nailShapeId == nail.nailShapeId).firstOrNull ??
        nail.nailShape ??
        (shapes.isEmpty ? null : shapes.first);
  }

  List<PlacedComponentDraft> _buildDrafts(
    CustomerNailModel? nail,
    List<CombinedComponent> components,
  ) {
    if (nail == null) return const [];
    return nail.customerNailComponents.map((item) {
      final component = components.firstWhereOrNull(
        (component) {
          if (item.customerComponentId != null) {
            return component.isCustomerComponent &&
                component.customerComponentId == item.customerComponentId;
          }
          if (item.componentId != null) {
            return !component.isCustomerComponent &&
                component.componentId == item.componentId;
          }
          return false;
        },
      );
      return PlacedComponentDraft.fromCustomerNailComponent(item, component: component);
    }).toList();
  }

  void _addSelectedComponent() {
    final component = _selectedComponent;
    if (component == null) return;
    if (_selectedFingerIndex == -1) {
      _showMessage('Chọn một ngón tay trước khi thêm component.');
      return;
    }
    final draft = PlacedComponentDraft(
      localId: DateTime.now().microsecondsSinceEpoch,
      component: component,
      componentId: component.componentId,
      customerComponentId: component.customerComponentId,
      name: component.name,
      imageUrl: component.imageUrl,
      fingerIndex: _selectedFingerIndex,
      posX: 0,
      posY: 0,
      scale: 0.5,
      rotation: 0,
    );
    setState(() {
      _placements.add(draft);
      _selectedPlacementId = draft.localId;
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
      _selectedPlacementId = _placements.isEmpty ? null : _placements.last.localId;
    });
  }

  void _nudge({double dx = 0, double dy = 0, double scale = 0, double rotation = 0}) {
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

  void _selectFinger(int value) {
    setState(() {
      _selectedFingerIndex = value;
    });
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
      if (!available) throw UnsupportedError('Virtual try-on is not available on this build.');
      if (photo) {
        await service.launchCustomerPhoto(preview);
      } else {
        await service.launchCustomerLive(preview);
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
          }
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
      final fresh = await _customerNailRepository.getCustomerNailById(nail.customerNailId);
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
      nailSurfaceId: nail?.nailSurfaceId,
      price: nail?.price,
      customColor: _buildColorJson(),
      duration: nail?.duration,
      isPublic: nail?.isPublic ?? false,
      nailShape: shape,
      nailSurface: nail?.nailSurface,
      customerNailComponents: _placements
          .map((placement) => placement.toCustomerNailComponent(nail?.customerNailId ?? 0))
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
      appBar: AppBar(
        title: Text(_customerNail == null ? 'Set up try-on' : _customerNail!.name),
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
        selectedNailShape: _selectedNailShape,
        selectedComponent: _selectedComponent,
        canSave: _customerNail != null && _selectedNailShape != null,
        isSaving: _isSaving,
        onLiveTryOn: () => _launchTryOn(photo: false),
        onPhotoTryOn: () => _launchTryOn(photo: true),
        onSave: _save,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildErrorWidget();
    final data = _tryOnData;
    if (data == null) return const Center(child: Text('No data available'));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        TryOnPreviewBoard(
          nail: _customerNail,
          selectedShape: _selectedNailShape,
          selectedColor: _activeFingerColor,
          gradientStops: _activeFingerGradient,
          selectedFingerIndex: _selectedFingerIndex,
          placements: _placements,
          selectedPlacementId: _selectedPlacementId,
          onSelectPlacement: (id) => setState(() => _selectedPlacementId = id),
        ),
        const SizedBox(height: 16),
        TryOnFingerSelector(
          value: _selectedFingerIndex,
          onChanged: _selectFinger,
        ),
        const SizedBox(height: 16),
        _CollapsibleTryOnSection(
          title: 'Shape',
          expanded: _showShapeSection,
          onToggle: () => setState(() => _showShapeSection = !_showShapeSection),
          child: NailShapeSelector(
            shapes: data.nailShapes,
            selectedShape: _selectedNailShape,
            showTitle: false,
            onSelected: (shape) => setState(() => _selectedNailShape = shape),
          ),
        ),
        _CollapsibleTryOnSection(
          title: 'Color',
          expanded: _showColorSection,
          onToggle: () => setState(() => _showColorSection = !_showColorSection),
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
                  _fingerGradients[i] =
                      gradient == null ? null : [...gradient];
                }
              } else {
                _fingerGradients[_selectedFingerIndex] =
                    gradient == null ? null : [...gradient];
              }
            }),
          ),
        ),
        _CollapsibleTryOnSection(
          title: 'Placement',
          expanded: _showPlacementSection,
          onToggle: () => setState(() => _showPlacementSection = !_showPlacementSection),
          trailing: FilledButton.icon(
            onPressed: _selectedComponent == null ? null : _addSelectedComponent,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
          child: TryOnPlacementControls(
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
        ),
        _CollapsibleTryOnSection(
          title: 'Components',
          expanded: _showSystemComponents,
          onToggle: () => setState(() => _showSystemComponents = !_showSystemComponents),
          child: ComponentGrid(
            title: 'System components',
            components: data.combinedComponents.where((item) => !item.isCustomerComponent).toList(),
            selectedComponent: _selectedComponent,
            onSelected: (component) => setState(() => _selectedComponent = component),
          ),
        ),
        _CollapsibleTryOnSection(
          title: 'Customer components',
          expanded: _showCustomerComponents,
          onToggle: () => setState(() => _showCustomerComponents = !_showCustomerComponents),
          child: ComponentGrid(
            title: 'My components',
            components: data.combinedComponents.where((item) => item.isCustomerComponent).toList(),
            selectedComponent: _selectedComponent,
            onSelected: (component) => setState(() => _selectedComponent = component),
          ),
        ),
      ],
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
          ElevatedButton(
            onPressed: _fetchData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  int get _selectedPlacementIndex {
    return _placements.indexWhere((item) => item.localId == _selectedPlacementId);
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

class _CollapsibleTryOnSection extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final Widget? trailing;

  const _CollapsibleTryOnSection({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: 6),
              ],
              IconButton(
                tooltip: expanded ? 'Hide' : 'Show',
                onPressed: onToggle,
                icon: Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            child,
          ],
        ],
      ),
    );
  }
}
