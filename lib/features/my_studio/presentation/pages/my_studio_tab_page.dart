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
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          dividerColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: TextStyle(
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(text: 'My nails'),
            Tab(text: 'My components'),
            Tab(text: 'Requests'),
          ],
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
