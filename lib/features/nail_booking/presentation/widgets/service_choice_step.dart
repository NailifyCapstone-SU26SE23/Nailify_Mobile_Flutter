import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../nails/data/models/nail_variant_model.dart';
import '../../../nails/data/models/shape_method_config_model.dart';
import '../../../nails/data/repositories/nail_variant_repository.dart';
import '../../data/datasources/capable_nails_api_service.dart';
import 'booking_service_selection.dart';
import 'nail_variant_detail_sheet.dart';

/// Step chọn dịch vụ với 2 tab:
/// - "Làm nail": load từ API capable-by-artist, hiển thị grid nail variants
/// - "Dịch vụ khác": tái sử dụng BookingServiceSelection
class ServiceChoiceStep extends StatefulWidget {
  /// ID thợ đã chọn (null nếu khách chọn "Tự động phân công").
  final String? selectedArtistId;

  /// Danh sách service thường (không bao gồm nail variant).
  final List<dynamic> services;
  final List<String?> selectedExtraServices;
  final ValueChanged<List<String?>> onExtraServicesChanged;

  /// Nail variant được chọn (null = chưa chọn nail).
  final NailVariantModel? selectedNailVariant;
  final ValueChanged<NailVariantModel?> onNailVariantChanged;

  /// Shape method config (chỉ khi đã chọn nail).
  final ShapeMethodConfigModel? selectedShapeMethod;
  final ValueChanged<ShapeMethodConfigModel?> onShapeMethodChanged;

  const ServiceChoiceStep({
    super.key,
    required this.selectedArtistId,
    required this.services,
    required this.selectedExtraServices,
    required this.onExtraServicesChanged,
    required this.selectedNailVariant,
    required this.onNailVariantChanged,
    required this.selectedShapeMethod,
    required this.onShapeMethodChanged,
  });

  @override
  State<ServiceChoiceStep> createState() => _ServiceChoiceStepState();
}

