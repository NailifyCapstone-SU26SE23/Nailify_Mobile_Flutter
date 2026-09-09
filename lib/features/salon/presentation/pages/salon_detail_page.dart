import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/booking_rating_model.dart';
import '../../data/models/nail_artist_model.dart';
import '../../data/models/salon_model.dart';
import '../../data/salon_repository.dart';
import '../widgets/basic_network_image.dart';
import '../widgets/rating_list.dart';
import '../widgets/section_title.dart';

class SalonDetailPage extends StatefulWidget {
  final String salonId;

  const SalonDetailPage({super.key, required this.salonId});

  @override
  State<SalonDetailPage> createState() => _SalonDetailPageState();
}

class _SalonDetailPageState extends State<SalonDetailPage> {
  late final SalonRepository _repository;
  late Future<_SalonDetailData> _detailFuture;

  @override
  void initState() {
    super.initState();
    _repository = SalonRepository(getIt<ApiClient>());
    _detailFuture = _loadDetail();
  }

  Future<_SalonDetailData> _loadDetail() async {
    final results = await Future.wait([
      _repository.getSalonDetail(widget.salonId),
      _repository.getSalonRatings(widget.salonId),
      _repository.getSalonOffDates(widget.salonId),
      _repository.getSalonArtists(widget.salonId),
    ]);

    return _SalonDetailData(
      salon: results[0] as SalonModel,
      ratings: results[1] as List<BookingRatingModel>,
      offDates: results[2] as List<SalonOffDate>,
      artists: results[3] as List<NailArtistModel>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Salon Detail')),
      body: FutureBuilder<_SalonDetailData>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load salon: ${snapshot.error}'));
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('Salon not found.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BasicNetworkImage(
                  imageUrl: data.salon.imageUrl,
                  height: 190,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                data.salon.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(data.salon.address),
              if (data.salon.phone.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Phone: ${data.salon.phone}'),
              ],
              const SectionTitle('Salon ratings'),
              RatingList(ratings: data.ratings),
              const SectionTitle('Off dates'),
              if (data.offDates.isEmpty)
                const Text('No off dates.')
              else
                ...data.offDates.map(
                  (offDate) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${offDate.startDate} - ${offDate.endDate}'),
                    subtitle: Text(offDate.description),
                  ),
                ),
              const SectionTitle('Nail artists'),
              if (data.artists.isEmpty)
                const Text('No artists found.')
              else
                ...data.artists.map(
                  (artist) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: artist.avatarUrl.isEmpty
                          ? null
                          : NetworkImage(artist.avatarUrl),
                      child: artist.avatarUrl.isEmpty
                          ? const Icon(Icons.person_outline)
                          : null,
                    ),
                    title: Text(artist.fullName),
                    subtitle: Text(artist.status),
                    onTap: () => context.push(
                      '/salons/${widget.salonId}/artists/${artist.nailArtistId}',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SalonDetailData {
  final SalonModel salon;
  final List<BookingRatingModel> ratings;
  final List<SalonOffDate> offDates;
  final List<NailArtistModel> artists;

  const _SalonDetailData({
    required this.salon,
    required this.ratings,
    required this.offDates,
    required this.artists,
  });
}
