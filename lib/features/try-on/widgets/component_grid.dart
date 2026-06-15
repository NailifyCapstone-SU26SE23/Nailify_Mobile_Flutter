import 'package:flutter/material.dart';

import '../models/try_on_data.dart';

class ComponentGrid extends StatefulWidget {
  final String title;
  final List<CombinedComponent> components;
  final CombinedComponent? selectedComponent;
  final ValueChanged<CombinedComponent> onSelected;

  const ComponentGrid({
    super.key,
    required this.title,
    required this.components,
    required this.selectedComponent,
    required this.onSelected,
  });

  @override
  State<ComponentGrid> createState() => _ComponentGridState();
}

class _ComponentGridState extends State<ComponentGrid> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.components.isEmpty) return const SizedBox.shrink();

    final totalPages = (widget.components.length / 3).ceil();
    final page = _page.clamp(0, totalPages - 1);
    if (page != _page) _page = page;
    final visible = widget.components.skip(page * 3).take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
              ),
            ),
            if (totalPages > 1) ...[
              IconButton(
                tooltip: 'Previous',
                onPressed: page == 0
                    ? null
                    : () => setState(() => _page = page - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${page + 1}/$totalPages'),
              IconButton(
                tooltip: 'Next',
                onPressed: page >= totalPages - 1
                    ? null
                    : () => setState(() => _page = page + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 0; index < 3; index++) ...[
              Expanded(
                child: index < visible.length
                    ? _ComponentCard(
                        component: visible[index],
                        isSelected: widget.selectedComponent?.id == visible[index].id &&
                            widget.selectedComponent?.isCustomerComponent == visible[index].isCustomerComponent,
                        onTap: () => widget.onSelected(visible[index]),
                      )
                    : const SizedBox.shrink(),
              ),
              if (index < 2) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _ComponentCard extends StatelessWidget {
  final CombinedComponent component;
  final bool isSelected;
  final VoidCallback onTap;

  const _ComponentCard({
    required this.component,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 0.72,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Colors.purple : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.purple.withAlpha(18), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                      child: component.imageUrl.isNotEmpty
                          ? Image.network(
                              component.imageUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              errorBuilder: (_, _, _) => const _FallbackGridIcon(),
                            )
                          : const _FallbackGridIcon(),
                    ),
                  ),

                  // Metadata
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          component.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _TypeBadge(type: component.type),
                            const Spacer(),
                            if (component.price != null)
                              Text(
                                '\$${component.price!.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Selected Checkmark Badge overlay
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.purple,
                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final ComponentType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    switch (type) {
      case ComponentType.gem: badgeColor = Colors.blue; break;
      case ComponentType.sticker: badgeColor = Colors.green; break;
      case ComponentType.charm: badgeColor = Colors.orange; break;
      case ComponentType.art: badgeColor = Colors.purple; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.name.toUpperCase(),
        style: TextStyle(fontSize: 8, color: badgeColor, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _FallbackGridIcon extends StatelessWidget {
  const _FallbackGridIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      width: double.infinity,
      child: Icon(Icons.auto_awesome, size: 24, color: Colors.grey.shade300),
    );
  }
}
