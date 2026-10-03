import 'package:flutter/widgets.dart';
import '../../../../generated/l10n.dart';

/// Models cho dữ liệu động hiển thị tại Trang chủ Nailify
class HomeCategoryItem {
  final dynamic id;
  final String title;
  final String? iconUrl;
  final String? imagePath;

  const HomeCategoryItem({
    required this.id,
    required this.title,
    this.iconUrl,
    this.imagePath,
  });

  factory HomeCategoryItem.fromJson(Map<String, dynamic> json) {
    return HomeCategoryItem(
      id: json['serviceId'] ?? json['id'],
      title:
          json['name'] as String? ??
          json['serviceName'] as String? ??
          json['title'] as String? ??
          'Dịch vụ',
      iconUrl:
          json['imageUrl'] as String? ??
          json['thumbnailUrl'] as String? ??
          json['iconUrl'] as String?,
    );
  }
}

class HomeGalleryItem {
  final int id;
  final String title;
  final String imageUrl;
  final bool isFavorite;
  final int? favoriteNailId;

  const HomeGalleryItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.isFavorite = false,
    this.favoriteNailId,
  });

  HomeGalleryItem copyWith({
    bool? isFavorite,
    int? favoriteNailId,
    bool clearFavoriteNailId = false,
  }) {
    return HomeGalleryItem(
      id: id,
      title: title,
      imageUrl: imageUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      favoriteNailId: clearFavoriteNailId
          ? null
          : favoriteNailId ?? this.favoriteNailId,
    );
  }

  factory HomeGalleryItem.fromJson(Map<String, dynamic> json) {
    final imageUrls = json['imageUrls'] ?? json['ImageUrls'];
    String img = (json['imageUrl'] ?? json['ImageUrl'] ?? '').toString().trim();
    if (img.isEmpty && json['primaryImageUrl'] != null) {
      img = json['primaryImageUrl'].toString().trim();
    }
    if (img.isEmpty && imageUrls is List && imageUrls.isNotEmpty) {
      img = imageUrls.first.toString().trim();
    }

    final rawId =
        json['nailDesignId'] ??
        json['NailDesignId'] ??
        json['id'] ??
        json['Id'];
    final int parsedId = rawId is int
        ? rawId
        : (rawId is num
              ? rawId.toInt()
              : int.tryParse(rawId?.toString() ?? '') ?? 0);

    final rawFav =
        json['isFavorited'] ??
        json['IsFavorited'] ??
        json['isFavorite'] ??
        json['IsFavorite'];
    final bool parsedFav = rawFav is bool
        ? rawFav
        : (rawFav?.toString().toLowerCase() == 'true' ||
              rawFav?.toString() == '1');

    final rawFavId = json['favoriteNailId'] ?? json['FavoriteNailId'];
    final int? parsedFavId = rawFavId is int
        ? rawFavId
        : (rawFavId is num
              ? rawFavId.toInt()
              : int.tryParse(rawFavId?.toString() ?? ''));

    return HomeGalleryItem(
      id: parsedId,
      title:
          (json['name'] ?? json['Name'] ?? json['title'] ?? 'Mẫu móng Nailify')
              .toString(),
      imageUrl: img,
      isFavorite: parsedFav,
      favoriteNailId: parsedFavId,
    );
  }
}

class HomeReviewItem {
  final String id;
  final String customerId;
  final String name;
  final String initials;
  final String review;
  final int stars;
  final String timeAgo;
  final DateTime? createdAt;
  final String? imageUrl;

  const HomeReviewItem({
    required this.id,
    this.customerId = '',
    required this.name,
    required this.initials,
    required this.review,
    required this.stars,
    required this.timeAgo,
    this.createdAt,
    this.imageUrl,
  });

