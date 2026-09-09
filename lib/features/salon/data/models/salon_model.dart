class SalonModel {
  final String salonId;
  final String name;
  final String address;
  final String phone;
  final String status;
  final String imageUrl;
  final double depositConfig;
  final List<SalonOperatingHour> operatingHours;

  const SalonModel({
    required this.salonId,
    required this.name,
    required this.address,
    required this.phone,
    required this.status,
    required this.imageUrl,
    required this.depositConfig,
    required this.operatingHours,
  });

  factory SalonModel.fromJson(Map<String, dynamic> json) {
    final hours = json['operatingHours'] is List
        ? json['operatingHours'] as List
        : const [];

    return SalonModel(
      salonId: _readString(json['salonId'] ?? json['id']),
      name: _readString(json['name'] ?? json['salonName']),
      address: _readString(json['address']),
      phone: _readString(json['phone']),
      status: _readString(json['status']),
      imageUrl: _readString(json['imageUrl'] ?? json['image']),
      depositConfig: _readDouble(json['depositConfig']),
      operatingHours: hours
          .whereType<Map>()
          .map((item) => SalonOperatingHour.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
    );
  }
}

class SalonOperatingHour {
  final int dayOfWeek;
  final String dayName;
  final String openTime;
  final String closeTime;
  final bool isClosed;

  const SalonOperatingHour({
    required this.dayOfWeek,
    required this.dayName,
    required this.openTime,
    required this.closeTime,
    required this.isClosed,
  });

  factory SalonOperatingHour.fromJson(Map<String, dynamic> json) {
    return SalonOperatingHour(
      dayOfWeek: _readInt(json['dayOfWeek']),
      dayName: _readString(json['dayName']),
      openTime: _readString(json['openTime']),
      closeTime: _readString(json['closeTime']),
      isClosed: _readBool(json['isClosed']),
    );
  }
}

class SalonOffDate {
  final String salonOffDateId;
  final String startDate;
  final String endDate;
  final String description;

  const SalonOffDate({
    required this.salonOffDateId,
    required this.startDate,
    required this.endDate,
    required this.description,
  });

  factory SalonOffDate.fromJson(Map<String, dynamic> json) {
    return SalonOffDate(
      salonOffDateId: _readString(json['salonOffDateId'] ?? json['id']),
      startDate: _readString(json['startDate']),
      endDate: _readString(json['endDate']),
      description: _readString(json['description']),
    );
  }
}

String _readString(dynamic value) => value?.toString() ?? '';

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _readDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase().trim();
  return text == 'true' || text == '1' || text == 'yes';
}
