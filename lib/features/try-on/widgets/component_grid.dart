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
  @override
  Widget build(BuildContext context) {
    if (widget.components.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title.isNotEmpty) ...[
          Text(
            widget.title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: 120, // More compact (120px instead of 160px)
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: widget.components.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final component = widget.components[index];
              return SizedBox(
                width: 90,
                child: _ComponentCard(
                  component: component,
                  isSelected: widget.selectedComponent?.id == component.id &&
                      widget.selectedComponent?.isCustomerComponent ==
                          component.isCustomerComponent,
                  onTap: () => widget.onSelected(component),
                ),
              );
            },
          ),
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 90,
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? const Color(0xFFE91E63) : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFFE91E63).withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    child: Container(
                      color: Colors.grey.shade50,
                      child: component.imageUrl.isNotEmpty
                          ? Image.network(
                              component.imageUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              errorBuilder: (_, _, _) => const _FallbackGridIcon(),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 1.5),
                                  ),
                                );
                              },
                            )
                          : const _FallbackGridIcon(),
                    ),
                  ),
                ),

                // Metadata
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        component.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 10,
                          color: isSelected ? const Color(0xFFE91E63) : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(child: _TypeBadge(type: component.type)),
                          const SizedBox(width: 4),
                          if (component.price != null)
                            Text(
                              '\$${component.price!.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFFC2185B) : Colors.grey.shade700,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFE91E63),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 8,
                ),
              ),
            ),
        ],
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
      case ComponentType.gem:
        badgeColor = Colors.blue;
        break;
      case ComponentType.sticker:
        badgeColor = Colors.green;
        break;
      case ComponentType.charm:
        badgeColor = Colors.orange;
        break;
      case ComponentType.art:
        badgeColor = const Color(0xFFE91E63);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.name.toUpperCase(),
        style: TextStyle(fontSize: 7, color: badgeColor, fontWeight: FontWeight.w800),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
      child: Icon(Icons.auto_awesome_outlined, size: 20, color: Colors.grey.shade300),
    );
  }
}
