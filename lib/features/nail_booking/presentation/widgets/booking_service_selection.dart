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

  void _addSlot() {
    final next = List<String?>.from(selectedExtraServices)..add(null);
    onChanged(next);
  }

  void _removeSlot(int index) {
    final next = List<String?>.from(selectedExtraServices)..removeAt(index);
    onChanged(next);
  }

  void _selectService(int index, String? serviceId) {
    final next = List<String?>.from(selectedExtraServices);
    next[index] = serviceId;
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final availableServices = _availableServices;
    final canAddMore = selectedExtraServices.length < availableServices.length;
    final isWarranty = nailData?['warrantyForBookingId'] != null;
    final warrantyBookingItems = nailData?['warrantyBookingItems'] != null
        ? List<Map<String, dynamic>>.from(nailData!['warrantyBookingItems'] as List)
        : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Dịch vụ chính (Locked default selection) hoặc Chọn dịch vụ cần bảo hành
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
            final isSelected = selectedWarrantyItems.any((selected) =>
                _isSameItem(selected, item));
            
            final names = [
              item['nailVariantName']?.toString().trim() ?? '',
              item['customerNailName']?.toString().trim() ?? '',
              item['serviceName']?.toString().trim() ?? '',
            ].where((name) => name.isNotEmpty).toList();
            final name = names.isEmpty ? 'Dịch vụ bảo hành' : names.join(' & ');
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.04) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary.withOpacity(0.3) : const Color(0xFFF3EFEA),
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
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                onChanged: (val) {
                  final next = List<Map<String, dynamic>>.from(selectedWarrantyItems);
                  if (val == true) {
                    if (!next.any((selected) => _isSameItem(selected, item))) {
                      next.add(item);
                    }
                  } else {
                    next.removeWhere((selected) => _isSameItem(selected, item));
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

        // 2. Dịch vụ phụ trợ / đi kèm
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
            if (selectedExtraServices.isNotEmpty)
              Text(
                'Đã chọn ${selectedExtraServices.where((id) => id != null).length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // List of dropdown slots
        if (availableServices.isNotEmpty) ...[
          ...List.generate(selectedExtraServices.length, (index) {
            return _buildSlotRow(context, index, availableServices);
          }),
          const SizedBox(height: 6),
          _buildAddButton(canAddMore),
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

  Widget _buildSlotRow(BuildContext context, int index, List<Map<String, dynamic>> availableServices) {
    final selectedId = selectedExtraServices[index];
    Map<String, dynamic>? selectedService;
    for (final s in availableServices) {
      if (_serviceId(s) == selectedId) {
        selectedService = s;
        break;
      }
    }

    final selectedIds = selectedExtraServices.where((id) => id != null).toSet();
    final options = availableServices.where((s) {
      final id = _serviceId(s);
      if (id == selectedId) return true;
      return !selectedIds.contains(id);
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: selectedService != null
                ? _buildSelectedCard(context, index, selectedService, options)
                : _buildPlaceholderCard(context, index, options),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _removeSlot(index),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cancel_rounded,
                color: Colors.red.shade400,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCard(
    BuildContext context,
    int index,
    Map<String, dynamic> service,
    List<Map<String, dynamic>> options,
  ) {
    final name = _serviceName(service);
    final price = _servicePrice(service);
    final duration = _serviceDuration(service);

    return PopupMenuButton<String>(
      onSelected: (value) => _selectService(index, value),
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      itemBuilder: (context) => options.map((s) {
        return PopupMenuItem<String>(
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
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
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
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF3EFEA), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 6,
              offset: const Offset(0, 2),
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
                      Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        DurationFormatter.format(duration),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              PriceFormatter.format(price),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard(
    BuildContext context,
    int index,
    List<Map<String, dynamic>> options,
  ) {
    return PopupMenuButton<String>(
      onSelected: (value) => _selectService(index, value),
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      itemBuilder: (context) => options.map((s) {
        return PopupMenuItem<String>(
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
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
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
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF3EFEA), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Chọn dịch vụ phụ trợ...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(bool enabled) {
    return OutlinedButton.icon(
      onPressed: enabled ? _addSlot : null,
      icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
      label: const Text(
        'Thêm dịch vụ',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          fontSize: 14,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.primary, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildNailVariantCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.diamond_outlined,
              color: AppColors.primary,
              size: 24,
            ),
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
            child: const Icon(Icons.lock_rounded, size: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

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
    if (a['customerNailRequestId'] != null && b['customerNailRequestId'] != null) {
      return a['customerNailRequestId'].toString() == b['customerNailRequestId'].toString();
    }
    return false;
  }
}
