class UserProfile {
  final String userId;
  final String email;
  final String? phone;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? status;
  final String? skinTone;
  final String? occupation;
  final String? nailCondition;
  final String? personaId;

  const UserProfile({
    required this.userId,
    required this.email,
    this.phone,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.status,
    this.skinTone,
    this.occupation,
    this.nailCondition,
    this.personaId,
  });

  String get fullName {
    final name = [firstName, lastName]
        .where((part) => part != null && part.trim().isNotEmpty)
        .join(' ');
    return name.isEmpty ? email : name;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: (json['userId'] ?? json['UserId'] ?? '').toString(),
      email: (json['email'] ?? json['Email'] ?? '').toString(),
      phone: (json['phone'] ?? json['Phone'])?.toString(),
      firstName: (json['firstName'] ?? json['FirstName'])?.toString(),
      lastName: (json['lastName'] ?? json['LastName'])?.toString(),
      avatarUrl: (json['avatarUrl'] ?? json['AvatarUrl'])?.toString(),
      status: (json['status'] ?? json['Status'])?.toString(),
      skinTone: (json['skinTone'] ?? json['SkinTone'])?.toString(),
      occupation: (json['occupation'] ?? json['Occupation'])?.toString(),
      nailCondition: (json['nailCondition'] ?? json['NailCondition'])?.toString(),
      personaId: (json['personaId'] ?? json['PersonaId'])?.toString(),
    );
  }
}
