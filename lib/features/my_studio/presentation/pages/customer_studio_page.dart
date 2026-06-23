import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../cubit/studio_cubit.dart';
import '../widgets/studio_nail_card.dart';
import '../../data/models/customer_nail_model.dart';

class CustomerStudioPage extends StatelessWidget {
  const CustomerStudioPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject Cubit vào Tree và lập tức gọi API
    return BlocProvider(
      create: (context) => StudioListCubit()..fetchNails(),
      child: DefaultTabController(
        length: 5,
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
                Tab(text: 'Đang xử lý'), // Gộp 4 trạng thái Review, Assigned, Reviewed, Quoted
                Tab(text: 'Đã duyệt'),
                Tab(text: 'Từ chối'),
              ],
            ),
          ),
          // Bắt sự kiện State để Render UI
          body: BlocBuilder<StudioListCubit, StudioListState>(
            builder: (context, state) {
              if (state is StudioListLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is StudioListError) {
                return Center(child: Text('Lỗi: ${state.message}'));
              }
              if (state is StudioListLoaded) {
                return TabBarView(
                  children: [
                    _buildList(context, state.nails, ['Draft']),
                    _buildList(context, state.nails, ['Pending']),
                    _buildList(context, state.nails, ['Review', 'Assigned', 'Reviewed', 'Quoted']),
                    _buildList(context, state.nails, ['Approved']),
                    _buildList(context, state.nails, ['Rejected']),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/custom-nail'),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Tạo mẫu mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<CustomerNailModel> allNails, List<String> statuses) {
    // Lọc theo mảng status
    final items = allNails.where((n) => statuses.contains(n.status)).toList();

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

    return RefreshIndicator(
      onRefresh: () => context.read<StudioListCubit>().fetchNails(),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return StudioNailCard(
            nail: items[index],
            onTap: () => context.push('/my-studio/${items[index].id}'),
          );
        },
      ),
    );
  }
}