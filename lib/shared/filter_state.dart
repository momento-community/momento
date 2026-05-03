import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/momento_category.dart';

enum SortBy { newest, popular, closest }

@immutable
class FilterState {
  const FilterState({
    this.categories = const {},
    this.distanceKm = 12.5,
    this.timeStart,
    this.timeEnd,
    this.sortBy = SortBy.newest,
  });

  final Set<MomentoCategory> categories;
  final double distanceKm;
  final DateTime? timeStart;
  final DateTime? timeEnd;
  final SortBy sortBy;

  FilterState copyWith({
    Set<MomentoCategory>? categories,
    double? distanceKm,
    DateTime? timeStart,
    DateTime? timeEnd,
    SortBy? sortBy,
    bool clearTime = false,
  }) {
    return FilterState(
      categories: categories ?? this.categories,
      distanceKm: distanceKm ?? this.distanceKm,
      timeStart: clearTime ? null : (timeStart ?? this.timeStart),
      timeEnd: clearTime ? null : (timeEnd ?? this.timeEnd),
      sortBy: sortBy ?? this.sortBy,
    );
  }

  bool get isFilteringTime => timeStart != null;

  static const FilterState reset = FilterState();
}

class FilterStateNotifier extends Notifier<FilterState> {
  @override
  FilterState build() => const FilterState();

  void replaceWith(FilterState next) => state = next;

  void toggleCategory(MomentoCategory cat) {
    final next = {...state.categories};
    next.contains(cat) ? next.remove(cat) : next.add(cat);
    state = state.copyWith(categories: next);
  }

  void setDistance(double km) => state = state.copyWith(distanceKm: km);

  void setTimeRange(DateTime? start, DateTime? end) {
    if (start == null) {
      state = state.copyWith(clearTime: true);
    } else {
      state = state.copyWith(timeStart: start, timeEnd: end);
    }
  }

  void setSort(SortBy sort) => state = state.copyWith(sortBy: sort);

  void resetAll() => state = FilterState.reset;
}

final filterStateProvider =
    NotifierProvider<FilterStateNotifier, FilterState>(
        FilterStateNotifier.new);
