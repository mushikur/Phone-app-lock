import 'package:flutter/foundation.dart';

import '../domain/entities/installed_app.dart';
import '../domain/repositories/app_inventory_repository.dart';

/// Loading lifecycle of the app inventory.
enum AppListStatus { loading, ready, error }

/// Which slice of the inventory the list is showing.
enum AppFilter { all, locked }

/// Immutable snapshot rendered by the app list screen.
@immutable
class AppListState {
  const AppListState({
    this.status = AppListStatus.loading,
    this.apps = const [],
    this.lockedPackages = const {},
    this.query = '',
    this.filter = AppFilter.all,
    this.errorMessage,
  });

  final AppListStatus status;
  final List<InstalledApp> apps;
  final Set<String> lockedPackages;
  final String query;
  final AppFilter filter;
  final String? errorMessage;

  /// Apps left after the active search term and filter are applied.
  List<InstalledApp> get visibleApps {
    return apps.where((app) {
      if (filter == AppFilter.locked && !isLocked(app)) return false;
      return app.matches(query);
    }).toList(growable: false);
  }

  int get lockedCount => lockedPackages.length;

  int get totalCount => apps.length;

  bool isLocked(InstalledApp app) => lockedPackages.contains(app.packageName);

  /// True when the device has apps but the current search or filter hides them all.
  bool get hasNoMatches => apps.isNotEmpty && visibleApps.isEmpty;

  AppListState copyWith({
    AppListStatus? status,
    List<InstalledApp>? apps,
    Set<String>? lockedPackages,
    String? query,
    AppFilter? filter,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AppListState(
      status: status ?? this.status,
      apps: apps ?? this.apps,
      lockedPackages: lockedPackages ?? this.lockedPackages,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Owns the app-list state and mediates every call into the native layer.
class AppListController extends ChangeNotifier {
  AppListController(this._repository);

  final AppInventoryRepository _repository;

  AppListState _state = const AppListState();

  AppListState get state => _state;

  /// Loads the inventory and the persisted locked set.
  ///
  /// [showSpinner] is false for pull-to-refresh, where the indicator already
  /// signals progress and swapping in a skeleton would flicker.
  Future<void> load({bool showSpinner = true}) async {
    if (showSpinner) {
      _emit(_state.copyWith(status: AppListStatus.loading, clearError: true));
    }

    try {
      final apps = await _repository.loadInstalledApps();
      final locked = await _repository.loadLockedPackages();
      _emit(
        _state.copyWith(
          status: AppListStatus.ready,
          apps: apps,
          lockedPackages: locked,
          clearError: true,
        ),
      );
    } on AppInventoryException catch (error) {
      _emit(
        _state.copyWith(
          status: AppListStatus.error,
          errorMessage: error.message,
        ),
      );
    }
  }

  void setQuery(String query) {
    if (query == _state.query) return;
    _emit(_state.copyWith(query: query));
  }

  void setFilter(AppFilter filter) {
    if (filter == _state.filter) return;
    _emit(_state.copyWith(filter: filter));
  }

  /// Toggles [app], updating the UI immediately and rolling back if the native
  /// write fails. Returns an error message on failure, or null on success.
  Future<String?> toggleLock(InstalledApp app) async {
    final previous = _state.lockedPackages;
    final shouldLock = !previous.contains(app.packageName);
    final optimistic = Set<String>.from(previous);

    if (shouldLock) {
      optimistic.add(app.packageName);
    } else {
      optimistic.remove(app.packageName);
    }
    _emit(_state.copyWith(lockedPackages: optimistic));

    try {
      final confirmed = await _repository.setLocked(
        packageName: app.packageName,
        locked: shouldLock,
      );
      if (confirmed != shouldLock) {
        _emit(_state.copyWith(lockedPackages: previous));
      }
      return null;
    } on AppInventoryException catch (error) {
      _emit(_state.copyWith(lockedPackages: previous));
      return error.message;
    }
  }

  void _emit(AppListState next) {
    _state = next;
    notifyListeners();
  }
}
