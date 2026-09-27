class BookingRatingModel {
  final String bookingRatingId;
  final int overallScore;
  final String comment;
  final String imageUrl;
  final int serviceQuality;
  final int punctuality;
  final int cleanliness;
  final String createdAt;

  const BookingRatingModel({
    required this.bookingRatingId,
    required this.overallScore,
    required this.comment,
    required this.imageUrl,
    required this.serviceQuality,
    required this.punctuality,
    required this.cleanliness,
    required this.createdAt,
  });

  factory BookingRatingModel.fromJson(Map<String, dynamic> json) {
    return BookingRatingModel(
      bookingRatingId: _readString(json['bookingRatingId'] ?? json['id']),
      overallScore: _readInt(json['overallScore']),
      comment: _readString(json['comment']),
      imageUrl: _readString(json['imageUrl'] ?? json['image']),
      serviceQuality: _readInt(json['serviceQuality']),
      punctuality: _readInt(json['punctuality']),
      cleanliness: _readInt(json['cleanliness']),
      createdAt: _readString(json['createdAt']),
    );
  }
}

String _readString(dynamic value) => value?.toString() ?? '';

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
