import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/category_type_model.dart';
import '../../data/models/nail_design_model.dart';
import '../../data/models/nail_filters.dart';
import '../../data/repositories/nail_design_repository.dart';

enum NailCatalogStatus { initial, loading, loaded, error, loadingMore }

class NailCatalogState extends Equatable {
  final NailCatalogStatus status;
  final List<NailDesignModel> designs;
  final List<CategoryTypeModel> categoryTypes;
  final NailFilters filters;
  final int page;
  final bool hasNextPage;
  final String? errorMessage;

  const NailCatalogState({
    this.status = NailCatalogStatus.initial,
    this.designs = const [],
    this.categoryTypes = const [],
    this.filters = const NailFilters(),
    this.page = 1,
    this.hasNextPage = true,
    this.errorMessage,
  });

  NailCatalogState copyWith({
    NailCatalogStatus? status,
    List<NailDesignModel>? designs,
    List<CategoryTypeModel>? categoryTypes,
    NailFilters? filters,
    int? page,
    bool? hasNextPage,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NailCatalogState(
      status: status ?? this.status,
      designs: designs ?? this.designs,
      categoryTypes: categoryTypes ?? this.categoryTypes,
      filters: filters ?? this.filters,
      page: page ?? this.page,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, designs, categoryTypes, filters, page, hasNextPage, errorMessage];
}

class NailCatalogCubit extends Cubit<NailCatalogState> {
  final NailDesignRepository _repository;
  final int _pageSize;

  NailCatalogCubit(this._repository, {int pageSize = 10})
      : _pageSize = pageSize,
        super(const NailCatalogState());

  Future<void> loadDesigns() async {
    emit(state.copyWith(status: NailCatalogStatus.loading, page: 1, clearError: true));
    try {
      final designsPage = await _repository.getNailDesigns(page: 1, pageSize: _pageSize, filters: state.filters);
      final categoryTypes = state.categoryTypes.isEmpty ? await _repository.getCategoryTypes() : state.categoryTypes;
      emit(state.copyWith(
        status: NailCatalogStatus.loaded,
        designs: designsPage.items,
        categoryTypes: categoryTypes,
        page: designsPage.page,
        hasNextPage: designsPage.hasNextPage,
      ));
    } catch (error) {
      emit(state.copyWith(status: NailCatalogStatus.error, errorMessage: error.toString()));
    }
  }

  Future<void> loadMore() async {
    if (!state.hasNextPage || state.status == NailCatalogStatus.loadingMore || state.status == NailCatalogStatus.loading) return;
    emit(state.copyWith(status: NailCatalogStatus.loadingMore, clearError: true));
    try {
      final nextPage = state.page + 1;
      final designsPage = await _repository.getNailDesigns(page: nextPage, pageSize: _pageSize, filters: state.filters);
      emit(state.copyWith(
        status: NailCatalogStatus.loaded,
        designs: [...state.designs, ...designsPage.items],
        page: designsPage.page,
        hasNextPage: designsPage.hasNextPage,
      ));
    } catch (error) {
      emit(state.copyWith(status: NailCatalogStatus.error, errorMessage: error.toString()));
    }
  }

  Future<void> applyFilters(NailFilters filters) async {
    emit(state.copyWith(filters: filters));
    await loadDesigns();
  }

  Future<void> refresh() => loadDesigns();
}
