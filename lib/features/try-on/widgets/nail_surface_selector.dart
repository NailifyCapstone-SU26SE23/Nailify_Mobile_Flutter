import 'package:flutter/material.dart';

import '../../nails/data/models/nail_surface_model.dart';

class NailSurfaceSelector extends StatelessWidget {
  final List<NailSurfaceModel> surfaces;
  final NailSurfaceModel? selectedSurface;
  final ValueChanged<NailSurfaceModel> onSelected;

  const NailSurfaceSelector({
    super.key,
    required this.surfaces,
    required this.selectedSurface,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (surfaces.isEmpty) {
      return const Text('No nail surfaces available');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final surface in surfaces)
          ChoiceChip(
            label: Text(surface.name),
            selected: selectedSurface?.nailSurfaceId == surface.nailSurfaceId,
            onSelected: (_) => onSelected(surface),
          ),
      ],
    );
  }
}
