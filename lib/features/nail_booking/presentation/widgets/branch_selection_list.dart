import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';

class BranchSelectionList extends StatelessWidget {
  final List<dynamic> salons;
  final bool isLoading;
  final String? selectedBranchId;
  final Function(dynamic) onBranchSelected;

  const BranchSelectionList({
    super.key,
    required this.salons,
    required this.isLoading,
    required this.selectedBranchId,
    required this.onBranchSelected,
  });

  // --- HÀM HIỂN THỊ POPUP OPENSTREETMAP ---
  void _showMapPopup(BuildContext context, dynamic salon) {
    // ---------------------------------------------------------
    // 1. TỌA ĐỘ TỪ API (Đã chuẩn bị sẵn)
    // Sau này khi API trả về tọa độ thật, hãy mở comment 2 dòng này:
    // ---------------------------------------------------------
    // final double lat = (salon['latitude'] as num?)?.toDouble() ?? 0.0;
    // final double lng = (salon['longitude'] as num?)?.toDouble() ?? 0.0;

    // ---------------------------------------------------------
    // 2. TỌA ĐỘ HARDCODE (Dùng tạm thời)
    // Khi mở lại đoạn 1 thì nhớ xóa/comment đoạn 2 này nhé
    // ---------------------------------------------------------
    final double lat = 10.993592755518687;
    final double lng = 106.65636465428618;

    final LatLng targetPosition = LatLng(lat, lng);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Cho phép tùy chỉnh chiều cao tự do
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        // Đặt chiều cao bằng 80% chiều cao màn hình
        final double height = MediaQuery.of(context).size.height * 0.8;

        return Container(
          height: height,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Thanh kéo (Handle) & Tiêu đề
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Vị trí: ${salon['name']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      salon['address'] ?? '',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Bản đồ
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: targetPosition, // Tâm bản đồ
                      initialZoom: 16.0, // Độ zoom
                    ),
                    children: [
                      // hình ảnh bản đồ từ OpenStreetMap
                      // TileLayer(
                      //   urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      //   userAgentPackageName: 'com.nailify.app', // Khai báo package app để tránh bị chặn IP
                      // ),
                      TileLayer(
                        urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.nailify.app',
                      ),
                      // Lớp ghim vị trí (Marker)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: targetPosition,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.primary, // Đổi màu ghim cho hợp tone màu chủ đạo của App
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (salons.isEmpty) return const Text('Không có chi nhánh nào.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: salons.map((salon) {
        bool isSelected = selectedBranchId == salon['salonId'];

        return GestureDetector(
          onTap: () => onBranchSelected(salon), // Chạm bình thường để chọn
          onLongPress: () => _showMapPopup(context, salon), // Giữ lâu để mở Map
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront, size: 30, color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        salon['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isSelected ? AppColors.primary : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        salon['address'],
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}