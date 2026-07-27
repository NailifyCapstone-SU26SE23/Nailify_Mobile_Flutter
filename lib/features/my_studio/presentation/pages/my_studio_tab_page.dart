import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../nails/data/repositories/customer_component_repository.dart';
import '../../../nails/data/repositories/customer_nail_repository.dart';
import '../tabs/customer_components_tab.dart';
import '../tabs/customer_nail_requests_tab.dart';
import '../tabs/customer_nails_tab.dart';
import '../../../../core/constants/app_colors.dart';

/// Trang studio với 3 tab: My Nails, My Components, Requests.
/// Được điều hướng từ footer "My Studio".
class MyStudioTabPage extends StatefulWidget {
  const MyStudioTabPage({super.key});

  @override
  State<MyStudioTabPage> createState() => _MyStudioTabPageState();
}

class _MyStudioTabPageState extends State<MyStudioTabPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _customerNailRepository = getIt<CustomerNailRepository>();
  final _customerComponentRepository = getIt<CustomerComponentRepository>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reloadData() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Studio',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'My Nails'),
                Tab(text: 'Components'),
                Tab(text: 'Requests'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CustomerNailsTab(
            repository: _customerNailRepository,
            onDataChanged: _reloadData,
          ),
          CustomerComponentsTab(
            repository: _customerComponentRepository,
            onDataChanged: _reloadData,
          ),
          const CustomerNailRequestsTab(),
        ],
      ),
    );
  }
}
