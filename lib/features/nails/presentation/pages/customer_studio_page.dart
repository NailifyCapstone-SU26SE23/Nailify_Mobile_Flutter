import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../data/repositories/customer_component_repository.dart';
import '../../data/repositories/customer_nail_repository.dart';
import '../tabs/customer_components_tab.dart';
import '../tabs/customer_nail_requests_tab.dart';
import '../tabs/customer_nails_tab.dart';

class CustomerStudioPage extends StatefulWidget {
  const CustomerStudioPage({super.key});

  @override
  State<CustomerStudioPage> createState() => _CustomerStudioPageState();
}

class _CustomerStudioPageState extends State<CustomerStudioPage>
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
        title: const Text('My Studio'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.spa), text: 'My nails'),
            Tab(icon: Icon(Icons.star), text: 'My components'),
            Tab(icon: Icon(Icons.assignment), text: 'Requests'),
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
