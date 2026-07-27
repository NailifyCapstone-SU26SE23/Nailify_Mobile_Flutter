import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/duration_formatter.dart';

class BookingServiceSelection extends StatelessWidget {
  final Map<String, dynamic>? nailData;
  final List<dynamic> services;
  final List<String?> selectedExtraServices;
  final ValueChanged<List<String?>> onChanged;
  final List<Map<String, dynamic>> selectedWarrantyItems;
  final ValueChanged<List<Map<String, dynamic>>>? onWarrantyItemsChanged;

  const BookingServiceSelection({
    super.key,
    required this.nailData,
    required this.services,
    required this.selectedExtraServices,
    required this.onChanged,
    this.selectedWarrantyItems = const [],
    this.onWarrantyItemsChanged,
  });

  List<Map<String, dynamic>> get _availableServices {
    return services
        .whereType<Map>()
        .map((service) => Map<String, dynamic>.from(service))
        .where((service) => _serviceId(service).isNotEmpty)
        .toList();
  }

  String _serviceId(Map<String, dynamic> service) =>
      service['serviceId']?.toString() ?? service['id']?.toString() ?? '';

  String _serviceName(Map<String, dynamic> service) =>
      service['name']?.toString() ??
      service['serviceName']?.toString() ??
      'Dịch vụ';

  dynamic _servicePrice(Map<String, dynamic> service) =>
      service['price'] ?? service['basePrice'] ?? 0;

  dynamic _serviceDuration(Map<String, dynamic> service) =>
      service['duration'] ?? 0;

  // ── Extra-service mutations ───────────────────────────────────────────────

  void _addService(String serviceId) {
    final next = List<String?>.from(selectedExtraServices)..add(serviceId);
    onChanged(next);
  }

  void _decrementService(String serviceId) {
    final next = List<String?>.from(selectedExtraServices);
    final idx = next.lastIndexOf(serviceId);
    if (idx >= 0) next.removeAt(idx);
    onChanged(next);
  }

  void _removeAllInstances(String serviceId) {
    final next = List<String?>.from(selectedExtraServices)
      ..removeWhere((id) => id == serviceId);
    onChanged(next);
  }

