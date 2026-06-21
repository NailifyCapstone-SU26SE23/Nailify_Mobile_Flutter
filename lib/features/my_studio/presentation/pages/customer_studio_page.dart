import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/studio_mock_data.dart';
import '../widgets/studio_nail_card.dart';

class CustomerStudioPage extends StatelessWidget {
  const CustomerStudioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('My Studio', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Bản nháp'),
              Tab(text: 'Chờ duyệt'),
              Tab(text: 'Đã duyệt'),
              Tab(text: 'Từ chối'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(context, 'Draft'),
            _buildList(context, 'Pending'),
            _buildList(context, 'Approved'),
            _buildList(context, 'Rejected'),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/custom-nail'),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Tạo mẫu móng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, String status) {
    final items = StudioMockData.myCustomNails.where((n) => n.status == status).toList();

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.design_services_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Chưa có mẫu móng nào.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return StudioNailCard(
          nail: items[index],
          onTap: () => context.push('/my-studio/${items[index].id}'),
        );
      },
    );
  }
}