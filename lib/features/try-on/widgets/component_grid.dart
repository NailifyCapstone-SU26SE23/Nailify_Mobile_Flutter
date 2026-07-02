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
        Text(
          widget.title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.components.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 150,
            mainAxisExtent: 190,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final component = widget.components[index];
            return _ComponentCard(
              component: component,
              isSelected:
                  widget.selectedComponent?.id == component.id &&
                  widget.selectedComponent?.isCustomerComponent ==
                      component.isCustomerComponent,
              onTap: () => widget.onSelected(component),
            );
          },
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
                ? [
                    BoxShadow(
                      color: Colors.purple.withAlpha(18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
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
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                      child: component.imageUrl.isNotEmpty
                          ? Image.network(
                              component.imageUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              errorBuilder: (_, _, _) =>
                                  const _FallbackGridIcon(),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
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
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
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
                    child: const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    ),
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
        badgeColor = Colors.purple;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.name.toUpperCase(),
        style: TextStyle(
          fontSize: 8,
          color: badgeColor,
          fontWeight: FontWeight.w800,
        ),
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
