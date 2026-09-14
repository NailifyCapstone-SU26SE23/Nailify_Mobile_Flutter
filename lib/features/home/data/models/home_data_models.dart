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
      title: json['name'] as String? ?? json['serviceName'] as String? ?? json['title'] as String? ?? 'Dịch vụ',
      iconUrl: json['imageUrl'] as String? ?? json['thumbnailUrl'] as String? ?? json['iconUrl'] as String?,
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

    final rawId = json['nailDesignId'] ?? json['NailDesignId'] ?? json['id'] ?? json['Id'];
    final int parsedId = rawId is int ? rawId : (rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '') ?? 0);

    final rawFav = json['isFavorited'] ?? json['IsFavorited'] ?? json['isFavorite'] ?? json['IsFavorite'];
    final bool parsedFav = rawFav is bool ? rawFav : (rawFav?.toString().toLowerCase() == 'true' || rawFav?.toString() == '1');

    final rawFavId = json['favoriteNailId'] ?? json['FavoriteNailId'];
    final int? parsedFavId = rawFavId is int ? rawFavId : (rawFavId is num ? rawFavId.toInt() : int.tryParse(rawFavId?.toString() ?? ''));

    return HomeGalleryItem(
      id: parsedId,
      title: (json['name'] ?? json['Name'] ?? json['title'] ?? 'Mẫu móng Nailify').toString(),
      imageUrl: img,
      isFavorite: parsedFav,
      favoriteNailId: parsedFavId,
    );
  }
}

class HomeReviewItem {
  final String id;
  final String name;
  final String initials;
  final String review;
  final int stars;
  final String timeAgo;
  final String? imageUrl;

  const HomeReviewItem({
    required this.id,
    required this.name,
    required this.initials,
    required this.review,
    required this.stars,
    required this.timeAgo,
    this.imageUrl,
  });

  factory HomeReviewItem.fromJson(Map<String, dynamic> json) {
    final fullName = json['customerName'] as String? ?? json['name'] as String? ?? json['userName'] as String? ?? 'Khách hàng';
    final parts = fullName.trim().split(' ');
    String init = 'KH';
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      if (parts.length > 1 && parts.last.isNotEmpty) {
        init = '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      } else {
        init = parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
      }
    }

    final rawScore = json['overallScore'] ?? json['stars'] ?? json['rating'] ?? json['score'] ?? 5;
    final int scoreInt = (rawScore is num) ? rawScore.round() : int.tryParse(rawScore.toString()) ?? 5;

    final img = (json['imageUrl'] ?? json['image'] ?? json['ImageUrl'] ?? json['Image'])?.toString().trim();
    final imageUrl = (img != null && img.isNotEmpty) ? img : null;

    return HomeReviewItem(
      id: json['id']?.toString() ?? json['bookingRatingId']?.toString() ?? '',
      name: fullName,
      initials: init,
      review: json['comment'] as String? ?? json['review'] as String? ?? json['content'] as String? ?? 'Dịch vụ rất tuyệt vời!',
      stars: scoreInt.clamp(1, 5),
      timeAgo: json['createdDate'] != null ? 'Gần đây' : '2 ngày trước',
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
