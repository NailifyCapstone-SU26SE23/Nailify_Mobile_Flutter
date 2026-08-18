import 'dart:async';
import 'package:flutter/material.dart';

class GlobalBookingManager extends ChangeNotifier {
  static final GlobalBookingManager instance = GlobalBookingManager._internal();
  GlobalBookingManager._internal();

  // Shared Hold Slot State
  String? holdToken;
  Timer? _holdTimer;
  int holdRemainingSeconds = 0;
  bool isHolding = false;

  // Callback when hold expires
  VoidCallback? onHoldExpired;

  // Active booking type: 'service', 'nail', 'custom'
  String? activeBookingType;

  // --------------------------------------------------
  // 1. Service Booking State (from NailBookingCubit)
  // --------------------------------------------------
  Map<String, dynamic>? serviceBranch;
  List<String?> serviceExtraServices = [];
  DateTime? serviceDate;
  Map<String, dynamic>? serviceStylist;
  String? serviceTime;
  List<dynamic> servicePromotions = [];
  bool serviceNoArtistSelected = false;
  Map<String, dynamic>? serviceBaseService;

  // --------------------------------------------------
  // 2. Nail Booking State (from NailBookingPage)
  // --------------------------------------------------
  Map<String, dynamic>? nailBranch;
  List<String?> nailExtraServices = [];
  DateTime? nailDate;
  Map<String, dynamic>? nailStylist;
  String? nailTime;
  int? nailSelectedPromotionId;
  bool nailNoArtistSelected = false;
  Map<String, dynamic>? nailData;

  // --------------------------------------------------
  // 3. Custom Nail Booking State (from CustomNailBookingPage)
  // --------------------------------------------------
  Map<String, dynamic>? customBranch;
  DateTime? customDate;
  String? customTime;
  List<String?> customExtraServices = [];
  dynamic customSelectedShapeMethod; // ShapeMethodConfigModel?
  List<dynamic> customSelectedPromotions = []; // PromotionModel
  dynamic customNail; // CustomerNailModel

  // Helper to start the global timer
  void startHoldTimer(
    String token,
    int initialSeconds, {
    required String bookingType,
    required VoidCallback onExpired,
  }) {
    _holdTimer?.cancel();
    holdToken = token;
    holdRemainingSeconds = initialSeconds;
    isHolding = true;
    activeBookingType = bookingType;
    onHoldExpired = onExpired;
    notifyListeners();

    _holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (holdRemainingSeconds <= 1) {
        timer.cancel();
        clearHold();
        if (onHoldExpired != null) {
          onHoldExpired!();
        }
      } else {
        holdRemainingSeconds--;
        notifyListeners();
      }
    });
  }

  void cancelHold(Future<void> Function(String) apiCancelCall) {
    _holdTimer?.cancel();
    _holdTimer = null;
    final token = holdToken;
    if (token != null) {
      apiCancelCall(token);
    }
    clearHold();
  }

  void clearHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    holdToken = null;
    isHolding = false;
    holdRemainingSeconds = 0;
    notifyListeners();
  }

  void clearAllBookingState() {
    clearHold();
    activeBookingType = null;

    // Clear Service state
    serviceBranch = null;
    serviceExtraServices = [];
    serviceDate = null;
    serviceStylist = null;
    serviceTime = null;
    servicePromotions = [];
    serviceNoArtistSelected = false;
    serviceBaseService = null;

    // Clear Nail state
    nailBranch = null;
    nailExtraServices = [];
    nailDate = null;
    nailStylist = null;
    nailTime = null;
    nailSelectedPromotionId = null;
    nailNoArtistSelected = false;
    nailData = null;

    // Clear Custom state
    customBranch = null;
    customDate = null;
    customTime = null;
    customExtraServices = [];
    customSelectedShapeMethod = null;
    customSelectedPromotions = [];
    customNail = null;
  }
}
