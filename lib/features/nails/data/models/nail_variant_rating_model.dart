import '../../../../core/utils/api_response_parser.dart';

class NailVariantRatingPage {
  final List<NailVariantRatingModel> items;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final bool hasPrevious;
  final bool hasNext;

  const NailVariantRatingPage({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.hasPrevious,
    required this.hasNext,
  });

  factory NailVariantRatingPage.empty({int page = 1}) {
    return NailVariantRatingPage(
      items: const [],
      currentPage: page,
      totalPages: 1,
      totalItems: 0,
      hasPrevious: false,
      hasNext: false,
    );
  }

  factory NailVariantRatingPage.fromJson(Map<String, dynamic> json) {
    final data = ApiResponseParser.unwrapMap(json);
    final items = (data['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => NailVariantRatingModel.fromJson(item))
        .toList();
    final metaData = data['metaData'] as Map? ?? const {};

    return NailVariantRatingPage(
      items: items,
      currentPage: _readInt(metaData['currentPage'], 1),
      totalPages: _readInt(metaData['totalPages'], 1),
      totalItems: _readInt(metaData['totalItems'], items.length),
      hasPrevious: _readBool(metaData['hasPrevious']),
      hasNext: _readBool(metaData['hasNext']),
    );
  }

  static int _readInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }
}

class NailVariantRatingModel {
  final String bookingRatingId;
  final int overallScore;
  final String comment;
  final String imageUrl;
  final int serviceQuality;
  final int punctuality;
  final int cleanliness;
  final DateTime? createdAt;
  final String userId;
  final String userName;
  final String userAvatarUrl;

  const NailVariantRatingModel({
    required this.bookingRatingId,
    required this.overallScore,
    required this.comment,
    required this.imageUrl,
    required this.serviceQuality,
    required this.punctuality,
    required this.cleanliness,
    required this.createdAt,
    this.userId = '',
    this.userName = '',
    this.userAvatarUrl = '',
  });

  static String _extractFullName(Map data) {
    final fn = (data['firstName'] ?? data['FirstName'] ?? '').toString().trim();
    final ln = (data['lastName'] ?? data['LastName'] ?? '').toString().trim();
    if (fn.isNotEmpty || ln.isNotEmpty) {
      if (ln.isNotEmpty && fn.isNotEmpty) return '$ln $fn';
      return fn.isNotEmpty ? fn : ln;
    }
    return (data['customerName'] ??
            data['CustomerName'] ??
            data['fullName'] ??
            data['FullName'] ??
            data['name'] ??
            data['Name'] ??
            data['userName'] ??
            data['UserName'] ??
            '')
        .toString()
        .trim();
  }

  factory NailVariantRatingModel.fromJson(Map<dynamic, dynamic> json) {
    final userObj = json['user'] ??
        json['User'] ??
        json['customer'] ??
        json['Customer'] ??
        json['userInfo'] ??
        json['UserInfo'];
    String name = '';
    String avatar = '';
    String uId = '';

    if (userObj is Map) {
      name = _extractFullName(userObj);
      avatar = (userObj['avatarUrl'] ??
              userObj['AvatarUrl'] ??
              userObj['avatar'] ??
              userObj['Avatar'] ??
              '')
          .toString()
          .trim();
      uId = (userObj['userId'] ??
              userObj['UserId'] ??
              userObj['id'] ??
              userObj['Id'] ??
              '')
          .toString()
          .trim();
    }

    if (name.isEmpty) {
      name = _extractFullName(json);
    }
    if (avatar.isEmpty) {
      avatar = (json['customerAvatarUrl'] ??
              json['CustomerAvatarUrl'] ??
              json['avatarUrl'] ??
              json['AvatarUrl'] ??
              json['avatar'] ??
              json['Avatar'] ??
              '')
          .toString()
          .trim();
    }
    if (uId.isEmpty) {
      uId = (json['userId'] ??
              json['UserId'] ??
              json['customerId'] ??
              json['CustomerId'] ??
              '')
          .toString()
          .trim();
    }

    final rawImg = json['imageUrl'] ??
        json['ImageUrl'] ??
        json['image'] ??
        json['Image'] ??
        json['ratingImage'] ??
        json['RatingImage'] ??
        json['ratingImageUrl'] ??
        json['RatingImageUrl'] ??
        json['imagePath'] ??
        json['ImagePath'] ??
        json['images'] ??
        json['Images'];
    String imgUrl = '';
    if (rawImg is List && rawImg.isNotEmpty) {
      imgUrl = rawImg.first.toString().trim();
    } else if (rawImg != null) {
      imgUrl = rawImg.toString().trim();
    }

    return NailVariantRatingModel(
      bookingRatingId:
          (json['bookingRatingId'] ?? json['BookingRatingId'] ?? '').toString(),
      overallScore: ApiResponseParser.asInt(
        json['overallScore'] ?? json['OverallScore'],
      ),
      comment: (json['comment'] ?? json['Comment'] ?? '').toString().trim(),
      imageUrl: imgUrl,
      serviceQuality: ApiResponseParser.asInt(
        json['serviceQuality'] ?? json['ServiceQuality'],
      ),
      punctuality: ApiResponseParser.asInt(
        json['punctuality'] ?? json['Punctuality'],
      ),
      cleanliness: ApiResponseParser.asInt(
        json['cleanliness'] ?? json['Cleanliness'],
      ),
      createdAt: DateTime.tryParse(
        (json['createdAt'] ?? json['CreatedAt'] ?? '').toString(),
      ),
      userId: uId,
      userName: name,
      userAvatarUrl: avatar,
    );
  }
}
