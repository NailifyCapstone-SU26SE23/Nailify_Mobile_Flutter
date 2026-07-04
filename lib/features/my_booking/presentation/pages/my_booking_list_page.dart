import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/datasources/my_booking_api_service.dart';
import '../utils/booking_status_utils.dart';

class MyBookingListPage extends StatefulWidget {
  const MyBookingListPage({super.key});

  @override
  State<MyBookingListPage> createState() => _MyBookingListPageState();
}

class _MyBookingListPageState extends State<MyBookingListPage> {
  final MyBookingApiService _apiService = MyBookingApiService();

  // Dữ liệu lịch hẹn
  List<Map<String, dynamic>> _allBookings = [];
  bool _isLoading = true;

  // Cấu hình Bộ lọc (Filter State)
  int? _selectedMonth;
  int? _selectedYear;
  String _selectedStatus = 'Tất cả';

  // Danh sách trạng thái dùng cho Filter
  final List<Map<String, String>> _statusOptions = [
    {'key': 'Tất cả', 'label': 'Tất cả'},
    {'key': 'Pending', 'label': 'Chờ xác nhận'},
    {'key': 'Approved', 'label': 'Đã chấp nhận'},
    {'key': 'Assigned', 'label': 'Đã xếp lịch'},
    {'key': 'CheckedIn', 'label': 'Đã Check-in'},
    {'key': 'InProgress', 'label': 'Đang thực hiện'},
    {'key': 'Completed', 'label': 'Đã hoàn thành'},
    {'key': 'Reviewed', 'label': 'Đã xem xét'},
    {'key': 'Repaired', 'label': 'Đã bảo hành'},
    {'key': 'Rejected', 'label': 'Từ chối'},
    {'key': 'Cancelled', 'label': 'Đã hủy'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    try {
      final data = await _apiService.getMyBookings();

      final List<Map<String, dynamic>> validBookings = [];
      for (var item in data) {
        if (item is Map) {
          final safeMap = <String, dynamic>{};
          item.forEach((key, value) {
            safeMap[key.toString()] = value;
          });
          validBookings.add(safeMap);
        }
      }

      // SẮP XẾP: Ưu tiên ngày mới nhất (Tương lai -> Hiện tại -> Quá khứ)
      validBookings.sort((a, b) {
        final dateAStr = a['bookingDate']?.toString() ?? '';
        final dateBStr = b['bookingDate']?.toString() ?? '';

        final dateA =
            DateTime.tryParse(dateAStr) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB =
            DateTime.tryParse(dateBStr) ??
            DateTime.fromMillisecondsSinceEpoch(0);

        return dateB.compareTo(dateA);
      });

      if (!mounted) return;
      setState(() {
        _allBookings = validBookings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('==== LỖI API MY BOOKINGS: $e ====');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải lịch hẹn: $e')));
    }
  }

  // Tự động phân tích các "Năm" có trong Data để tạo Dropdown
  List<int> get _availableYears {
    final years = _allBookings
        .map((b) {
          final dateStr = b['bookingDate']?.toString() ?? '';
          return (DateTime.tryParse(dateStr) ?? DateTime.now()).year;
        })
        .toSet()
        .toList();

    if (years.isEmpty) years.add(DateTime.now().year);
    years.sort((a, b) => b.compareTo(a)); // Năm mới nhất lên trước
    return years;
  }

  // Thuật toán Lọc Danh sách (Filter Logic)
  List<Map<String, dynamic>> get _filteredBookings {
    return _allBookings.where((booking) {
      final dateStr = booking['bookingDate']?.toString() ?? '';
      final date =
          DateTime.tryParse(dateStr) ?? DateTime.fromMillisecondsSinceEpoch(0);

      // Lọc theo Tháng
      if (_selectedMonth != null && date.month != _selectedMonth) return false;

      // Lọc theo Năm
      if (_selectedYear != null && date.year != _selectedYear) return false;

      // Lọc theo Trạng thái
      if (_selectedStatus != 'Tất cả' &&
          booking['status']?.toString() != _selectedStatus) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayedBookings = _filteredBookings;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Lịch hẹn của tôi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilters(), // Khu vực hiển thị bộ lọc
                Expanded(
                  child: displayedBookings.isEmpty
                      ? _buildEmptyState(
                          hasDataButFilteredOut: _allBookings.isNotEmpty,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          physics: const BouncingScrollPhysics(),
                          itemCount: displayedBookings.length,
                          itemBuilder: (context, index) {
                            return _buildBookingCard(displayedBookings[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // ================= UI: BỘ LỌC ================= //
  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Column(
        children: [
          // 1. Lọc theo Tháng & Năm
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    hint: 'Tháng',
                    value: _selectedMonth,
                    items: [null, ...List.generate(12, (i) => i + 1)],
                    itemLabel: (val) =>
                        val == null ? 'Tất cả tháng' : 'Tháng $val',
                    onChanged: (val) => setState(() => _selectedMonth = val),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    hint: 'Năm',
                    value: _selectedYear,
                    items: [null, ..._availableYears],
                    itemLabel: (val) => val == null ? 'Tất cả năm' : 'Năm $val',
                    onChanged: (val) => setState(() => _selectedYear = val),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Lọc theo Trạng Thái (Kéo Ngang)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _statusOptions.map((status) {
                final isSelected = _selectedStatus == status['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      status['label']!,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.grey.shade50,
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade300,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedStatus = status['key']!);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String hint,
    required T? value,
    required List<T?> items,
    required String Function(T?) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 20,
            color: Colors.grey,
          ),
          items: items.map((item) {
            return DropdownMenuItem<T?>(
              value: item,
              child: Text(
                itemLabel(item),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool hasDataButFilteredOut}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            hasDataButFilteredOut
                ? 'Không có kết quả'
                : 'Bạn chưa có lịch hẹn nào',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasDataButFilteredOut
                ? 'Thử thay đổi bộ lọc tháng, năm hoặc trạng thái.'
                : 'Hãy đặt ngay một lịch làm móng để trải nghiệm!',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (!hasDataButFilteredOut)
            ElevatedButton(
              onPressed: () => context.go('/'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Khám phá dịch vụ'),
            ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final dateStr = booking['bookingDate']?.toString() ?? '';
    final bookingDate = DateTime.tryParse(dateStr) ?? DateTime.now();

    final status = bookingStatusView(booking['status']?.toString());
    final rawStatus = booking['status']?.toString();
    final items = booking['bookingItems'] as List<dynamic>? ?? [];
    var nailName = 'Dịch vụ làm móng';

    if (items.isNotEmpty && items.first is Map) {
      final firstItem = items.first as Map;
      final variantName = firstItem['nailVariantName']?.toString().trim() ?? '';
      final customNailName =
          firstItem['customerNailName']?.toString().trim() ?? '';
      final serviceName = firstItem['serviceName']?.toString().trim() ?? '';

      if (variantName.isNotEmpty) {
        nailName = variantName;
      } else if (customNailName.isNotEmpty) {
        nailName = customNailName;
      } else if (serviceName.isNotEmpty) {
        nailName = serviceName;
      }
    }

    String timeStr = booking['startTime']?.toString() ?? '';
    if (timeStr.length >= 5) {
      timeStr = timeStr.substring(0, 5);
    }

    final artistName = booking['artistName']?.toString() ?? 'Bất kỳ';
    final bookingIdStr = booking['bookingId']?.toString() ?? '';
    final canRate = rawStatus == 'Completed' && !bookingIsRated(booking);

    return GestureDetector(
      onTap: () {
        if (bookingIdStr.isNotEmpty) {
          context.push('/my-bookings/detail', extra: bookingIdStr);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lỗi: Lịch hẹn này bị khuyết ID từ hệ thống.'),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      color: status.textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppColors.borderLight),
            ),
            Text(
              nailName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.face_2, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    artistName,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (canRate && bookingIdStr.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/my-bookings/rate', extra: bookingIdStr),
                  icon: const Icon(Icons.star_border, size: 18),
                  label: const Text('Rate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
