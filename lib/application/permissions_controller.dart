import 'package:flutter/foundation.dart';

import '../domain/entities/app_permission.dart';
import '../domain/repositories/permission_repository.dart';

/// Loading lifecycle of the permission snapshot.
enum PermissionsStatus { loading, ready, error }

/// Immutable snapshot rendered by the permissions screen.
@immutable
class PermissionsState {
  const PermissionsState({
    this.status = PermissionsStatus.loading,
    this.snapshot = const PermissionSnapshot.unknown(),
    this.errorMessage,
    this.pending,
  });

  final PermissionsStatus status;
  final PermissionSnapshot snapshot;
  final String? errorMessage;

  /// Permission whose settings page or prompt is currently being opened.
  final AppPermission? pending;

  bool get isReady =>
      status == PermissionsStatus.ready && snapshot.isReady;

  PermissionsState copyWith({
    PermissionsStatus? status,
    PermissionSnapshot? snapshot,
    String? errorMessage,
    AppPermission? pending,
    bool clearError = false,
    bool clearPending = false,
  }) {
    return PermissionsState(
      status: status ?? this.status,
      snapshot: snapshot ?? this.snapshot,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pending: clearPending ? null : (pending ?? this.pending),
    );
  }
}

/// Owns permission state and mediates every permission call into the native layer.
class PermissionsController extends ChangeNotifier {
  PermissionsController(this._repository);

  final PermissionRepository _repository;

  PermissionsState _state = const PermissionsState();

  PermissionsState get state => _state;

  /// Re-reads every permission status.
  ///
  /// [showSpinner] is false when refreshing after the app resumes from Settings,
  /// where swapping in a skeleton would flicker the screen the user just returned
  /// to.
  Future<void> refresh({bool showSpinner = true}) async {
    if (showSpinner) {
      _emit(_state.copyWith(status: PermissionsStatus.loading, clearError: true));
    }

    try {
      final snapshot = await _repository.loadStatuses();
      _emit(
        _state.copyWith(
          status: PermissionsStatus.ready,
          snapshot: snapshot,
          clearError: true,
        ),
      );
    } on PermissionException catch (error) {
      _emit(
        _state.copyWith(
          status: PermissionsStatus.error,
          errorMessage: error.message,
        ),
      );
    }
  }

  /// Hands the user off to the right place for [permission].
  ///
  /// Notifications get the system prompt where Android offers one; everything
  /// else opens a Settings page. Returns a message to show the user when the
  /// hand-off did not work, or null on success.
  Future<String?> grant(AppPermission permission) async {
    _emit(_state.copyWith(pending: permission, clearError: true));

    try {
      if (permission == AppPermission.notifications) {
        final status = await _repository.requestNotificationPermission();
        if (status.isSatisfied) {
          await refresh(showSpinner: false);
          return null;
        }
        // The prompt does not exist, or the user has dismissed it before; the
        // Settings page is the only remaining route.
        final opened = await _repository.openSettings(permission);
        return opened ? null : _couldNotOpenMessage;
      }

      final opened = await _repository.openSettings(permission);
      return opened ? null : _couldNotOpenMessage;
    } on PermissionException catch (error) {
      return error.message;
    } finally {
      _emit(_state.copyWith(clearPending: true));
    }
  }

  static const String _couldNotOpenMessage =
      'This phone does not offer that settings page. You can grant it from '
      'Android Settings.';

  void _emit(PermissionsState next) {
    _state = next;
    notifyListeners();
  }
}