  HomeReviewItem copyWith({
    String? id,
    String? customerId,
    String? name,
    String? initials,
    String? review,
    int? stars,
    String? timeAgo,
    DateTime? createdAt,
    String? imageUrl,
  }) {
    return HomeReviewItem(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      name: name ?? this.name,
      initials: initials ?? this.initials,
      review: review ?? this.review,
      stars: stars ?? this.stars,
      timeAgo: timeAgo ?? this.timeAgo,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  static String calculateInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      if (parts.length > 1 && parts.last.isNotEmpty) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      } else {
        return parts.first
            .substring(0, parts.first.length.clamp(1, 2))
            .toUpperCase();
      }
    }
    return 'KH';
  }

  String getLocalizedName(BuildContext context) {
    if (name == 'Khách hàng' || name == 'Customer' || name.isEmpty) {
      return S.of(context).customerDefault;
    }
    return name;
  }

  String getLocalizedTimeAgo(BuildContext context) {
    if (createdAt == null) {
      return S.of(context).timeDaysAgo('1');
    }
    final diff = DateTime.now().difference(createdAt!.toLocal());
    if (diff.inDays > 30) {
      return S.of(context).timeMonthsAgo('${(diff.inDays / 30).floor()}');
    } else if (diff.inDays > 0) {
      return S.of(context).timeDaysAgo('${diff.inDays}');
    } else if (diff.inHours > 0) {
      return S.of(context).timeHoursAgo('${diff.inHours}');
    } else if (diff.inMinutes > 0) {
      return S.of(context).timeMinutesAgo('${diff.inMinutes}');
    } else {
      return S.of(context).justNow;
    }
  }

  factory HomeReviewItem.fromJson(Map<String, dynamic> json) {
    final rawCustomerId =
        json['customerId'] ??
        json['CustomerId'] ??
        json['userId'] ??
        json['UserId'] ??
        '';
    final customerId = rawCustomerId.toString().trim();

    final userObj =
        json['user'] ??
        json['User'] ??
        json['customer'] ??
        json['Customer'] ??
        json['userInfo'] ??
        json['UserInfo'];

    String fn = '';
    String ln = '';
    if (userObj is Map) {
      fn = (userObj['firstName'] ?? userObj['FirstName'] ?? '').toString().trim();
      ln = (userObj['lastName'] ?? userObj['LastName'] ?? '').toString().trim();
    }
    if (fn.isEmpty && ln.isEmpty) {
      fn = (json['firstName'] ?? json['FirstName'] ?? '').toString().trim();
      ln = (json['lastName'] ?? json['LastName'] ?? '').toString().trim();
    }

    String fullName = '';
    if (ln.isNotEmpty && fn.isNotEmpty) {
      fullName = '$ln $fn';
    } else if (fn.isNotEmpty) {
      fullName = fn;
    } else if (ln.isNotEmpty) {
      fullName = ln;
    } else {
      fullName =
          json['customerName'] as String? ??
          json['CustomerName'] as String? ??
          json['name'] as String? ??
          json['Name'] as String? ??
          json['userName'] as String? ??
          json['UserName'] as String? ??
          'Khách hàng';
    }

    final init = calculateInitials(fullName);

    final rawScore =
        json['overallScore'] ??
        json['OverallScore'] ??
        json['stars'] ??
        json['rating'] ??
        json['score'] ??
        5;
    final int scoreInt = (rawScore is num)
        ? rawScore.round()
        : int.tryParse(rawScore.toString()) ?? 5;

    final img =
        (json['imageUrl'] ?? json['image'] ?? json['ImageUrl'] ?? json['Image'])
            ?.toString()
            .trim();
    final imageUrl = (img != null && img.isNotEmpty) ? img : null;

    final rawDate =
        json['createdAt'] ??
        json['CreatedAt'] ??
        json['createdDate'] ??
        json['CreatedDate'];
    DateTime? parsedDate;
    String timeAgoStr = '1 ngày trước';
    if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString());
      if (parsedDate != null) {
        final diff = DateTime.now().difference(parsedDate.toLocal());
        if (diff.inDays > 30) {
          timeAgoStr = '${(diff.inDays / 30).floor()} tháng trước';
        } else if (diff.inDays > 0) {
          timeAgoStr = '${diff.inDays} ngày trước';
        } else if (diff.inHours > 0) {
          timeAgoStr = '${diff.inHours} giờ trước';
        } else if (diff.inMinutes > 0) {
          timeAgoStr = '${diff.inMinutes} phút trước';
        } else {
          timeAgoStr = 'Vừa xong';
        }
      }
    }

    return HomeReviewItem(
      id:
          json['id']?.toString() ??
          json['bookingRatingId']?.toString() ??
          json['BookingRatingId']?.toString() ??
          '',
      customerId: customerId,
      name: fullName,
      initials: init,
      review:
          json['comment'] as String? ??
          json['Comment'] as String? ??
          json['review'] as String? ??
          json['content'] as String? ??
          'Dịch vụ rất tuyệt vời!',
      stars: scoreInt.clamp(1, 5),
      timeAgo: timeAgoStr,
      createdAt: parsedDate,
      imageUrl: imageUrl,
    );
  }
}

class HomeSalonItem {
  final String id;
  final String name;
  final String address;

  const HomeSalonItem({
    required this.id,
    required this.name,
    required this.address,
  });

  factory HomeSalonItem.fromJson(Map<String, dynamic> json) {
    return HomeSalonItem(
      id: json['salonId'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Nailify Salon',
      address: json['address'] as String? ?? 'Hệ thống salon trên toàn quốc',
    );
  }
}
