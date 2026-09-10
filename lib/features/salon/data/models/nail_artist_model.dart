class NailArtistModel {
  final String nailArtistId;
  final String accountId;
  final String salonId;
  final String status;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String avatarUrl;
  final List<NailArtistSchedule> schedules;

  const NailArtistModel({
    required this.nailArtistId,
    required this.accountId,
    required this.salonId,
    required this.status,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.avatarUrl,
    required this.schedules,
  });

  String get fullName {
    final name = '$lastName $firstName'.trim();
    return name.isEmpty ? 'Nail Artist' : name;
  }

  factory NailArtistModel.fromJson(Map<String, dynamic> json) {
    final schedules = json['schedules'] is List
        ? json['schedules'] as List
        : const [];

    return NailArtistModel(
      nailArtistId: _readString(json['nailArtistId'] ?? json['id']),
      accountId: _readString(json['accountId']),
      salonId: _readString(json['salonId']),
      status: _readString(json['status']),
      email: _readString(json['email']),
      firstName: _readString(json['firstName']),
      lastName: _readString(json['lastName']),
      phone: _readString(json['phone']),
      avatarUrl: _readString(json['avatarUrl'] ?? json['imageUrl']),
      schedules: schedules
          .whereType<Map>()
          .map(
            (item) =>
                NailArtistSchedule.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class NailArtistSchedule {
  final String scheduleId;
  final String workDate;
  final String shiftStart;
  final String shiftEnd;
  final String status;

  const NailArtistSchedule({
    required this.scheduleId,
    required this.workDate,
    required this.shiftStart,
    required this.shiftEnd,
    required this.status,
  });

  factory NailArtistSchedule.fromJson(Map<String, dynamic> json) {
    return NailArtistSchedule(
      scheduleId: _readString(json['scheduleId'] ?? json['id']),
      workDate: _readString(json['workDate']),
      shiftStart: _readString(json['shiftStart']),
      shiftEnd: _readString(json['shiftEnd']),
      status: _readString(json['status']),
    );
  }
}

String _readString(dynamic value) => value?.toString() ?? '';
