import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../generated/l10n.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/signalr_service.dart';
import '../../data/datasources/my_booking_api_service.dart';
import '../utils/booking_status_utils.dart';
import '../widgets/waitlist_tab.dart';
import '../widgets/reschedule_tab.dart';

class MyBookingListPage extends StatefulWidget {
  final int initialTab;
  const MyBookingListPage({super.key, this.initialTab = 0});

  @override
  State<MyBookingListPage> createState() => _MyBookingListPageState();
}

class _MyBookingListPageState extends State<MyBookingListPage>
    with SingleTickerProviderStateMixin {
  static const int _bookingPageSize = 5;

  final MyBookingApiService _apiService = MyBookingApiService();
  final ScrollController _bookingScrollController = ScrollController();

  late TabController _tabController;
  StreamSubscription? _rescheduleSub;

  // Dữ liệu lịch hẹn
  List<Map<String, dynamic>> _allBookings = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  bool _hasNextPage = false;

  // Cấu hình Bộ lọc (Filter State)
  int? _selectedMonth;
  int? _selectedYear;
  String _selectedStatus = 'Tất cả';

  // Danh sách trạng thái dùng cho Filter
  List<Map<String, String>> get _statusOptions => [
    {'key': 'Tất cả', 'label': S.of(context).allStatus},
    {'key': 'Pending', 'label': S.of(context).statusPending},
    {'key': 'Approved', 'label': S.of(context).statusApproved},
    {'key': 'CheckedIn', 'label': S.of(context).statusCheckedIn},
    {'key': 'InProgress', 'label': S.of(context).statusInProgress},
    {'key': 'Completed', 'label': S.of(context).statusCompleted},
    {'key': 'Repaired', 'label': S.of(context).statusRepaired},
    {'key': 'Rejected', 'label': S.of(context).statusRejected},
    {'key': 'Cancelled', 'label': S.of(context).statusCancelled},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );

    _bookingScrollController.addListener(_onBookingScroll);
    _fetchBookings(refresh: true);

    _rescheduleSub = getIt<SignalRService>().onBookingRescheduled.listen((
      event,
    ) {
      debugPrint(
        '[RescheduleTab] ⚡ Nhận sự kiện status=${event.status}, bookingId=${event.bookingId}, message=${event.message}',
      );
      if (mounted) {
        _fetchBookings(refresh: true);
      }
    });
  }

  @override
  void dispose() {
    _rescheduleSub?.cancel();
    _bookingScrollController.removeListener(_onBookingScroll);
    _bookingScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MyBookingListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // GoRouter có thể rebuild widget thay vì recreate khi dùng shell route
    // → Phản hồi khi initialTab thay đổi (ví dụ: sau khi gửi yêu cầu dời lịch)
    if (widget.initialTab != oldWidget.initialTab) {
      _tabController.animateTo(widget.initialTab.clamp(0, 2));
      _fetchBookings(); // Reload lại dữ liệu để hiển thị booking mới
    }
  }

  void _onBookingScroll() {
    if (_tabController.index != 0) return;
    if (_bookingScrollController.position.extentAfter < 400) {
      _loadMoreBookings();
    }
  }

  Future<void> _loadMoreBookings() async {
    if (!_hasNextPage || _isLoadingMore || _isLoading) return;
    await _fetchBookings(refresh: false);
  }

  void _onFilterChanged({
    int? month,
    bool monthChanged = false,
    int? year,
    bool yearChanged = false,
    String? status,
  }) {
    setState(() {
      if (monthChanged) _selectedMonth = month;
      if (yearChanged) _selectedYear = year;
      if (status != null) _selectedStatus = status;
    });
    _fetchBookings(refresh: true);
  }

  DateTime? get _filterStartDate {
    if (_selectedYear == null && _selectedMonth == null) return null;
    final year = _selectedYear ?? DateTime.now().year;
    return DateTime(year, _selectedMonth ?? 1, 1);
  }

  DateTime? get _filterEndDate {
    if (_selectedYear == null && _selectedMonth == null) return null;
    final year = _selectedYear ?? DateTime.now().year;
    final month = _selectedMonth;
    if (month == null) return DateTime(year, 12, 31);
    return DateTime(year, month + 1, 0);
  }

  String? get _serverStatusFilter {
    if (_selectedStatus == 'Tất cả') return null;
    if (_requiresClientSideStatusFilter) return null;
    return _selectedStatus;
  }

  bool get _requiresClientSideStatusFilter {
    return _selectedStatus == 'Completed' ||
        _selectedStatus == 'Assigned' ||
        _selectedStatus == 'Reviewed';
  }

  Future<void> _fetchBookings({bool refresh = true}) async {
    if (refresh) {
      setState(() {
        _allBookings = [];
        _isLoading = true;
        _page = 1;
        _hasNextPage = false;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final shouldLoadAll = refresh && _requiresClientSideStatusFilter;
      final validBookings = <Map<String, dynamic>>[];
      var nextPage = refresh ? 1 : _page + 1;
      var resultPage = _page;
      var hasNextPage = false;

      do {
        final result = await _apiService.getMyBookingsPage(
          pageNumber: nextPage,
          pageSize: _bookingPageSize,
          startDate: _filterStartDate,
          endDate: _filterEndDate,
          status: _serverStatusFilter,
        );

        for (var item in result.items) {
          if (item is Map) {
            final safeMap = <String, dynamic>{};
            item.forEach((key, value) {
              safeMap[key.toString()] = value;
            });
            validBookings.add(safeMap);
          }
        }

        resultPage = result.page;
        hasNextPage = result.hasNextPage;
        nextPage = result.page + 1;
      } while (shouldLoadAll && hasNextPage);

      // SẮP XẾP: Ưu tiên ngày mới nhất
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
        _allBookings = refresh
            ? validBookings
            : [..._allBookings, ...validBookings];
        _page = resultPage;
        _hasNextPage = shouldLoadAll ? false : hasNextPage;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      debugPrint('==== LỖI API MY BOOKINGS: $e ====');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải lịch hẹn: $e')));
    }
  }

  List<int> get _availableYears {
    final years = _allBookings
        .map((b) {
          final dateStr = b['bookingDate']?.toString() ?? '';
          return (DateTime.tryParse(dateStr) ?? DateTime.now()).year;
        })
        .toSet()
        .toList();
    if (years.isEmpty) years.add(DateTime.now().year);
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  List<Map<String, dynamic>> get _rescheduleRelatedBookings {
    return _allBookings.where((booking) {
      final status = booking['status']?.toString();
      return status == 'ReschedulePending' || status == 'RescheduleSuggested';
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredBookings {
    return _allBookings.where((booking) {
      final status = booking['status']?.toString();
      if (status == 'ReschedulePending' || status == 'RescheduleSuggested') {
        return false;
      }
      final dateStr = booking['bookingDate']?.toString() ?? '';
      final date =
          DateTime.tryParse(dateStr) ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (_selectedMonth != null && date.month != _selectedMonth) return false;
      if (_selectedYear != null && date.year != _selectedYear) return false;
      if (_selectedStatus != 'Tất cả') {
        final bStatus = booking['status']?.toString();
        if (_selectedStatus == 'Completed') {
          if (bStatus != 'Completed' && bStatus != 'ServiceCompleted') {
            return false;
          }
        } else {
          if (bStatus != _selectedStatus) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          S.of(context).myBookingsTitle,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
          tabs: [
            Tab(
              iconMargin: const EdgeInsets.only(bottom: 2),
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
              text: S.of(context).bookingTabScheduled,
            ),
            Tab(
              iconMargin: const EdgeInsets.only(bottom: 2),
              icon: const Icon(Icons.notifications_outlined, size: 16),
              text: S.of(context).bookingTabWaitlist,
            ),
            Tab(
              iconMargin: const EdgeInsets.only(bottom: 2),
              icon: const Icon(Icons.edit_calendar_outlined, size: 16),
              text: S.of(context).bookingTabReschedule,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── TAB 1: Lịch đặt ───
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildFilters(),
                    Expanded(
                      child: _filteredBookings.isEmpty
                          ? _buildEmptyState(
                              hasDataButFilteredOut: _allBookings.isNotEmpty,
                            )
                          : ListView.builder(
                              controller: _bookingScrollController,
                              padding: const EdgeInsets.all(20),
                              physics: const BouncingScrollPhysics(),
                              itemCount:
                                  _filteredBookings.length +
                                  (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= _filteredBookings.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                return _buildBookingCard(
                                  _filteredBookings[index],
                                );
                              },
                            ),
                    ),
                  ],
                ),

          // ─── TAB 2: Lịch chờ ───
          WaitlistTab(onRefreshBookings: () => _fetchBookings(refresh: true)),

          // ─── TAB 3: Dời lịch ───
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RescheduleTab(
                  rescheduleBookings: _rescheduleRelatedBookings,
                  onRefreshBookings: () => _fetchBookings(refresh: true),
                  // Sau khi accept/decline thành công → chuyển về tab Lịch đặt
                  onActionSuccess: () {
                    _tabController.animateTo(0);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    hint: S.of(context).monthHint,
                    value: _selectedMonth,
                    items: [null, ...List.generate(12, (i) => i + 1)],
                    itemLabel: (val) => val == null
                        ? S.of(context).allMonths
                        : S.of(context).monthFormat(val),
                    onChanged: (val) =>
                        _onFilterChanged(month: val, monthChanged: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    hint: S.of(context).yearHint,
                    value: _selectedYear,
                    items: [null, ..._availableYears],
                    itemLabel: (val) => val == null
                        ? S.of(context).allYears
                        : S.of(context).yearFormat(val),
                    onChanged: (val) =>
                        _onFilterChanged(year: val, yearChanged: true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                        _onFilterChanged(status: status['key']!);
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
          items: items
              .map(
                (item) => DropdownMenuItem<T?>(
                  value: item,
                  child: Text(
                    itemLabel(item),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required bool hasDataButFilteredOut,
    String? message,
    String? subMessage,
  }) {
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
            message ??
                (hasDataButFilteredOut
                    ? S.of(context).noData
                    : S.of(context).noMatchingFound),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subMessage ??
                (hasDataButFilteredOut
                    ? S.of(context).tryChangeFilter
                    : S.of(context).bookNowHint),
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (!hasDataButFilteredOut && message == null)
            ElevatedButton(
              onPressed: () => context.go('/'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(S.of(context).exploreServices),
            ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final dateStr = booking['bookingDate']?.toString() ?? '';
    final bookingDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    final status = bookingStatusView(booking['status']?.toString(), context);
    final rawStatus = booking['status']?.toString();
    final items = booking['bookingItems'] as List<dynamic>? ?? [];
    var nailName = S.of(context).nailServiceDefault;

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
    if (timeStr.length >= 5) timeStr = timeStr.substring(0, 5);

    final artistName =
        booking['artistName']?.toString() ?? S.of(context).anyArtist;
    final bookingIdStr = booking['bookingId']?.toString() ?? '';
    final canRate =
        (rawStatus == 'Completed' && booking['isRated'] == false);

    return GestureDetector(
      onTap: () {
        if (bookingIdStr.isNotEmpty) {
          context.push('/my-bookings/detail', extra: bookingIdStr);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).bookingMissingId)),
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: status.textColor.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(status.icon, color: status.textColor, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        status.label,
                        style: TextStyle(
                          color: status.textColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
                  label: const Text('Đánh giá'),
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
            // Check & render Warranty button
            if (rawStatus == 'Completed' &&
                bookingIdStr.isNotEmpty &&
                !_readBool(
                  booking['isWarrantied'] ?? booking['IsWarrantied'],
                ) &&
                !_hasWarranty(bookingIdStr)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleWarrantyAction(booking),
                    icon: const Icon(Icons.shield_outlined, size: 18),
                    label: Text(S.of(context).warrantyButton),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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

  bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase().trim();
    return text == 'true' || text == '1' || text == 'yes';
  }

  bool _hasWarranty(String bookingId) {
    if (bookingId.isEmpty) return false;
    return _allBookings.any(
      (b) => b['warrantyForBookingId']?.toString() == bookingId,
    );
  }

  void _handleWarrantyAction(Map<String, dynamic> booking) {
    final items = booking['bookingItems'] as List<dynamic>? ?? [];
    int? nailVariantId;
    int? shapeMethodConfigId;
    String? shapeMethodName;
    final extraServiceIds = <String>[];

    // Build booking items cho API chính xác
    final List<Map<String, dynamic>> bookingItemsForApi = items.map((item) {
      final map = <String, dynamic>{};
      if (item is Map) {
        if (item['nailVariantId'] != null) {
          final idVal = int.tryParse(item['nailVariantId'].toString());
          if (idVal != null && idVal > 0) {
            nailVariantId = idVal;
            map['nailVariantId'] = idVal;
          }
        }
        map['nailVariantName'] = item['nailVariantName']?.toString();

        if (item['serviceId'] != null) {
          final sId = item['serviceId'].toString();
          extraServiceIds.add(sId);
          map['serviceId'] = sId;
        }
        map['serviceName'] = item['serviceName']?.toString();

        final shapeConfigVal =
            item['shapeMethodConfigId'] ?? item['ShapeMethodConfigId'];
        if (shapeConfigVal != null) {
          final configId = int.tryParse(shapeConfigVal.toString());
          shapeMethodConfigId = configId;
          map['shapeMethodConfigId'] = configId;
        }
        shapeMethodName = item['shapeMethodName']?.toString();
        map['shapeMethodName'] = shapeMethodName;

        if (item['customerNailId'] != null) {
          map['customerNailId'] = int.tryParse(
            item['customerNailId'].toString(),
          );
        }
        map['customerNailName'] = item['customerNailName']?.toString();

        if (item['customerNailRequestId'] != null) {
          map['customerNailRequestId'] = item['customerNailRequestId']
              .toString();
        }
        map['quantity'] =
            int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
        map['price'] = item['price'] ?? item['basePrice'] ?? 0;
      }
      return map;
    }).toList();

    var displayName = S.of(context).warrantyServiceDefault;
    if (items.isNotEmpty && items.first is Map) {
      final firstItem = items.first as Map;
      final variantName = firstItem['nailVariantName']?.toString().trim() ?? '';
      final customNailName =
          firstItem['customerNailName']?.toString().trim() ?? '';
      final serviceName = firstItem['serviceName']?.toString().trim() ?? '';
      if (variantName.isNotEmpty) {
        displayName = variantName;
      } else if (customNailName.isNotEmpty) {
        displayName = customNailName;
      } else if (serviceName.isNotEmpty) {
        displayName = serviceName;
      }
    }

    final bookingIdStr = booking['bookingId']?.toString() ?? '';
    final salonId = booking['salonId']?.toString() ?? '';

    final nailData = {
      'id': nailVariantId ?? 0,
      'name': '${S.of(context).warrantyPrefix}: $displayName',
      'price': 0, // Bảo hành miễn phí
      'shapeMethodConfigId': shapeMethodConfigId,
      'shapeMethodPrice': 0.0, // Bảo hành tạo form miễn phí
      'shapeMethodName': shapeMethodName,
      'warrantyForBookingId': bookingIdStr,
      'salonId': salonId,
      'extraServiceIds': extraServiceIds,
      'warrantyBookingItems':
          bookingItemsForApi, // Truyền chuẩn mảng bookingItems cũ
    };

    context.push('/nail-booking', extra: nailData);
  }
}
