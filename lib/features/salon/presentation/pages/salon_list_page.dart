import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../generated/l10n.dart';
import '../../data/models/salon_model.dart';
import '../../data/salon_repository.dart';
import '../widgets/basic_network_image.dart';
import '../widgets/salon_ui.dart';

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

  Future<void> _refresh() async {
    setState(() => _salonsFuture = _repository.getSalons());
    await _salonsFuture;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.primaryDark,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.salonsTitle,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<SalonModel>>(
        future: _salonsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError) {
            return SalonErrorState(
              message: l10n.salonsLoadError(snapshot.error.toString()),
              retryLabel: l10n.retry,
              onRetry: _refresh,
            );
          }

          final salons = snapshot.data ?? const [];
          if (salons.isEmpty) {
            return SalonEmptyState(
              icon: Icons.storefront_rounded,
              title: l10n.noSalonsFound,
              message: l10n.noSalonsFoundDesc,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: salons.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _SalonListIntro(count: salons.length);
                }
                final salon = salons[index - 1];
                return _SalonCard(
                  salon: salon,
                  onTap: () => context.push('/salons/${salon.salonId}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SalonListIntro extends StatelessWidget {
  final int count;

  const _SalonListIntro({required this.count});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF0F5), Color(0xFFFFFBEE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.salonsHeroTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Georgia',
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.salonsHeroSubtitle,
                    style: TextStyle(
                      height: 1.4,
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          l10n.salonsAvailableCount(count),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary,
                    blurRadius: 10,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.spa_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalonCard extends StatelessWidget {
  final SalonModel salon;
  final VoidCallback onTap;

  const _SalonCard({required this.salon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final isOpen = salon.status.toLowerCase() != 'closed' &&
        salon.status.toLowerCase() != 'inactive';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EAE1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Header with overlay & status badge
              Stack(
                children: [
                  BasicNetworkImage(
                    imageUrl: salon.imageUrl,
                    height: 160,
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
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Floating Open/Closed Status Chip
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isOpen
                            ? Colors.green.shade500.withValues(alpha: 0.9)
                            : Colors.grey.shade700.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isOpen ? 'Đang mở cửa' : 'Tạm đóng cửa',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Salon Title on Image
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: Text(
                      salon.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                      ),
                    ),
                  ),
                ],
              ),
              // Body Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            salon.address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (salon.phone.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.call_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  salon.phone,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        Row(
                          children: [
                            Text(
                              l10n.viewDetail,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
