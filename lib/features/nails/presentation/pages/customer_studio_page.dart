import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../data/repositories/nail_repository.dart';
import '../tabs/customer_components_tab.dart';
import '../tabs/customer_nails_tab.dart';

class CustomerStudioPage extends StatefulWidget {
  const CustomerStudioPage({super.key});

  @override
  State<CustomerStudioPage> createState() => _CustomerStudioPageState();
}

class _CustomerStudioPageState extends State<CustomerStudioPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repository = getIt<NailRepository>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reloadData() {
    // This will trigger both tabs to refresh via their own state management
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Studio của tôi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/profile'),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.spa), text: 'Móng của tôi'),
            Tab(icon: Icon(Icons.star), text: 'Thành phần của tôi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CustomerNailsTab(
            repository: _repository,
            onDataChanged: _reloadData,
          ),
          CustomerComponentsTab(
            repository: _repository,
            onDataChanged: _reloadData,
          ),
        ],
      ),
    );
  }
}