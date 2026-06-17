import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../data/models/booking_mock_data.dart';

class BookingServiceSelection extends StatelessWidget {
  final Map<String, dynamic>? nailData;
  final List<dynamic> services;
  final List<String> selectedExtraServices;
  final ValueChanged<List<String>> onChanged;

  const BookingServiceSelection({
    super.key,
    required this.nailData,
    required this.services,
    required this.selectedExtraServices,
    required this.onChanged,
  });

  List<Map<String, dynamic>> get _availableServices {
    final source = services.isEmpty ? BookingMockData.extraServices : services;
    return source
        .whereType<Map>()
        .map((service) => Map<String, dynamic>.from(service))
        .where((service) => _serviceId(service).isNotEmpty)
        .toList();
  }

  String _serviceId(Map<String, dynamic> service) =>
      service['serviceId']?.toString() ?? service['id']?.toString() ?? '';

  String _serviceName(Map<String, dynamic> service) =>
      service['serviceName']?.toString() ?? service['name']?.toString() ?? '';

  dynamic _servicePrice(Map<String, dynamic> service) =>
      service['price'] ?? service['basePrice'];

  void _toggleService(String serviceId, bool selected) {
    final next = List<String>.from(selectedExtraServices);
    if (selected) {
      if (!next.contains(serviceId)) next.add(serviceId);
    } else {
      next.remove(serviceId);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final availableServices = _availableServices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dịch vụ *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        if (nailData != null) _buildNailVariantCard(),
        if (availableServices.isEmpty)
          const Text(
            'Không có dịch vụ phụ trợ',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          ...availableServices.map(_buildServiceRow),
      ],
    );
  }

  Widget _buildNailVariantCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.diamond_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dịch vụ thiết kế Nail (Mặc định)',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  nailData!['name']?.toString() ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildServiceRow(Map<String, dynamic> service) {
    final serviceId = _serviceId(service);
    final isSelected = selectedExtraServices.contains(serviceId);
    final price = _servicePrice(service);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey.shade300,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) => _toggleService(serviceId, value ?? false),
        activeColor: AppColors.primary,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        title: Text(
          _serviceName(service),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: price == null
            ? null
            : Text(
                PriceFormatter.format(price),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
      ),
    );
  }
}
