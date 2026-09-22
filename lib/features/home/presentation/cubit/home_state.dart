import 'package:equatable/equatable.dart';
import '../../data/models/home_data_models.dart';

enum HomeStatus { initial, loading, loaded, error }

class HomeState extends Equatable {
  final HomeStatus status;
  final List<HomeCategoryItem> services;
  final List<HomeGalleryItem> gallery;
  final List<HomeReviewItem> reviews;
  final HomeSalonItem? nearestSalon;
  final String? errorMessage;

  const HomeState({
    this.status = HomeStatus.initial,
    this.services = const [],
    this.gallery = const [],
    this.reviews = const [],
    this.nearestSalon,
    this.errorMessage,
  });

  HomeState copyWith({
    HomeStatus? status,
    List<HomeCategoryItem>? services,
    List<HomeGalleryItem>? gallery,
    List<HomeReviewItem>? reviews,
    HomeSalonItem? nearestSalon,
    String? errorMessage,
  }) {
    return HomeState(
      status: status ?? this.status,
      services: services ?? this.services,
      gallery: gallery ?? this.gallery,
      reviews: reviews ?? this.reviews,
      nearestSalon: nearestSalon ?? this.nearestSalon,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    services,
    gallery,
    reviews,
    nearestSalon,
    errorMessage,
  ];
}
