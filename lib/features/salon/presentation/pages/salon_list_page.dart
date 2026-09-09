import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/salon_model.dart';
import '../../data/salon_repository.dart';
import '../widgets/basic_network_image.dart';

class SalonListPage extends StatefulWidget {
  const SalonListPage({super.key});

  @override
  State<SalonListPage> createState() => _SalonListPageState();
}

class _SalonListPageState extends State<SalonListPage> {
  late final SalonRepository _repository;
  late Future<List<SalonModel>> _salonsFuture;

  @override
  void initState() {
    super.initState();
    _repository = SalonRepository(getIt<ApiClient>());
    _salonsFuture = _repository.getSalons();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Our Salons')),
      body: FutureBuilder<List<SalonModel>>(
        future: _salonsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load salons: ${snapshot.error}'));
          }

          final salons = snapshot.data ?? const [];
          if (salons.isEmpty) {
            return const Center(child: Text('No salons found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: salons.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final salon = salons[index];
              return InkWell(
                onTap: () => context.push('/salons/${salon.salonId}'),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BasicNetworkImage(
                            imageUrl: salon.imageUrl,
                            width: 92,
                            height: 76,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                salon.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(salon.address),
                              if (salon.status.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text('Status: ${salon.status}'),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
