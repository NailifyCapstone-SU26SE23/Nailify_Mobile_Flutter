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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < surfaces.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == surfaces.length - 1 ? 0 : 16.0,
              ),
              child: SizedBox(
                height: 64,
                child: FilledButton.tonal(
                  onPressed: () => onSelected(surfaces[i]),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        selectedSurface?.nailSurfaceId ==
                            surfaces[i].nailSurfaceId
                        ? Colors.pink
                        : Colors.pink.shade50,
                    foregroundColor:
                        selectedSurface?.nailSurfaceId ==
                            surfaces[i].nailSurfaceId
                        ? Colors.white
                        : Colors.pink.shade900,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    surfaces[i].name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
