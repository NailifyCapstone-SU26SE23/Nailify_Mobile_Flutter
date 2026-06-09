import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../data/models/nail_component_model.dart';
import '../../data/models/nail_variant_model.dart';
import '../../data/repositories/nail_variant_repository.dart';
import '../../services/ar_try_on_service.dart';

class NailVariantDetailScreen extends StatefulWidget {
  final int nailVariantId;

  const NailVariantDetailScreen({super.key, required this.nailVariantId});

  @override
  State<NailVariantDetailScreen> createState() =>
      _NailVariantDetailScreenState();
}

class _NailVariantDetailScreenState extends State<NailVariantDetailScreen> {
  late Future<NailVariantModel> _future;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    _future = _loadVariant();
  }

  Future<NailVariantModel> _loadVariant() {
    return getIt<NailVariantRepository>().getNailVariantById(widget.nailVariantId);
  }

  Future<void> _openTryOn(
    Future<void> Function(NailVariantModel) launcher,
  ) async {
    setState(() => _launching = true);
    try {
      final arService = getIt<ArTryOnService>();
      final available = await arService.isAvailable();
      if (!available) {
        throw UnsupportedError('Virtual try-on is not available on this build.');
      }
      final freshVariant = await _loadVariant();
      await launcher(freshVariant);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NailVariantModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _VariantLoadingView();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _VariantErrorView(
            message: snapshot.error?.toString() ?? 'Could not load variant.',
            onRetry: () => setState(() => _future = _loadVariant()),
          );
        }
        return _VariantDetailContent(
          variant: snapshot.data!,
          launching: _launching,
          onLiveTryOn: () => _openTryOn(
            getIt<ArTryOnService>().launchLive,
          ),
          onPhotoTryOn: () => _openTryOn(
            getIt<ArTryOnService>().launchPhoto,
          ),
        );
      },
    );
  }
}

class _VariantDetailContent extends StatelessWidget {
  final NailVariantModel variant;
  final bool launching;
  final VoidCallback onLiveTryOn;
  final VoidCallback onPhotoTryOn;

  const _VariantDetailContent({
    required this.variant,
    required this.launching,
    required this.onLiveTryOn,
    required this.onPhotoTryOn,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<NailComponentModel>>{};
    for (final component in variant.nailComponents) {
      grouped.putIfAbsent(component.fingerIndex, () => []).add(component);
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/nails/${variant.nailDesignId}');
                  }
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 1.1,
                child: variant.imageUrl.isEmpty
                    ? Container(
                        color: const Color(0xFFF7E8F1),
                        alignment: Alignment.center,
                        child: const Icon(Icons.spa_outlined, size: 48),
                      )
                    : Image.network(
                        variant.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF7E8F1),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              variant.name,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${variant.price.toStringAsFixed(0)} VND',
              style: const TextStyle(
                color: Color(0xFFFF66C4),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DetailChip(label: variant.nailShape?.name ?? 'Shape'),
                _DetailChip(label: variant.nailSurface?.name ?? 'Surface'),
                if (variant.duration != null)
                  _DetailChip(label: '${variant.duration} min'),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: launching ? null : onLiveTryOn,
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Live try on'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: launching ? null : onPhotoTryOn,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Photo try on'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Components',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (var finger = 0; finger < 5; finger++)
              _FingerComponents(
                fingerIndex: finger,
                components: grouped[finger] ?? const [],
              ),
            if (grouped[-1]?.isNotEmpty == true)
              _FingerComponents(
                fingerIndex: -1,
                components: grouped[-1]!,
                title: 'Shared',
              ),
          ],
        ),
        if (launching) const _TryOnLoadingOverlay(),
      ],
    );
  }
}

class _VariantLoadingView extends StatelessWidget {
  const _VariantLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('Loading nail variant...'),
        ],
      ),
    );
  }
}

class _VariantErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _VariantErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TryOnLoadingOverlay extends StatelessWidget {
  const _TryOnLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.white.withOpacity(0.78),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Preparing try on...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _FingerComponents extends StatelessWidget {
  final int fingerIndex;
  final List<NailComponentModel> components;
  final String? title;

  const _FingerComponents({
    required this.fingerIndex,
    required this.components,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (components.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              title ?? _fingerName(fingerIndex),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: components
                  .map((component) => _ComponentChip(component: component))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _fingerName(int index) {
    const names = ['Thumb', 'Index', 'Middle', 'Ring', 'Pinky'];
    return index >= 0 && index < names.length ? names[index] : 'Finger $index';
  }
}

class _ComponentChip extends StatelessWidget {
  final NailComponentModel component;

  const _ComponentChip({required this.component});

  @override
  Widget build(BuildContext context) {
    final config = component.config;
    final subtitle =
        'x ${component.posX.toStringAsFixed(2)}, y ${component.posY.toStringAsFixed(2)}, scale ${config.scale.toStringAsFixed(2)}';
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7FB),
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: component.component?.imageUrl.isNotEmpty == true
                ? Image.network(component.component!.imageUrl, fit: BoxFit.contain)
                : const Icon(Icons.auto_awesome, color: Color(0xFFFF66C4)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  component.component?.name ??
                      'Component ${component.componentId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;

  const _DetailChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
