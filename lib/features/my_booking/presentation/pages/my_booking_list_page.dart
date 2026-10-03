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
import '../widgets/reschedule_booking_dialog.dart';

class MyBookingListPage extends StatefulWidget {
  final int initialTab;
  final String? targetBookingId;
  const MyBookingListPage({
    super.key,
    this.initialTab = 0,
    this.targetBookingId,
  });

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
  StreamSubscription? _confirmedSub;
  StreamSubscription? _rejectedSub;
  StreamSubscription? _cancelledSub;
  StreamSubscription? _artistReassignedSub;

  // Dữ liệu lịch hẹn
  List<Map<String, dynamic>> _allBookings = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  bool _hasNextPage = false;

  // Cấu hình Bộ lọc (Filter State)
  DateTime? _selectedDate;
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

  String? _highlightedBookingId;
  final Map<String, GlobalKey> _bookingCardKeys = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );

    _bookingScrollController.addListener(_onBookingScroll);
    _fetchBookings(refresh: true).then((_) {
      if (widget.targetBookingId != null &&
          widget.targetBookingId!.isNotEmpty) {
        _scrollToBooking(widget.targetBookingId!);
      }
    });

    final signalR = getIt<SignalRService>();
    _rescheduleSub = signalR.onBookingRescheduled.listen((event) {
      debugPrint(
        '[MyBookingListPage] ⚡ Nhận sự kiện Rescheduled: ${event.message}',
      );
      if (mounted) _fetchBookings(refresh: true);
    });

    _confirmedSub = signalR.onBookingConfirmed.listen((event) {
      debugPrint(
        '[MyBookingListPage] ⚡ Nhận sự kiện BookingConfirmed: ${event.message}',
      );
      if (mounted) _fetchBookings(refresh: true);
    });

    _rejectedSub = signalR.onBookingRejected.listen((event) {
      debugPrint(
        '[MyBookingListPage] ⚡ Nhận sự kiện BookingRejected: ${event.message}',
      );
      if (mounted) _fetchBookings(refresh: true);
    });

    _cancelledSub = signalR.onBookingCancelled.listen((event) {
      debugPrint(
        '[MyBookingListPage] ⚡ Nhận sự kiện BookingCancelled: ${event.message}',
      );
      if (mounted) _fetchBookings(refresh: true);
    });

    _artistReassignedSub = signalR.onArtistReassigned.listen((event) {
      debugPrint(
        '[MyBookingListPage] ⚡ Nhận sự kiện ArtistReassigned: ${event.message}',
      );
      if (mounted) _fetchBookings(refresh: true);
    });
  }

  @override
  void dispose() {
    _rescheduleSub?.cancel();
    _confirmedSub?.cancel();
    _rejectedSub?.cancel();
    _cancelledSub?.cancel();
    _artistReassignedSub?.cancel();
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
    if (widget.targetBookingId != null &&
        widget.targetBookingId != oldWidget.targetBookingId) {
      _fetchBookings(refresh: true).then((_) {
        _scrollToBooking(widget.targetBookingId!);
      });
    }
  }

  Future<void> _scrollToBooking(String targetBookingId) async {
    if (!mounted || targetBookingId.isEmpty) return;

    setState(() {
      _highlightedBookingId = targetBookingId;
    });

    Timer(const Duration(seconds: 3), () {
      if (mounted && _highlightedBookingId == targetBookingId) {
        setState(() {
          _highlightedBookingId = null;
        });
      }
    });

    if (_tabController.index != 0) {
      _tabController.animateTo(0);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Kiểm tra xem booking có bị ẩn bởi filter hiện tại không
    final isInFiltered = _filteredBookings.any((b) {
      final id = (b['bookingId'] ?? b['id'] ?? b['booking_id'])?.toString();
      return id == targetBookingId;
    });

    if (!isInFiltered && _allBookings.isNotEmpty) {
      setState(() {
        _selectedStatus = 'Tất cả';
        _selectedDate = null;
      });
    }

    final targetIndex = _filteredBookings.indexWhere((b) {
      final id = (b['bookingId'] ?? b['id'] ?? b['booking_id'])?.toString();
      return id == targetBookingId;
    });

    if (targetIndex == -1) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final key = _bookingCardKeys[targetBookingId];
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        alignment: 0.15,
      );
    } else if (_bookingScrollController.hasClients) {
      final targetOffset = (targetIndex * 280.0).clamp(
        0.0,
        _bookingScrollController.position.maxScrollExtent,
      );
      await _bookingScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      final mountedKey = _bookingCardKeys[targetBookingId];
      if (mountedKey?.currentContext != null) {
        await Scrollable.ensureVisible(
          mountedKey!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          alignment: 0.15,
        );
      }
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
    DateTime? date,
    bool dateChanged = false,
    String? status,
  }) {
    setState(() {
      if (dateChanged) _selectedDate = date;
      if (status != null) _selectedStatus = status;
    });
    _fetchBookings(refresh: true);
  }

  DateTime? get _filterStartDate {
    if (_selectedDate == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      0,
      0,
      0,
    );
  }

  DateTime? get _filterEndDate {
    if (_selectedDate == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      23,
      59,
      59,
    );
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
      final shouldLoadAll = refresh;
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

  List<Map<String, dynamic>> get _rescheduleRelatedBookings {
    return _allBookings.where((booking) {
      final status = booking['status']?.toString() ?? '';
      return status == 'ReschedulePending' ||
          status == 'RescheduleSuggested' ||
          status == 'RescheduleApproved' ||
          status == 'RescheduleRejected' ||
          status.startsWith('Reschedule');
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredBookings {
    return _allBookings.where((booking) {
      final status = booking['status']?.toString() ?? '';
      if (status == 'ReschedulePending' ||
          status == 'RescheduleSuggested' ||
          status == 'RescheduleApproved' ||
          status == 'RescheduleRejected' ||
          status.startsWith('Reschedule')) {
        return false;
      }
      final dateStr = booking['bookingDate']?.toString() ?? '';
      final date =
          DateTime.tryParse(dateStr) ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (_selectedDate != null) {
        if (date.year != _selectedDate!.year ||
            date.month != _selectedDate!.month ||
            date.day != _selectedDate!.day) {
          return false;
        }
      }
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
            child: _buildDateFilter(),
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

  Widget _buildDateFilter() {
    final hasDate = _selectedDate != null;
    final dateText = hasDate
        ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
        : S.of(context).selectDate;

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  onSurface: AppColors.textPrimary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          _onFilterChanged(date: picked, dateChanged: true);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(
            color: hasDate ? AppColors.primary : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: hasDate ? AppColors.primary : Colors.grey.shade600,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                dateText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: hasDate ? FontWeight.bold : FontWeight.w500,
                  color: hasDate ? AppColors.primary : Colors.grey.shade700,
                ),
              ),
            ),
            if (hasDate)
              GestureDetector(
                onTap: () {
                  _onFilterChanged(date: null, dateChanged: true);
                },
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.cancel,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                ),
              )
            else
              Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
          ],
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
          // Text(
          //   message ??
          //       (hasDataButFilteredOut
          //           ? S.of(context).noData
          //           : S.of(context).noMatchingFound),
          //   style: const TextStyle(
          //     fontSize: 18,
          //     fontWeight: FontWeight.bold,
          //     color: AppColors.textPrimary,
          //   ),
          // ),
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
    final dateStr =
        (booking['bookingDate'] ?? booking['BookingDate'])?.toString() ?? '';
    final bookingDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    final status = bookingStatusView(
      (booking['status'] ?? booking['Status'])?.toString(),
      context,
    );
    final rawStatus = (booking['status'] ?? booking['Status'])?.toString();
    final bookingIdStr =
        (booking['bookingId'] ?? booking['BookingId'])?.toString() ?? '';

    final parsedItems = _parseBookingItems(booking);

    String timeStr =
        (booking['startTime'] ?? booking['StartTime'])?.toString() ?? '';
    if (timeStr.length >= 5) timeStr = timeStr.substring(0, 5);

    final artistName =
        (booking['artistName'] ??
                booking['ArtistName'] ??
                booking['nailArtistName'] ??
                booking['NailArtistName'])
            ?.toString() ??
        S.of(context).anyArtist;

    final canRate =
        (rawStatus == 'Completed' &&
        (booking['isRated'] ?? booking['IsRated']) == false);
    final canReschedule = rawStatus == 'Approved' && bookingIdStr.isNotEmpty;

    final warrantyForBookingId =
        (booking['warrantyForBookingId'] ?? booking['WarrantyForBookingId'])
            ?.toString();
    final isWarrantyBooking =
        warrantyForBookingId != null && warrantyForBookingId.isNotEmpty;
    final hasWarrantyRequested =
        _readBool(booking['isWarrantied'] ?? booking['IsWarrantied']) ||
        _hasWarranty(bookingIdStr);

    final isHighlighted = _highlightedBookingId == bookingIdStr;
    final cardKey = _bookingCardKeys.putIfAbsent(
      bookingIdStr,
      () => GlobalKey(),
    );

    return GestureDetector(
      key: cardKey,
      onTap: () async {
        if (bookingIdStr.isNotEmpty) {
          final res = await context.push(
            '/my-bookings/detail',
            extra: bookingIdStr,
          );
          if (res != null && mounted) {
            final shouldReload =
                res == true || (res is Map && res['reload'] == true);
            if (shouldReload) {
              final targetId = (res is Map && res['bookingId'] != null)
                  ? res['bookingId'].toString()
                  : bookingIdStr;
              await _fetchBookings(refresh: true);
              _scrollToBooking(targetId);
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).bookingMissingId)),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isHighlighted ? const Color(0xFFFFF5F8) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighlighted ? AppColors.primary : AppColors.borderLight,
            width: isHighlighted ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isHighlighted
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isHighlighted ? 16 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badges & Booking Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                    if (isWarrantyBooking) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          'Đơn bảo hành',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else if (hasWarrantyRequested) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Text(
                          'Đã bảo hành',
                          style: TextStyle(
                            color: Colors.teal.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: AppColors.borderLight),
            ),

            // Booked Services List breakdown
            _buildBookedServicesWidget(parsedItems),

            const SizedBox(height: 12),

            // Time & Stylist bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_filled,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 1,
                    height: 12,
                    color: Colors.grey.shade300,
                  ),
                  Icon(
                    Icons.face_2_outlined,
                    size: 15,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      artistName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            if (canReschedule) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openRescheduleDialog(booking),
                  icon: const Icon(
                    Icons.edit_calendar_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    S.of(context).bookingRescheduleBtnLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
            if (canRate && bookingIdStr.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final res = await context.push(
                      '/my-bookings/rate',
                      extra: bookingIdStr,
                    );
                    if (res != null && mounted) {
                      final targetId = (res is Map && res['bookingId'] != null)
                          ? res['bookingId'].toString()
                          : bookingIdStr;
                      await _fetchBookings(refresh: true);
                      _scrollToBooking(targetId);
                    }
                  },
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
            // Check & render Warranty button (Chỉ hiển thị với đơn có mẫu nail)
            if (rawStatus == 'Completed' &&
                bookingIdStr.isNotEmpty &&
                !_readBool(
                  booking['isWarrantied'] ?? booking['IsWarrantied'],
                ) &&
                !_hasWarranty(bookingIdStr) &&
                _hasNailDesign(booking)) ...[
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

  List<_BookingItemDisplay> _parseBookingItems(Map<String, dynamic> booking) {
    final rawItems =
        booking['bookingItems'] ??
        booking['BookingItems'] ??
        booking['items'] ??
        booking['Items'];
    final items = rawItems is List ? rawItems : <dynamic>[];
    final result = <_BookingItemDisplay>[];

    for (final item in items) {
      if (item is Map) {
        final variantName =
            (item['nailVariantName'] ?? item['NailVariantName'])
                ?.toString()
                .trim() ??
            '';
        final customNailName =
            (item['customerNailName'] ?? item['CustomerNailName'])
                ?.toString()
                .trim() ??
            '';
        final serviceName =
            (item['serviceName'] ?? item['ServiceName'])?.toString().trim() ??
            '';
        final shapeName = (item['shapeMethodName'] ?? item['ShapeMethodName'])
            ?.toString()
            .trim();
        final qtyRaw = item['quantity'] ?? item['Quantity'] ?? 1;
        final qty = (qtyRaw is num)
            ? qtyRaw.toInt()
            : (int.tryParse(qtyRaw.toString()) ?? 1);

        String name = '';
        bool isNailDesign = false;

        if (variantName.isNotEmpty) {
          name = variantName;
          isNailDesign = true;
        } else if (customNailName.isNotEmpty) {
          name = customNailName;
          isNailDesign = true;
        } else if (serviceName.isNotEmpty) {
          name = serviceName;
        }

        if (name.isNotEmpty) {
          result.add(
            _BookingItemDisplay(
              name: name,
              shapeName: (shapeName != null && shapeName.isNotEmpty)
                  ? shapeName
                  : null,
              quantity: qty,
              isNailDesign: isNailDesign,
            ),
          );
        }
      }
    }
    return result;
  }

  Widget _buildBookedServicesWidget(List<_BookingItemDisplay> items) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCE3EC)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              S.of(context).nailServiceDefault,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCE3EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Dịch vụ đã đặt (${items.length})',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: idx == items.length - 1 ? 0 : 6),
              child: Row(
                children: [
                  Icon(
                    item.isNailDesign
                        ? Icons.brush_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 14,
                    color: item.isNailDesign
                        ? AppColors.primary
                        : Colors.teal.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: item.isNailDesign
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.shapeName != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.shapeName!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B21A8),
                        ),
                      ),
                    ),
                  ],
                  if (item.quantity > 1) ...[
                    const SizedBox(width: 6),
                    Text(
                      'x${item.quantity}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _openRescheduleDialog(Map<String, dynamic> booking) {
    final bookingIdStr = booking['bookingId']?.toString() ?? '';
    final salonId = booking['salonId']?.toString() ?? '';
    RescheduleBookingDialog.show(
      context: context,
      bookingId: bookingIdStr,
      salonId: salonId,
      bookingData: booking,
      onConfirm: (newDate, newTime, reason) async {
        try {
          final success = await _apiService.requestRescheduleBooking(
            bookingIdStr,
            newDate: newDate,
            newTime: newTime,
            reason: reason,
          );
          if (!context.mounted) return false;
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(S.of(context).bookingRescheduleSuccess),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
            _fetchBookings(refresh: true);
            _tabController.animateTo(2);
            return true;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(S.of(context).bookingRescheduleFail),
                backgroundColor: Colors.red,
              ),
            );
            return false;
          }
        } catch (e) {
          if (!context.mounted) return false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
      },
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

  bool _hasNailDesign(Map<String, dynamic> booking) {
    final items = booking['bookingItems'] as List<dynamic>? ?? [];
    for (final item in items) {
      if (item is Map) {
        final nailVariantId = item['nailVariantId'] ?? item['NailVariantId'];
        final nailVariantName =
            item['nailVariantName'] ?? item['NailVariantName'];
        final customerNailId = item['customerNailId'] ?? item['CustomerNailId'];
        final customerNailName =
            item['customerNailName'] ?? item['CustomerNailName'];
        final customerNailRequestId =
            item['customerNailRequestId'] ?? item['CustomerNailRequestId'];

        if (nailVariantId != null &&
            int.tryParse(nailVariantId.toString()) != null &&
            int.tryParse(nailVariantId.toString())! > 0) {
          return true;
        }
        if (nailVariantName != null &&
            nailVariantName.toString().trim().isNotEmpty) {
          return true;
        }
        if (customerNailId != null &&
            customerNailId.toString().trim().isNotEmpty) {
          return true;
        }
        if (customerNailName != null &&
            customerNailName.toString().trim().isNotEmpty) {
          return true;
        }
        if (customerNailRequestId != null &&
            customerNailRequestId.toString().trim().isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  void _handleWarrantyAction(Map<String, dynamic> booking) {
    final rawItems =
        booking['bookingItems'] ??
        booking['BookingItems'] ??
        booking['items'] ??
        booking['Items'];
    final items = rawItems is List ? rawItems : <dynamic>[];

    // ── Guard: thời hạn bảo hành tối đa 7 ngày từ ngày hoàn thành ──
    // Check sớm ngay tại list page để hiện popup ngay, không nhảy qua
    // page trung gian (như trước đây vẫn navigate sang warranty page
    // khoảng 2s rồi mới hiện thông báo).
    final bookingIdStr =
        (booking['bookingId'] ?? booking['BookingId'])?.toString() ?? '';
    final salonId =
        (booking['salonId'] ?? booking['SalonId'])?.toString() ?? '';
    final dateStr =
        (booking['bookingDate'] ?? booking['BookingDate'])?.toString() ?? '';
    final sourceBookingDate = DateTime.tryParse(dateStr);
    if (sourceBookingDate != null &&
        DateTime.now().difference(sourceBookingDate) >
            const Duration(days: 7)) {
      _showWarrantyExpiredDialog();
      return;
    }

    // Build booking items cho API chính xác — ép kiểu tất cả field cần thiết.
    final List<Map<String, dynamic>> bookingItemsForApi = items.map((item) {
      final map = <String, dynamic>{};
      if (item is Map) {
        final nailVariantIdRaw =
            (item['nailVariantId'] ?? item['NailVariantId'])?.toString();
        if (nailVariantIdRaw != null &&
            int.tryParse(nailVariantIdRaw) != null &&
            int.tryParse(nailVariantIdRaw)! > 0) {
          map['nailVariantId'] = int.parse(nailVariantIdRaw);
        }
        map['nailVariantName'] =
            (item['nailVariantName'] ?? item['NailVariantName'])?.toString();

        final serviceId = (item['serviceId'] ?? item['ServiceId'])?.toString();
        if (serviceId != null && serviceId.isNotEmpty) {
          map['serviceId'] = serviceId;
        }
        map['serviceName'] = (item['serviceName'] ?? item['ServiceName'])
            ?.toString();

        final shapeConfigVal =
            item['shapeMethodConfigId'] ?? item['ShapeMethodConfigId'];
        if (shapeConfigVal != null) {
          final configId = int.tryParse(shapeConfigVal.toString());
          if (configId != null && configId > 0) {
            map['shapeMethodConfigId'] = configId;
          }
        }
        map['shapeMethodName'] =
            (item['shapeMethodName'] ?? item['ShapeMethodName'])?.toString();

        final customerNailIdRaw =
            (item['customerNailId'] ?? item['CustomerNailId'])?.toString();
        if (customerNailIdRaw != null && customerNailIdRaw.isNotEmpty) {
          final parsed = int.tryParse(customerNailIdRaw);
          if (parsed != null) {
            map['customerNailId'] = parsed;
          }
        }
        map['customerNailName'] =
            (item['customerNailName'] ?? item['CustomerNailName'])?.toString();

        final customerNailRequestId =
            (item['customerNailRequestId'] ?? item['CustomerNailRequestId'])
                ?.toString();
        if (customerNailRequestId != null && customerNailRequestId.isNotEmpty) {
          map['customerNailRequestId'] = customerNailRequestId;
        }
        final qtyRaw = item['quantity'] ?? item['Quantity'];
        map['quantity'] = int.tryParse(qtyRaw?.toString() ?? '1') ?? 1;
        map['price'] = item['price'] ?? item['Price'] ?? item['basePrice'] ?? 0;
      }
      return map;
    }).toList();

    // Resolve nailArtistId từ response. Cấu trúc response có thể là:
    //  - Flat:    booking['nailArtistId']
    //  - Nested:  booking['nailArtist']['nailArtistId']
    //  - Nested alt: booking['artist']['nailArtistId']
    // Nếu không resolve được → truyền rỗng, user sẽ chọn lại artist.
    String nailArtistId = '';
    final flatArtistId = booking['nailArtistId']?.toString();
    if (flatArtistId != null && flatArtistId.trim().isNotEmpty) {
      nailArtistId = flatArtistId.trim();
    } else {
      for (final key in const ['nailArtist', 'artist']) {
        final nested = booking[key];
        if (nested is Map) {
          final id =
              nested['nailArtistId']?.toString() ??
              nested['id']?.toString() ??
              '';
          if (id.trim().isNotEmpty) {
            nailArtistId = id.trim();
            break;
          }
        }
      }
    }

    // Build payload mới cho WarrantyBookingPage — flow riêng, KHÔNG dùng
    // lại NailBookingPage. Salon, thợ cũ (nếu resolve được) được truyền
    // để page pre-select + pin lên đầu. Booking items từ booking gốc
    // được truyền để page render danh sách bảo hành.
    Map<String, dynamic>? sourceStylist;
    for (final key in const ['nailArtist', 'artist']) {
      final nested = booking[key];
      if (nested is Map) {
        sourceStylist = Map<String, dynamic>.from(nested);
        break;
      }
    }
    if (sourceStylist != null) {
      sourceStylist['nailArtistId'] ??= nailArtistId;
      final existingName = sourceStylist['fullName']?.toString() ?? '';
      if (existingName.isEmpty) {
        sourceStylist['fullName'] = booking['artistName']?.toString() ?? '';
      }
    }

    final warrantyData = {
      'sourceBookingId': bookingIdStr,
      'salonId': salonId,
      'salonName': booking['salonName']?.toString() ?? '',
      'salonAddress': booking['salonAddress']?.toString() ?? '',
      'sourceArtistId': nailArtistId,
      'sourceArtistName': booking['artistName']?.toString() ?? '',
      'sourceStylist': sourceStylist,
      'noArtistSelected': nailArtistId.isEmpty,
      'bookingItems': bookingItemsForApi,
      if (sourceBookingDate != null)
        'sourceBookingDate': sourceBookingDate.toIso8601String(),
    };

    if (!mounted) return;
    context.push('/warranty-booking', extra: warrantyData);
  }

  /// Hiện popup "Đã quá hạn bảo hành" ngay tại list page, không
  /// navigate sang trang trung gian. Được gọi khi `DateTime.now()` trừ
  /// đi `sourceBookingDate` > 7 ngày.
  void _showWarrantyExpiredDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.access_time_filled_rounded,
                size: 40,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context).warrantyExpiredTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              S.of(context).warrantyExpiredDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: Text(
              S.of(context).warrantyExpiredBackBtn,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingItemDisplay {
  final String name;
  final String? shapeName;
  final int quantity;
  final bool isNailDesign;

  _BookingItemDisplay({
    required this.name,
    this.shapeName,
    required this.quantity,
    required this.isNailDesign,
  });
}
