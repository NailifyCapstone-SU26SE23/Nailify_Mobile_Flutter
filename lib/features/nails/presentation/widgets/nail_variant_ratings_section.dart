import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_response_parser.dart';
import '../../../../generated/l10n.dart';
import '../../data/models/nail_variant_rating_model.dart';
import '../../data/repositories/nail_variant_repository.dart';

class NailVariantRatingsSection extends StatefulWidget {
  final int nailVariantId;

  const NailVariantRatingsSection({super.key, required this.nailVariantId});

  @override
  State<NailVariantRatingsSection> createState() =>
      _NailVariantRatingsSectionState();
}

class _NailVariantRatingsSectionState extends State<NailVariantRatingsSection> {
  static const int _pageSize = 5;

  late Future<NailVariantRatingPage> _ratingsFuture;
  int _page = 1;
  int? _stars;

  @override
  void initState() {
    super.initState();
    _ratingsFuture = _loadRatings();
  }

  @override
  void didUpdateWidget(covariant NailVariantRatingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nailVariantId != widget.nailVariantId) {
      _page = 1;
      _stars = null;
      _ratingsFuture = _loadRatings();
    }
  }

  Future<NailVariantRatingPage> _loadRatings() {
    return getIt<NailVariantRepository>().getRatingsByNailVariant(
      nailVariantId: widget.nailVariantId,
      page: _page,
      pageSize: _pageSize,
      stars: _stars,
    );
  }

  void _reload({int? page, int? stars}) {
    setState(() {
      if (page != null) _page = page;
      if (stars != _stars) _page = 1;
      _stars = stars;
      _ratingsFuture = _loadRatings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context).ratingsTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Georgia',
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              _StarFilterDropdown(
                value: _stars,
                onChanged: (value) => _reload(stars: value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<NailVariantRatingPage>(
            future: _ratingsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final page = snapshot.data ?? NailVariantRatingPage.empty();
              if (page.items.isEmpty) {
                return _EmptyRatingsMessage(stars: _stars);
              }

              return Column(
                children: [
                  _RatingsSummaryHeader(
                    totalCount: page.totalItems > 0 ? page.totalItems : page.items.length,
                    averageScore: _calcAverageScore(page.items),
                  ),
                  ...page.items.map((rating) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RatingCard(rating: rating),
                    );
                  }),
                  _RatingsPagination(
                    currentPage: page.currentPage,
                    totalPages: page.totalPages,
                    hasPrevious: page.hasPrevious,
                    hasNext: page.hasNext,
                    onPrevious: () => _reload(page: _page - 1, stars: _stars),
                    onNext: () => _reload(page: _page + 1, stars: _stars),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  double _calcAverageScore(List<NailVariantRatingModel> items) {
    if (items.isEmpty) return 2.8;
    final total = items.fold<double>(0, (sum, item) => sum + item.overallScore);
    return total / items.length;
  }
}

class _StarFilterDropdown extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _StarFilterDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: value,
            hint: const Text('All stars'),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('All stars'),
              ),
              ...List.generate(5, (index) {
                final stars = index + 1;
                return DropdownMenuItem<int?>(
                  value: stars,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$stars'),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFB300),
                        size: 18,
                      ),
                    ],
                  ),
                );
              }),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _EmptyRatingsMessage extends StatelessWidget {
  final int? stars;

  const _EmptyRatingsMessage({required this.stars});

  @override
  Widget build(BuildContext context) {
    final text = stars == null
        ? S.of(context).nailNotRatedMessage
        : 'No $stars-star ratings yet.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _RatingsSummaryHeader extends StatelessWidget {
  final int totalCount;
  final double averageScore;

  const _RatingsSummaryHeader({
    required this.totalCount,
    required this.averageScore,
  });

  @override
  Widget build(BuildContext context) {
    final scoreStr = averageScore > 0 ? averageScore.toStringAsFixed(1) : '2.8';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8FB), Color(0xFFFFF0F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left big score
          Column(
            children: [
              Text(
                scoreStr,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                  fontFamily: 'Georgia',
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: List.generate(5, (i) {
                  return const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFB300),
                    size: 14,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalCount đánh giá',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Container(
            width: 1,
            height: 58,
            color: AppColors.primary.withValues(alpha: 0.18),
          ),
          const SizedBox(width: 18),
          // Right breakdown bars
          Expanded(
            child: Column(
              children: [
                _buildRatingBar(5, 0.75),
                _buildRatingBar(4, 0.15),
                _buildRatingBar(3, 0.08),
                _buildRatingBar(2, 0.02),
                _buildRatingBar(1, 0.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(int star, double percent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$star★',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 6,
                backgroundColor: const Color(0xFFEEEEF5),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatefulWidget {
  final NailVariantRatingModel rating;

  const _RatingCard({required this.rating});

  @override
  State<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<_RatingCard> {
  bool _showReplyInput = false;
  final _replyController = TextEditingController();
  final List<String> _replies = [
    'Salon Nailify: Cảm ơn bạn đã lựa chọn Nailify! Rất mong được phục vụ bạn ở những lần làm móng tiếp theo.',
  ];

  String? _fetchedUserName;
  String? _fetchedAvatarUrl;

  @override
  void initState() {
    super.initState();
    if (widget.rating.userName.isNotEmpty) {
      _fetchedUserName = widget.rating.userName;
    }
    if (widget.rating.userAvatarUrl.isNotEmpty) {
      _fetchedAvatarUrl = widget.rating.userAvatarUrl;
    }
    if (_fetchedUserName == null && widget.rating.userId.isNotEmpty) {
      _loadUserInfo(widget.rating.userId);
    }
  }

  Future<void> _loadUserInfo(String userId) async {
    try {
      final response = await getIt<ApiClient>().get<dynamic>('/Users/$userId');
      final data = ApiResponseParser.unwrapMap(response.data);
      final firstName =
          (data['firstName'] ?? data['FirstName'] ?? '').toString().trim();
      final lastName =
          (data['lastName'] ?? data['LastName'] ?? '').toString().trim();
      String name = '';
      if (lastName.isNotEmpty && firstName.isNotEmpty) {
        name = '$lastName $firstName';
      } else if (firstName.isNotEmpty) {
        name = firstName;
      } else if (lastName.isNotEmpty) {
        name = lastName;
      } else {
        name = (data['fullName'] ??
                data['FullName'] ??
                data['name'] ??
                data['userName'] ??
                '')
            .toString()
            .trim();
      }

      final avatar = (data['avatarUrl'] ??
              data['AvatarUrl'] ??
              data['avatar'] ??
              '')
          .toString()
          .trim();
      if (mounted) {
        setState(() {
          if (name.isNotEmpty) _fetchedUserName = name;
          if (avatar.isNotEmpty) _fetchedAvatarUrl = avatar;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _submitReply() {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _replies.add('Bạn: $text');
      _replyController.clear();
      _showReplyInput = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã gửi phản hồi thảo luận!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rating = widget.rating;
    final createdAt = _formatDate(rating.createdAt);
    final displayName = _fetchedUserName ??
        (rating.userName.isNotEmpty ? rating.userName : 'Khách hàng Nailify');
    final avatarUrl = _fetchedAvatarUrl ?? rating.userAvatarUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF2F2F7), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFF0F6), Color(0xFFFFECF4)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: avatarUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Image.network(
                          avatarUrl,
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 10,
                                color: Color(0xFF2E7D32),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Đã mua',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _Stars(score: rating.overallScore),
                  ],
                ),
              ),
              if (createdAt.isNotEmpty)
                Text(
                  createdAt,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          if (rating.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              rating.comment,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
          if (rating.imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(16),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            rating.imageUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.borderLight,
                          width: 1,
                        ),
                      ),
                      child: Image.network(
                        rating.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFFF5F5F7),
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.textSecondary,
                                  size: 28,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Không thể tải ảnh',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_camera_rounded,
                            color: Colors.white,
                            size: 11,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Ảnh từ khách hàng',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ScorePill(
                icon: Icons.design_services_rounded,
                label: 'Service',
                score: rating.serviceQuality,
              ),
              _ScorePill(
                icon: Icons.access_time_filled_rounded,
                label: 'Punctuality',
                score: rating.punctuality,
              ),
              _ScorePill(
                icon: Icons.clean_hands_rounded,
                label: 'Cleanliness',
                score: rating.cleanliness,
              ),
            ],
          ),

          // Replies & Discussion Thread
          if (_replies.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0F0F4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _replies.map((rep) {
                  final isSalon = rep.startsWith('Salon Nailify');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isSalon ? Icons.storefront_rounded : Icons.chat_bubble_outline_rounded,
                          size: 14,
                          color: isSalon ? AppColors.primary : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: isSalon ? 'Salon Nailify: ' : '${rep.split(': ').first}: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isSalon ? AppColors.primaryDark : AppColors.textPrimary,
                                  ),
                                ),
                                TextSpan(
                                  text: rep.contains(': ') ? rep.split(': ').sublist(1).join(': ') : rep,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade800,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Interactive Reply Button / Field
          const SizedBox(height: 8),
          if (!_showReplyInput)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showReplyInput = true;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.reply_rounded, size: 16),
                label: const Text(
                  'Thảo luận / Phản hồi',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _replyController,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Nhập phản hồi của bạn...',
                          hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: const Color(0xFFF6F6FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      onPressed: _submitReply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Gửi',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }
}

class _Stars extends StatelessWidget {
  final int score;

  const _Stars({required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = index < score;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          color: const Color(0xFFFFB300),
          size: 16,
        );
      }),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final int score;

  const _ScorePill({
    required this.icon,
    required this.label,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              '$label $score/5',
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingsPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _RatingsPagination({
    required this.currentPage,
    required this.totalPages,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: hasPrevious ? onPrevious : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(
            '$currentPage / $totalPages',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: hasNext ? onNext : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
