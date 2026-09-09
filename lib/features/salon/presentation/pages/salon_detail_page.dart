import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../generated/l10n.dart';
import '../../data/models/booking_rating_model.dart';
import '../../data/models/nail_artist_model.dart';
import '../../data/models/salon_model.dart';
import '../../data/salon_repository.dart';
import '../widgets/basic_network_image.dart';
import '../widgets/rating_list.dart';
import '../widgets/salon_ui.dart';

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
    final l10n = S.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(l10n.salonDetailTitle),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<_SalonDetailData>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return SalonErrorState(
              message: l10n.salonLoadError(snapshot.error.toString()),
              retryLabel: l10n.retry,
              onRetry: () => setState(() => _detailFuture = _loadDetail()),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return SalonEmptyState(
              icon: Icons.storefront_rounded,
              title: l10n.salonNotFound,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _SalonHero(salon: data.salon),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (data.salon.phone.isNotEmpty)
                    SalonInfoChip(
                      icon: Icons.call_rounded,
                      label: data.salon.phone,
                    ),
                  SalonInfoChip(
                    icon: Icons.verified_rounded,
                    label: data.salon.status.isNotEmpty
                        ? data.salon.status
                        : l10n.salonVerified,
                    color: AppColors.success,
                  ),
                ],
              ),
              SalonSectionHeader(
                title: l10n.salonRatingsTitle,
                icon: Icons.star_rounded,
              ),
              RatingList(ratings: data.ratings),
              SalonSectionHeader(
                title: l10n.salonOffDatesTitle,
                icon: Icons.event_busy_rounded,
              ),
              if (data.offDates.isEmpty)
                SalonEmptyState(
                  icon: Icons.event_available_rounded,
                  title: l10n.noOffDates,
                )
              else
                ...data.offDates.map(
                  (offDate) => _InfoTile(
                    icon: Icons.event_busy_rounded,
                    title: '${offDate.startDate} - ${offDate.endDate}',
                    subtitle: offDate.description,
                  ),
                ),
              SalonSectionHeader(
                title: l10n.nailArtistsTitle,
                icon: Icons.groups_rounded,
              ),
              if (data.artists.isEmpty)
                SalonEmptyState(
                  icon: Icons.person_search_rounded,
                  title: l10n.noArtistsFound,
                )
              else
                ...data.artists.map(
                  (artist) => _ArtistTile(
                    artist: artist,
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

class _SalonHero extends StatelessWidget {
  final SalonModel salon;

  const _SalonHero({required this.salon});

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
            imageUrl: salon.imageUrl,
            height: 230,
            placeholderIcon: Icons.storefront_rounded,
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
                Text(
                  salon.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        salon.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistTile extends StatelessWidget {
  final NailArtistModel artist;
  final VoidCallback onTap;

  const _ArtistTile({required this.artist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
          backgroundImage:
              artist.avatarUrl.isEmpty ? null : NetworkImage(artist.avatarUrl),
          child: artist.avatarUrl.isEmpty
              ? const Icon(Icons.person_outline, color: AppColors.primary)
              : null,
        ),
        title: Text(
          artist.fullName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: artist.phone.isNotEmpty ? Text(artist.phone) : null,
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
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
