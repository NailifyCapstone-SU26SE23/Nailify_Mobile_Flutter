import 'package:flutter/material.dart';
import '../models/try_on_data.dart'; // Adjust path based on your real structure

class ComponentGrid extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (components.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.82,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: components.length,
          itemBuilder: (context, index) {
            final component = components[index];
            final isSelected = selectedComponent?.id == component.id &&
                selectedComponent?.isCustomerComponent == component.isCustomerComponent;

            return _ComponentCard(
              component: component,
              isSelected: isSelected,
              onTap: () => onSelected(component),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.purple : Colors.grey.shade200,
            width: isSelected ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.purple.withAlpha(20), blurRadius: 8, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: component.imageUrl.isNotEmpty
                        ? Image.network(
                      component.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => const _FallbackGridIcon(),
                    )
                        : const _FallbackGridIcon(),
                  ),
                ),

                // Metadata
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        component.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _TypeBadge(type: component.type),
                          const Spacer(),
                          if (component.price != null)
                            Text(
                              '\$${component.price!.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
                  radius: 12,
                  backgroundColor: Colors.purple,
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.name.toUpperCase(),
        style: TextStyle(fontSize: 9, color: badgeColor, fontWeight: FontWeight.w800),
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
      child: Icon(Icons.auto_awesome, size: 36, color: Colors.grey.shade300),
    );
  }
}
