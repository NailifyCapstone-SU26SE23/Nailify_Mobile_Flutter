import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../data/datasources/service_api_service.dart';

class ServiceListPage extends StatefulWidget {
  const ServiceListPage({super.key});

  @override
  State<ServiceListPage> createState() => _ServiceListPageState();
}

class _ServiceListPageState extends State<ServiceListPage> {
  final ServiceApiService _apiService = ServiceApiService();
  List<dynamic> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      final data = await _apiService.getServices(pageNumber: 1, pageSize: 20);
      if (mounted) {
        setState(() {
          _services = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải dịch vụ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text('Dịch vụ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.go('/'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _services.isEmpty
          ? const Center(child: Text('Không có dịch vụ nào khả dụng.'))
          : ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        itemCount: _services.length,
        itemBuilder: (context, index) {
          final service = _services[index];
          return _buildServiceCard(service);
        },
      ),
    );
  }

  Widget _buildServiceCard(dynamic service) {
    final String serviceId = service['serviceId'] ?? '';
    final String name = service['name']?.toString().trim() ?? 'Dịch vụ';
    final int price = (service['price'] as num?)?.toInt() ?? 0;
    final int duration = (service['duration'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: () {
        if (serviceId.isNotEmpty) {
          context.push('/services/$serviceId');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.spa_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(DurationFormatter.format(duration), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(PriceFormatter.format(price), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15)),
              ],
            )
          ],
        ),
      ),
    );
  }
}