class _ServiceChoiceStepState extends State<ServiceChoiceStep>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<List<NailVariantModel>> _capableNailsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _capableNailsFuture = _loadCapableNails();
  }

  Future<List<NailVariantModel>> _loadCapableNails() {
    final artistId = widget.selectedArtistId;
    if (artistId == null || artistId.isEmpty) {
      return Future.value(const []);
    }
    return CapableNailsApiService().getCapableNailsByArtist(artistId);
  }

  @override
  void didUpdateWidget(covariant ServiceChoiceStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedArtistId != widget.selectedArtistId) {
      // Reset nail variant selection khi đổi thợ.
      widget.onNailVariantChanged(null);
      widget.onShapeMethodChanged(null);
      setState(() {
        _capableNailsFuture = _loadCapableNails();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildHeader(),
        const SizedBox(height: 16),
        _buildCustomTabBar(),
        const SizedBox(height: 16),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [_buildNailTab(), _buildServiceTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn dịch vụ cho bạn',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Georgia',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Thỏa sức sáng tạo với bộ nail mới hoặc thêm dịch vụ đi kèm',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFFFF80AB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        indicatorPadding: EdgeInsets.zero,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade700,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.spa_rounded, size: 18),
                SizedBox(width: 8),
                Text('Làm nail'),
              ],
            ),
          ),
          Tab(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.room_service_rounded, size: 18),
                SizedBox(width: 8),
                Text('Dịch vụ khác'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNailTab() {
    if (widget.selectedArtistId == null || widget.selectedArtistId!.isEmpty) {
      return _buildNoArtistPlaceholder();
    }
    return FutureBuilder<List<NailVariantModel>>(
      future: _capableNailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error.toString());
        }
        final variants = snapshot.data ?? const [];
        if (variants.isEmpty) {
          return _buildEmptyNailsView();
        }
        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: variants.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.68,
          ),
          itemBuilder: (context, index) {
            return _NailVariantCard(
              variant: variants[index],
              isSelected:
                  widget.selectedNailVariant?.nailVariantId ==
                  variants[index].nailVariantId,
              onTap: () async {
                if (widget.selectedNailVariant?.nailVariantId ==
                    variants[index].nailVariantId) {
                  // Bấm lại card đã chọn → bỏ chọn
                  widget.onNailVariantChanged(null);
                  widget.onShapeMethodChanged(null);
                } else {
                  // Chọn mới
                  widget.onNailVariantChanged(variants[index]);
                  // Load shape method mặc định (item đầu tiên không inactive)
                  final shapeMethod = await _fetchDefaultShapeMethod(
                    variants[index],
                  );
                  widget.onShapeMethodChanged(shapeMethod);
                }
              },
              onDetailTap: () => _openDetail(variants[index]),
            );
          },
        );
      },
    );
  }

  Future<ShapeMethodConfigModel?> _fetchDefaultShapeMethod(
    NailVariantModel variant,
  ) async {
    try {
      final methods = await getIt<NailVariantRepository>()
          .getShapeMethodConfigsByNailShape(variant.nailShapeId);
      final active = methods
          .where((m) => m.status.toLowerCase() != 'inactive')
          .toList();
      return active.isNotEmpty
          ? active.first
          : (methods.isNotEmpty ? methods.first : null);
    } catch (_) {
      return null;
    }
  }

  void _openDetail(NailVariantModel variant) async {
    final shapeMethod = await NailVariantDetailSheet.show(
      context,
      variant: variant,
    );
    if (shapeMethod != null && mounted) {
      widget.onNailVariantChanged(variant);
      widget.onShapeMethodChanged(shapeMethod);
    } else if (mounted) {
      // Đóng sheet mà không chọn → vẫn set variant để có thể xem nhanh
      widget.onNailVariantChanged(variant);
    }
  }

  Widget _buildServiceTab() {
    return BookingServiceSelection(
      nailData: widget.selectedNailVariant != null
          ? {
              'id': widget.selectedNailVariant!.nailVariantId.toString(),
              'name': widget.selectedNailVariant!.name,
            }
          : null,
      services: widget.services,
      selectedExtraServices: widget.selectedExtraServices,
      onChanged: widget.onExtraServicesChanged,
    );
  }

  Widget _buildNoArtistPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_search_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Vui lòng chọn thợ trước',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Để xem các mẫu nail mà thợ có thể thực hiện, hãy quay lại bước chọn thợ nhé.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyNailsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spa_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Thợ này chưa có mẫu nail nào',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bạn vẫn có thể chọn dịch vụ khác ở tab bên cạnh.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 12),
            Text(
              'Không tải được danh sách nail',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _capableNailsFuture = _loadCapableNails();
                });
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NailVariantCard extends StatelessWidget {
  final NailVariantModel variant;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDetailTap;

  const _NailVariantCard({
    required this.variant,
    required this.isSelected,
    required this.onTap,
    required this.onDetailTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFF3EFEA),
            width: isSelected ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 14 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 110,
                    child: variant.imageUrl.isEmpty
                        ? Container(
                            color: const Color(0xFFF5F5F7),
                            child: const Icon(
                              Icons.spa_rounded,
                              color: AppColors.primary,
                              size: 36,
                            ),
                          )
                        : Image.network(variant.imageUrl, fit: BoxFit.cover),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    variant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DurationFormatter.format(variant.duration ?? 0),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    PriceFormatter.format(
                      variant.price,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onDetailTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Chi tiết',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: GestureDetector(
                          onTap: onTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isSelected
                                    ? [
                                        Colors.grey.shade400,
                                        Colors.grey.shade500,
                                      ]
                                    : const [
                                        AppColors.primary,
                                        Color(0xFFFF80AB),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              isSelected ? 'Đã chọn' : 'Chọn',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
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
      ),
    );
  }
}

/// Public helper để widget con có thể gọi từ bên ngoài
