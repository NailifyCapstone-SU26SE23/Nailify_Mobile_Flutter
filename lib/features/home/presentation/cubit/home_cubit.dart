import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/home_data_models.dart';
import '../../data/repositories/home_repository.dart';
import 'home_state.dart';


class HomeCubit extends Cubit<HomeState> {
  final HomeRepository _repository;

  HomeCubit(this._repository) : super(const HomeState());

  Future<void> loadHomeData() async {
    emit(state.copyWith(status: HomeStatus.loading));

    try {
      final results = await Future.wait([
        _repository.getFeaturedServices(),
        _repository.getGalleryDesigns(),
        _repository.getCustomerReviews(),
        _repository.getNearestSalon(),
      ]);

      final servicesList = results[0] as List<HomeCategoryItem>;
      final galleryList = results[1] as List<HomeGalleryItem>;
      final reviewsList = results[2] as List<HomeReviewItem>;
      final salonItem = results[3] as HomeSalonItem?;

      emit(
        state.copyWith(
          status: HomeStatus.loaded,
          services: servicesList,
          gallery: galleryList,
          reviews: reviewsList,
          nearestSalon: salonItem,
        ),
      );

    } catch (e) {
      emit(
        state.copyWith(
          status: HomeStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void updateFavoriteGalleryItem({
    required int nailDesignId,
    required bool isFavorited,
    int? favoriteNailId,
  }) {
    final updatedGallery = state.gallery.map((item) {
      if (item.id != nailDesignId) return item;
      return item.copyWith(
        isFavorite: isFavorited,
        favoriteNailId: favoriteNailId,
        clearFavoriteNailId: !isFavorited,
      );
    }).toList();
    emit(state.copyWith(gallery: updatedGallery));
  }
}
