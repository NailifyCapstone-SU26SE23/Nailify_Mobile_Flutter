import 'package:equatable/equatable.dart';

/// Thực thể nghiệp vụ thuần túy đại diện cho một lịch hẹn đặt móng.
class BookingEntity extends Equatable {
  final String bookingId;
  final String salonId;
  final String salonName;
  final DateTime bookingDate;
  final String startTime;
  final String? nailArtistId;
  final String? nailArtistName;
  final int? nailVariantId;
  final List<String> serviceIds;
  final List<int>? selectedPromotionIds;

  const BookingEntity({
    required this.bookingId,
    required this.salonId,
    required this.salonName,
    required this.bookingDate,
    required this.startTime,
    this.nailArtistId,
    this.nailArtistName,
    this.nailVariantId,
    required this.serviceIds,
    this.selectedPromotionIds,
  });

  @override
  List<Object?> get props => [
    bookingId,
    salonId,
    bookingDate,
    startTime,
    nailArtistId,
    nailVariantId,
    serviceIds,
  ];
}
