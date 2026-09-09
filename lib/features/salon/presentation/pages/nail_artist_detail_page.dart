import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/booking_rating_model.dart';
import '../../data/models/nail_artist_model.dart';
import '../../data/nail_artist_repository.dart';
import '../widgets/basic_network_image.dart';
import '../widgets/rating_list.dart';
import '../widgets/section_title.dart';

class NailArtistDetailPage extends StatefulWidget {
  final String nailArtistId;

  const NailArtistDetailPage({super.key, required this.nailArtistId});

  @override
  State<NailArtistDetailPage> createState() => _NailArtistDetailPageState();
}

class _NailArtistDetailPageState extends State<NailArtistDetailPage> {
  late final NailArtistRepository _repository;
  late Future<_NailArtistDetailData> _detailFuture;

  @override
  void initState() {
    super.initState();
    _repository = NailArtistRepository(getIt<ApiClient>());
    _detailFuture = _loadDetail();
  }

  Future<_NailArtistDetailData> _loadDetail() async {
    final results = await Future.wait([
      _repository.getNailArtistDetail(widget.nailArtistId),
      _repository.getNailArtistRatings(widget.nailArtistId),
    ]);

    return _NailArtistDetailData(
      artist: results[0] as NailArtistModel,
      ratings: results[1] as List<BookingRatingModel>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nail Artist Detail')),
      body: FutureBuilder<_NailArtistDetailData>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load artist: ${snapshot.error}'));
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('Artist not found.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BasicNetworkImage(
                  imageUrl: data.artist.avatarUrl,
                  height: 190,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                data.artist.fullName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Status: ${data.artist.status}'),
              if (data.artist.email.isNotEmpty) Text('Email: ${data.artist.email}'),
              if (data.artist.phone.isNotEmpty) Text('Phone: ${data.artist.phone}'),
              const SectionTitle('Ratings'),
              RatingList(ratings: data.ratings),
              const SectionTitle('Schedules'),
              if (data.artist.schedules.isEmpty)
                const Text('No schedules.')
              else
                ...data.artist.schedules.map(
                  (schedule) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(schedule.workDate),
                    subtitle: Text(
                      '${schedule.shiftStart} - ${schedule.shiftEnd} (${schedule.status})',
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

class _NailArtistDetailData {
  final NailArtistModel artist;
  final List<BookingRatingModel> ratings;

  const _NailArtistDetailData({
    required this.artist,
    required this.ratings,
  });
}
