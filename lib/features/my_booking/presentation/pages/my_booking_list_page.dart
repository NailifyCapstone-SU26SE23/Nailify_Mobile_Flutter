import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/datasources/my_booking_api_service.dart';
import '../widgets/booking_card_widget.dart';
import '../widgets/booking_filter_section.dart';

class MyBookingListPage extends StatefulWidget {
  const MyBookingListPage({super.key});

  @override
  State<MyBookingListPage> createState() => _MyBookingListPageState();
}

class _MyBookingListPageState extends State<MyBookingListPage> {
  final MyBookingApiService _apiService = MyBookingApiService();

  List<Map<String, dynamic>> _allBookings = [];
  List<Map<String, dynamic>> _myRatings = [];
  bool _isLoading = true;

  int? _selectedMonth;
  int? _selectedYear;
  String _selectedStatus = 'Tất cả';

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
      final Future<List<dynamic>> bookingsFuture = _apiService.getMyBookings();
      final Future<List<dynamic>> ratingsFuture = _apiService.getMyRatings();

      final results = await Future.wait([bookingsFuture, ratingsFuture]);
      final bookingsData = results[0];
      final ratingsData = results[1];

      final List<Map<String, dynamic>> validBookings = [];
      for (var item in bookingsData) {
        if (item is Map) {
          final safeMap = <String, dynamic>{};
          item.forEach((key, value) {
            safeMap[key.toString()] = value;
          });
          validBookings.add(safeMap);
        }
      }

      final List<Map<String, dynamic>> validRatings = [];
      for (var item in ratingsData) {
        if (item is Map) {
          final safeMap = <String, dynamic>{};
          item.forEach((key, value) {
            safeMap[key.toString()] = value;
          });
          validRatings.add(safeMap);
        }
      }

      // Sort bookings by date descending
      validBookings.sort((a, b) {
        final dateAStr = a['bookingDate']?.toString() ?? '';
        final dateBStr = b['bookingDate']?.toString() ?? '';
        final dateA = DateTime.tryParse(dateAStr) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(dateBStr) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      if (!mounted) return;
      setState(() {
        _allBookings = validBookings;
        _myRatings = validRatings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải lịch hẹn: $e')),
      );
    }
  }

  List<int> get _availableYears {
    final years = _allBookings.map((b) {
      final dateStr = b['bookingDate']?.toString() ?? '';
      return (DateTime.tryParse(dateStr) ?? DateTime.now()).year;
    }).toSet().toList();

    if (years.isEmpty) years.add(DateTime.now().year);
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  List<Map<String, dynamic>> get _filteredBookings {
    return _allBookings.where((booking) {
      final dateStr = booking['bookingDate']?.toString() ?? '';
      final date = DateTime.tryParse(dateStr) ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (_selectedMonth != null && date.month != _selectedMonth) return false;
      if (_selectedYear != null && date.year != _selectedYear) return false;
      if (_selectedStatus != 'Tất cả' && booking['status']?.toString() != _selectedStatus) return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayedBookings = _filteredBookings;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        title: const Text(
          'Lịch hẹn của tôi',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
            color: AppColors.primaryDark,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFDFBF7),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                BookingFilterSection(
                  selectedMonth: _selectedMonth,
                  selectedYear: _selectedYear,
                  selectedStatus: _selectedStatus,
                  availableYears: _availableYears,
                  statusOptions: _statusOptions,
                  onMonthChanged: (val) => setState(() => _selectedMonth = val),
                  onYearChanged: (val) => setState(() => _selectedYear = val),
                  onStatusChanged: (val) => setState(() => _selectedStatus = val),
                ),
                Expanded(
                  child: displayedBookings.isEmpty
                      ? _buildEmptyState(hasDataButFilteredOut: _allBookings.isNotEmpty)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: displayedBookings.length,
                          itemBuilder: (context, index) {
                            final booking = displayedBookings[index];
                            final bookingIdStr = booking['bookingId']?.toString() ?? '';
                            
                            // Find rating for this booking
                            final rating = _myRatings.firstWhere(
                              (r) => r['bookingId']?.toString().toLowerCase() == bookingIdStr.toLowerCase(),
                              orElse: () => <String, dynamic>{},
                            );

                            return BookingCardWidget(
                              booking: booking,
                              rating: rating,
                              onTap: () {
                                if (bookingIdStr.isNotEmpty) {
                                  context.push('/my-bookings/detail', extra: bookingIdStr);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Lỗi: Lịch hẹn không có ID hợp lệ.')),
                                  );
                                }
                              },
                              onRatePressed: () async {
                                final result = await context.push<dynamic>(
                                  '/my-bookings/rate',
                                  extra: bookingIdStr,
                                );
                                if (result == true) {
                                  // Refresh the bookings list on successful submit or update
                                  _fetchBookings();
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState({required bool hasDataButFilteredOut}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 18),
            Text(
              hasDataButFilteredOut ? 'Không có kết quả' : 'Chưa có lịch hẹn nào',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
                fontFamily: 'Georgia',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasDataButFilteredOut
                  ? 'Vui lòng thay đổi các bộ lọc ở trên.'
                  : 'Đặt một lịch hẹn làm móng ngay hôm nay để có bộ móng ưng ý nhất!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            if (!hasDataButFilteredOut)
              ElevatedButton(
                onPressed: () => context.go('/'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Khám phá ngay', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}
