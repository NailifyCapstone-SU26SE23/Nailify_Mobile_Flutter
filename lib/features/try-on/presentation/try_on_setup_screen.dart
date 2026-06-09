import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../nails/data/models/customer_nail_models.dart';
import '../../nails/data/models/nail_shape_model.dart';
import '../../nails/data/repositories/customer_nail_repository.dart';
import '../../nails/data/repositories/nail_component_repository.dart';
import '../../nails/services/ar_try_on_service.dart';
import '../models/try_on_data.dart';
import '../services/try_on_setup_service.dart';
import '../widgets/component_grid.dart';
import '../widgets/nail_shape_selector.dart';
import '../widgets/try_on_action_bar.dart';

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
  String? _error;
  TryOnData? _tryOnData;
  CustomerNailModel? _customerNail;

  NailShapeModel? _selectedNailShape;
  CombinedComponent? _selectedComponent;
  int _selectedFingerIndex = 1;
  int? _selectedPlacementId;
  final List<_PlacedComponentDraft> _placements = [];
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

      setState(() {
        _tryOnData = data;
        _customerNail = customerNail;
        _selectedNailShape = _resolveShape(data.nailShapes, customerNail);
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

  List<_PlacedComponentDraft> _buildDrafts(
    CustomerNailModel? nail,
    List<CombinedComponent> components,
  ) {
    if (nail == null) return const [];
    return nail.customerNailComponents.map((item) {
      final component = components.firstWhereOrNull(
        (component) =>
            component.componentId == item.componentId ||
            component.customerComponentId == item.customerComponentId,
      );
      final config = _decodeConfig(item.configJson);
      return _PlacedComponentDraft(
        localId: item.customerNailComponentId,
        customerNailComponentId: item.customerNailComponentId,
        component: component,
        componentId: item.componentId,
        customerComponentId: item.customerComponentId,
        name: component?.name ?? item.component?.name ?? item.customerComponent?.name ?? 'Component',
        imageUrl: component?.imageUrl ?? item.component?.imageUrl ?? item.customerComponent?.imageUrl ?? '',
        fingerIndex: item.fingerIndex,
        posX: item.posX,
        posY: item.posY,
        scale: _asDouble(config['scale'], fallback: 0.35),
        rotation: _asDouble(config['rotation']),
      );
    }).toList();
  }

  void _addSelectedComponent() {
    final component = _selectedComponent;
    if (component == null) return;
    final draft = _PlacedComponentDraft(
      localId: DateTime.now().microsecondsSinceEpoch,
      component: component,
      componentId: component.componentId,
      customerComponentId: component.customerComponentId,
      name: component.name,
      imageUrl: component.imageUrl,
      fingerIndex: _selectedFingerIndex,
      posX: 0.5,
      posY: 0.5,
      scale: 0.35,
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
        posX: (current.posX + dx).clamp(0.0, 1.0).toDouble(),
        posY: (current.posY + dy).clamp(0.0, 1.0).toDouble(),
        scale: (current.scale + scale).clamp(0.1, 1.5).toDouble(),
        rotation: current.rotation + rotation,
      );
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
        customColor: _buildSolidColorJson('#FF4081'),
        isFavorite: nail.isFavorite,
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
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  CustomerNailModel? _buildPreviewNail() {
    final nail = _customerNail;
    final shape = _selectedNailShape;
    if (nail == null || shape == null) return null;
    return CustomerNailModel(
      customerNailId: nail.customerNailId,
      name: nail.name,
      imageUrl: nail.imageUrl,
      nailShapeId: shape.nailShapeId,
      nailSurfaceId: nail.nailSurfaceId,
      price: nail.price,
      customColor: nail.customColor ?? _buildSolidColorJson('#FF4081'),
      duration: nail.duration,
      isFavorite: nail.isFavorite,
      isPublic: nail.isPublic,
      nailShape: shape,
      nailSurface: nail.nailSurface,
      customerNailComponents: _placements
          .map((placement) => placement.toCustomerNailComponent(nail.customerNailId))
          .toList(),
    );
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
        _PreviewBoard(
          nail: _customerNail,
          selectedShape: _selectedNailShape,
          placements: _placements,
          selectedPlacementId: _selectedPlacementId,
          onSelectPlacement: (id) => setState(() => _selectedPlacementId = id),
        ),
        const SizedBox(height: 16),
        _PlacementControls(
          selectedPlacement: _selectedPlacement,
          selectedFingerIndex: _selectedFingerIndex,
          onFingerChanged: (value) => setState(() {
            _selectedFingerIndex = value;
            final index = _selectedPlacementIndex;
            if (index != -1) {
              _placements[index] = _placements[index].copyWith(fingerIndex: value);
            }
          }),
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
        const SizedBox(height: 24),
        NailShapeSelector(
          shapes: data.nailShapes,
          selectedShape: _selectedNailShape,
          onSelected: (shape) => setState(() => _selectedNailShape = shape),
        ),
        const SizedBox(height: 24),
        _FingerSelector(
          value: _selectedFingerIndex,
          onChanged: (value) => setState(() => _selectedFingerIndex = value),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text('Components', style: Theme.of(context).textTheme.titleLarge),
            ),
            FilledButton.icon(
              onPressed: _selectedComponent == null ? null : _addSelectedComponent,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        ComponentGrid(
          title: 'System components',
          components: data.combinedComponents.where((item) => !item.isCustomerComponent).toList(),
          selectedComponent: _selectedComponent,
          onSelected: (component) => setState(() => _selectedComponent = component),
        ),
        ComponentGrid(
          title: 'My components',
          components: data.combinedComponents.where((item) => item.isCustomerComponent).toList(),
          selectedComponent: _selectedComponent,
          onSelected: (component) => setState(() => _selectedComponent = component),
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

  _PlacedComponentDraft? get _selectedPlacement {
    final index = _selectedPlacementIndex;
    return index == -1 ? null : _placements[index];
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PreviewBoard extends StatelessWidget {
  final CustomerNailModel? nail;
  final NailShapeModel? selectedShape;
  final List<_PlacedComponentDraft> placements;
  final int? selectedPlacementId;
  final ValueChanged<int> onSelectPlacement;

  const _PreviewBoard({
    required this.nail,
    required this.selectedShape,
    required this.placements,
    required this.selectedPlacementId,
    required this.onSelectPlacement,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7FB),
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned.fill(
                  child: nail?.imageUrl.isNotEmpty == true
                      ? Image.network(
                          nail!.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _PreviewFallback(),
                        )
                      : const _PreviewFallback(),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      selectedShape?.name ?? 'Select nail shape',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                ...placements.map((placement) {
                  final size = 54.0 * placement.scale.clamp(0.35, 1.5).toDouble();
                  return Positioned(
                    left: placement.posX * (constraints.maxWidth - size),
                    top: placement.posY * (constraints.maxHeight - size),
                    child: GestureDetector(
                      onTap: () => onSelectPlacement(placement.localId),
                      child: Transform.rotate(
                        angle: placement.rotation * 3.14159265359 / 180,
                        child: Container(
                          width: size,
                          height: size,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.88),
                            border: Border.all(
                              color: selectedPlacementId == placement.localId
                                  ? Colors.purple
                                  : Colors.black26,
                              width: selectedPlacementId == placement.localId ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: placement.imageUrl.isEmpty
                              ? const Icon(Icons.auto_awesome, color: Colors.purple)
                              : Image.network(
                                  placement.imageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.auto_awesome, color: Colors.purple),
                                ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: const Color(0xFFF8EAF2),
      child: const Icon(Icons.spa_outlined, size: 52, color: Colors.black38),
    );
  }
}

class _PlacementControls extends StatelessWidget {
  final _PlacedComponentDraft? selectedPlacement;
  final int selectedFingerIndex;
  final ValueChanged<int> onFingerChanged;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onScaleDown;
  final VoidCallback onScaleUp;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onRemove;

  const _PlacementControls({
    required this.selectedPlacement,
    required this.selectedFingerIndex,
    required this.onFingerChanged,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onScaleDown,
    required this.onScaleUp,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = selectedPlacement != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                selectedPlacement?.name ?? 'Select a placed component',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              onPressed: enabled ? onRemove : null,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        _FingerSelector(value: selectedPlacement?.fingerIndex ?? selectedFingerIndex, onChanged: onFingerChanged),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            IconButton.filledTonal(onPressed: enabled ? onMoveLeft : null, icon: const Icon(Icons.chevron_left)),
            IconButton.filledTonal(onPressed: enabled ? onMoveUp : null, icon: const Icon(Icons.keyboard_arrow_up)),
            IconButton.filledTonal(onPressed: enabled ? onMoveDown : null, icon: const Icon(Icons.keyboard_arrow_down)),
            IconButton.filledTonal(onPressed: enabled ? onMoveRight : null, icon: const Icon(Icons.chevron_right)),
            IconButton.filledTonal(onPressed: enabled ? onScaleDown : null, icon: const Icon(Icons.remove)),
            IconButton.filledTonal(onPressed: enabled ? onScaleUp : null, icon: const Icon(Icons.add)),
            IconButton.filledTonal(onPressed: enabled ? onRotateLeft : null, icon: const Icon(Icons.rotate_left)),
            IconButton.filledTonal(onPressed: enabled ? onRotateRight : null, icon: const Icon(Icons.rotate_right)),
          ],
        ),
      ],
    );
  }
}

class _FingerSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _FingerSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const fingers = [
      MapEntry(-1, 'All'),
      MapEntry(1, 'Thumb'),
      MapEntry(2, 'Index'),
      MapEntry(3, 'Middle'),
      MapEntry(4, 'Ring'),
      MapEntry(5, 'Pinky'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final finger in fingers)
          ChoiceChip(
            label: Text(finger.value),
            selected: value == finger.key,
            onSelected: (_) => onChanged(finger.key),
          ),
      ],
    );
  }
}

class _PlacedComponentDraft {
  final int localId;
  final int? customerNailComponentId;
  final CombinedComponent? component;
  final int? componentId;
  final int? customerComponentId;
  final String name;
  final String imageUrl;
  final int fingerIndex;
  final double posX;
  final double posY;
  final double scale;
  final double rotation;

  const _PlacedComponentDraft({
    required this.localId,
    this.customerNailComponentId,
    this.component,
    this.componentId,
    this.customerComponentId,
    required this.name,
    required this.imageUrl,
    required this.fingerIndex,
    required this.posX,
    required this.posY,
    required this.scale,
    required this.rotation,
  });

  _PlacedComponentDraft copyWith({
    int? fingerIndex,
    double? posX,
    double? posY,
    double? scale,
    double? rotation,
  }) {
    return _PlacedComponentDraft(
      localId: localId,
      customerNailComponentId: customerNailComponentId,
      component: component,
      componentId: componentId,
      customerComponentId: customerComponentId,
      name: name,
      imageUrl: imageUrl,
      fingerIndex: fingerIndex ?? this.fingerIndex,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  _CustomerNailComponentPayload toPayload(int customerNailId) {
    return _CustomerNailComponentPayload(
      customerNailId: customerNailId,
      componentId: componentId,
      customerComponentId: customerComponentId,
      posX: posX,
      posY: posY,
      fingerIndex: fingerIndex,
      configJson: jsonEncode({
        'scale': scale,
        'rotation': rotation,
      }),
    );
  }

  CustomerNailComponentModel toCustomerNailComponent(int customerNailId) {
    return CustomerNailComponentModel(
      customerNailComponentId: customerNailComponentId ?? localId,
      customerNailId: customerNailId,
      componentId: componentId,
      customerComponentId: customerComponentId,
      posX: posX,
      posY: posY,
      fingerIndex: fingerIndex,
      configJson: jsonEncode({
        'scale': scale,
        'rotation': rotation,
        'imageSrc': imageUrl,
        'type': component?.type.stringValue,
      }),
    );
  }
}

class _CustomerNailComponentPayload {
  final int customerNailId;
  final int? componentId;
  final int? customerComponentId;
  final double posX;
  final double posY;
  final int fingerIndex;
  final String configJson;

  const _CustomerNailComponentPayload({
    required this.customerNailId,
    required this.componentId,
    required this.customerComponentId,
    required this.posX,
    required this.posY,
    required this.fingerIndex,
    required this.configJson,
  });
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }

  T? get firstOrNull => isEmpty ? null : first;
}

Map<String, dynamic> _decodeConfig(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return const {};
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

String _buildSolidColorJson(String color) {
  return jsonEncode({
    'mode': 'solid',
    'color': color,
    'gradient': null,
  });
}
