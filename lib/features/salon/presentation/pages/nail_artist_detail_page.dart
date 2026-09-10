import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../generated/l10n.dart';
import '../../../nail_booking/data/datasources/capable_nails_api_service.dart';
import '../../../nails/data/models/nail_variant_model.dart';
import '../../data/models/booking_rating_model.dart';
import '../../data/models/nail_artist_model.dart';
import '../../data/nail_artist_repository.dart';
import '../widgets/basic_network_image.dart';
import '../widgets/artist_schedule_section.dart';
import '../widgets/rating_list.dart';
import '../widgets/salon_ui.dart';

class NailArtistDetailPage extends StatefulWidget {
  final String nailArtistId;

  const NailArtistDetailPage({super.key, required this.nailArtistId});

  @override
  State<NailArtistDetailPage> createState() => _NailArtistDetailPageState();
}

class _NailArtistDetailPageState extends State<NailArtistDetailPage> {
  late final NailArtistRepository _repository;
  late final CapableNailsApiService _capableNailsService;
  late Future<_NailArtistDetailData> _detailFuture;

  @override
  void initState() {
    super.initState();
    _repository = NailArtistRepository(getIt<ApiClient>());
    _capableNailsService = CapableNailsApiService();
    _detailFuture = _loadDetail();
  }

  Future<_NailArtistDetailData> _loadDetail() async {
    final results = await Future.wait([
      _repository.getNailArtistDetail(widget.nailArtistId),
      _repository.getNailArtistRatings(widget.nailArtistId),
      _repository.getNailArtistSchedules(widget.nailArtistId),
      _capableNailsService.getCapableNailsByArtist(widget.nailArtistId),
    ]);

    return _NailArtistDetailData(
      artist: results[0] as NailArtistModel,
      ratings: results[1] as List<BookingRatingModel>,
      schedules: results[2] as List<NailArtistSchedule>,
      capableNailVariants: results[3] as List<NailVariantModel>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(l10n.nailArtistDetailTitle),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<_NailArtistDetailData>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return SalonErrorState(
              message: l10n.artistLoadError(snapshot.error.toString()),
              retryLabel: l10n.retry,
              onRetry: () => setState(() => _detailFuture = _loadDetail()),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return SalonEmptyState(
              icon: Icons.person_search_rounded,
              title: l10n.artistNotFound,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _ArtistHero(artist: data.artist),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (data.artist.email.isNotEmpty)
                    SalonInfoChip(
                      icon: Icons.mail_rounded,
                      label: data.artist.email,
                    ),
                  if (data.artist.phone.isNotEmpty)
                    SalonInfoChip(
                      icon: Icons.call_rounded,
                      label: data.artist.phone,
                    ),
                  if (data.artist.status.isNotEmpty)
                    SalonInfoChip(
                      icon: Icons.verified_rounded,
                      label: data.artist.status,
                      color: AppColors.success,
                    ),
                ],
              ),
              SalonSectionHeader(
                title: l10n.ratingsTitle,
                icon: Icons.star_rounded,
              ),
              RatingList(ratings: data.ratings),
              ArtistScheduleSection(schedules: data.schedules),
              SalonSectionHeader(
                title: l10n.nailVariantsLabel,
                icon: Icons.auto_awesome_rounded,
              ),
              if (data.capableNailVariants.isEmpty)
                SalonEmptyState(
                  icon: Icons.back_hand_rounded,
                  title: l10n.noVariantsAvailable,
                )
              else
                ...data.capableNailVariants.map(
                  (variant) => _NailVariantTile(variant: variant),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ArtistHero extends StatelessWidget {
  final NailArtistModel artist;

  const _ArtistHero({required this.artist});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          BasicNetworkImage(
            imageUrl: artist.avatarUrl,
            height: 260,
            placeholderIcon: Icons.person_rounded,
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SalonInfoChip(
                  icon: Icons.brush_rounded,
                  label: S.of(context).nailArtistLabel,
                  color: AppColors.secondary,
                ),
                const SizedBox(height: 10),
                Text(
                  artist.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatPrice(double price) {
  final text = price % 1 == 0 ? price.toInt().toString() : price.toString();
  return '$text VND';
}

class _NailVariantTile extends StatelessWidget {
  final NailVariantModel variant;

  const _NailVariantTile({required this.variant});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final specs = <String>[
      if (variant.nailShape != null)
        '${l10n.nailShapeLabel}: ${variant.nailShape!.name}',
      if (variant.nailSurface != null)
        '${l10n.nailSurfaceLabel}: ${variant.nailSurface!.name}',
      if (variant.duration != null) l10n.minutesLabel('${variant.duration}'),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          BasicNetworkImage(
            imageUrl: variant.imageUrl,
            width: 92,
            height: 92,
            placeholderIcon: Icons.auto_awesome_rounded,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    variant.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (specs.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      specs.join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SalonInfoChip(
                    icon: Icons.payments_rounded,
                    label: _formatPrice(variant.price),
                    color: AppColors.primaryDark,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NailArtistDetailData {
  final NailArtistModel artist;
  final List<BookingRatingModel> ratings;
  final List<NailArtistSchedule> schedules;
  final List<NailVariantModel> capableNailVariants;

  const _NailArtistDetailData({
    required this.artist,
    required this.ratings,
    required this.schedules,
    required this.capableNailVariants,
  });
}
