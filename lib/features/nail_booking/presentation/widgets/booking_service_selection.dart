import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/duration_formatter.dart';

class BookingServiceSelection extends StatelessWidget {
  final Map<String, dynamic>? nailData;
  final List<dynamic> services;
  final List<String?> selectedExtraServices;
  final ValueChanged<List<String?>> onChanged;

  const BookingServiceSelection({
    super.key,
    required this.nailData,
    required this.services,
    required this.selectedExtraServices,
    required this.onChanged,
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
      service['name']?.toString() ?? service['serviceName']?.toString() ?? 'Dịch vụ';

  dynamic _servicePrice(Map<String, dynamic> service) =>
      service['price'] ?? service['basePrice'] ?? 0;

  dynamic _serviceDuration(Map<String, dynamic> service) =>
      service['duration'] ?? 0;

  void _addService() {
    final next = List<String?>.from(selectedExtraServices);
    next.add(null);
    onChanged(next);
  }

  void _removeService(int index) {
    final next = List<String?>.from(selectedExtraServices);
    next.removeAt(index);
    onChanged(next);
  }

  void _updateService(int index, String? value) {
    final next = List<String?>.from(selectedExtraServices);
    next[index] = value;
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final availableServices = _availableServices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dịch vụ chính của bạn',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Georgia',
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 14),

        if (nailData != null) _buildNailVariantCard(),

        if (availableServices.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Chọn thêm dịch vụ phụ trợ (Tùy chọn)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 14),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: selectedExtraServices.length,
            itemBuilder: (context, index) {
              final selectedId = selectedExtraServices[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFF3EFEA), width: 1.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedId,
                            hint: const Text(
                              'Chọn dịch vụ phụ trợ...',
                              style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                            isExpanded: true,
                            icon: const Icon(Icons.expand_more_rounded, size: 20, color: Colors.grey),
                            itemHeight: 64,
                            items: availableServices.map((service) {
                              final id = _serviceId(service);
                              final name = _serviceName(service);
                              final price = _servicePrice(service);
                              final duration = _serviceDuration(service);

                              return DropdownMenuItem<String>(
                                value: id,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            DurationFormatter.format(duration),
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      PriceFormatter.format(price),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => _updateService(index, val),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _removeService(index),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.red.shade100, width: 1),
                        ),
                        child: Icon(Icons.close_rounded, color: Colors.red.shade600, size: 18),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        if (availableServices.isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addService,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Thêm dịch vụ phụ trợ', style: TextStyle(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ] else ...[
          const Text(
            'Hiện không có dịch vụ phụ trợ nào.',
            style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
          )
        ],
      ],
    );
  }

  Widget _buildNailVariantCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD1E1), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thiết kế Nail đã chọn',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  nailData!['name']?.toString() ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primary),
        ],
      ),
    );
  }
}