  /// Returns unique service IDs in insertion order with their counts.
  Map<String, int> get _serviceCounts {
    final counts = <String, int>{};
    for (final id in selectedExtraServices) {
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final availableServices = _availableServices;
    final isWarranty = nailData?['warrantyForBookingId'] != null;
    final warrantyBookingItems = nailData?['warrantyBookingItems'] != null
        ? List<Map<String, dynamic>>.from(nailData!['warrantyBookingItems'] as List)
        : <Map<String, dynamic>>[];

    final counts = _serviceCounts;
    final totalSelectedCount = counts.values.fold(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Warranty items / main service ─────────────────────────────
        if (isWarranty && warrantyBookingItems.isNotEmpty) ...[
          const Text(
            'Chọn dịch vụ cần bảo hành',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...warrantyBookingItems.map((item) {
            final isSelected = selectedWarrantyItems
                .any((selected) => _isSameItem(selected, item));

            final names = [
              item['nailVariantName']?.toString().trim() ?? '',
              item['customerNailName']?.toString().trim() ?? '',
              item['serviceName']?.toString().trim() ?? '',
            ].where((name) => name.isNotEmpty).toList();
            final name =
                names.isEmpty ? 'Dịch vụ bảo hành' : names.join(' & ');

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.04)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.3)
                      : const Color(0xFFF3EFEA),
                  width: 1.2,
                ),
              ),
              child: CheckboxListTile(
                value: isSelected,
                activeColor: AppColors.primary,
                title: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Bảo hành miễn phí • Số lượng: ${item['quantity'] ?? 1}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                onChanged: (val) {
                  final next = List<Map<String, dynamic>>.from(
                      selectedWarrantyItems);
                  if (val == true) {
                    if (!next.any((s) => _isSameItem(s, item))) next.add(item);
                  } else {
                    next.removeWhere((s) => _isSameItem(s, item));
                  }
                  onWarrantyItemsChanged?.call(next);
                },
              ),
            );
          }),
          const SizedBox(height: 24),
        ] else if (nailData != null) ...[
          const Text(
            'Dịch vụ chính',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildNailVariantCard(),
          const SizedBox(height: 24),
        ],

        // ── 2. "Dịch vụ đi kèm" header ──────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Dịch vụ đi kèm',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (totalSelectedCount > 0)
              Text(
                'Đã chọn $totalSelectedCount',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ── 3. Service cards (quantity-grouped) + add button ──────────────
        if (availableServices.isNotEmpty) ...[
          ...counts.entries.map((entry) {
            final serviceId = entry.key;
            final count = entry.value;
            Map<String, dynamic>? service;
            for (final s in availableServices) {
              if (_serviceId(s) == serviceId) {
                service = s;
                break;
              }
            }
            if (service == null) return const SizedBox.shrink();
            return _buildServiceCard(service, count, serviceId);
          }),
          const SizedBox(height: 6),
          _buildAddButton(context, availableServices),
        ] else
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Hiện không có dịch vụ phụ trợ nào.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Service quantity card ─────────────────────────────────────────────────

  Widget _buildServiceCard(
      Map<String, dynamic> service, int count, String serviceId) {
    final name = _serviceName(service);
    final unitPrice = _servicePrice(service);
    final duration = _serviceDuration(service);
    final totalPrice = (unitPrice is num) ? unitPrice * count : unitPrice;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: const Color(0xFFF3EFEA), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.01),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: name, duration, total price
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                    size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  DurationFormatter.format(duration),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            PriceFormatter.format(totalPrice),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          if (count > 1)
                            Text(
                              '${PriceFormatter.format(unitPrice)} / cái',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // Quantity stepper — shown only when count > 1
                  if (count > 1) ...[
                    const SizedBox(height: 10),
                    Divider(height: 1, color: Colors.grey.shade100),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Số lượng',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        _buildStepper(count, serviceId),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Remove-all button
          GestureDetector(
            onTap: () => _removeAllInstances(serviceId),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cancel_rounded,
                  color: Colors.red.shade400, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quantity stepper ─────────────────────────────────────────────────────

  Widget _buildStepper(int count, String serviceId) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: AppColors.primary.withOpacity(0.35), width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _decrementService(serviceId),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(Icons.remove_rounded,
                  size: 16, color: AppColors.primary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _addService(serviceId),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(Icons.add_rounded,
                  size: 16, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── "Thêm dịch vụ" picker ────────────────────────────────────────────────

  Widget _buildAddButton(
      BuildContext context, List<Map<String, dynamic>> availableServices) {
    return PopupMenuButton<String>(
      onSelected: _addService,
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      itemBuilder: (context) => availableServices
          .map(
            (s) => PopupMenuItem<String>(
              value: _serviceId(s),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _serviceName(s),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DurationFormatter.format(_serviceDuration(s)),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    PriceFormatter.format(_servicePrice(s)),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary, width: 1.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Thêm dịch vụ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Nail-variant card (normal booking) ───────────────────────────────────

  Widget _buildNailVariantCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.diamond_outlined,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dịch vụ thiết kế Nail (Mặc định)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nailData!['name']?.toString() ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15.5,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded,
                size: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  bool _isSameItem(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a['nailVariantId'] != null && b['nailVariantId'] != null) {
      return a['nailVariantId'].toString() == b['nailVariantId'].toString();
    }
    if (a['serviceId'] != null && b['serviceId'] != null) {
      return a['serviceId'].toString() == b['serviceId'].toString();
    }
    if (a['customerNailId'] != null && b['customerNailId'] != null) {
      return a['customerNailId'].toString() == b['customerNailId'].toString();
    }
    if (a['customerNailRequestId'] != null &&
        b['customerNailRequestId'] != null) {
      return a['customerNailRequestId'].toString() ==
          b['customerNailRequestId'].toString();
    }
    return false;
  }
}
