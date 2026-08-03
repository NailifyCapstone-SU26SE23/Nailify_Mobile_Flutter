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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải dịch vụ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Dịch vụ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
            fontFamily: 'Georgia',
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: _isLoading
          ? const ServiceListSkeleton()
          : _services.isEmpty
          ? const Center(child: Text('Không có dịch vụ nào khả dụng.'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100), // extra padding bottom for safe scroll
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFF0F5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4081).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            if (serviceId.isNotEmpty) {
              context.push('/services/$serviceId');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4081).withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.spa_rounded,
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
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Georgia',
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DurationFormatter.format(duration),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF4081),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ServiceListSkeleton extends StatelessWidget {
  const ServiceListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFF0F5), width: 1.5),
          ),
          child: Row(
            children: [
              const SkeletonBox(
                width: 50,
                height: 50,
                borderRadius: BorderRadius.all(Radius.circular(25)),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 18),
                    SizedBox(height: 8),
                    SkeletonBox(width: 80, height: 12),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const SkeletonBox(width: 70, height: 16),
            ],
          ),
        );
      },
    );
  }
}

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFF5F5F7),
                Color.lerp(
                  const Color(0xFFF5F5F7),
                  const Color(0xFFFF4081).withValues(alpha: 0.08),
                  _controller.value,
                )!,
                const Color(0xFFF5F5F7),
              ],
            ),
          ),
        );
      },
    );
  }
}
