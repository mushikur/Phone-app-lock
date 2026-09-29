import 'package:flutter/foundation.dart';

import '../domain/repositories/protection_repository.dart';

/// Loading lifecycle of the protection status.
enum ProtectionLoadStatus { loading, ready, error }

/// Immutable snapshot rendered by the protection card.
@immutable
class ProtectionState {
  const ProtectionState({
    this.loadStatus = ProtectionLoadStatus.loading,
    this.status = const ProtectionStatus.unknown(),
    this.isBusy = false,
    this.errorMessage,
  });

  final ProtectionLoadStatus loadStatus;
  final ProtectionStatus status;

  /// A start or stop is in flight.
  final bool isBusy;
  final String? errorMessage;

  bool get isEnabled => status.isEnabled;

  bool get canRun => status.canRun;

  /// Switched on, permitted, and the service is actually up.
  bool get isActive => status.isEnabled && status.isRunning;

  ProtectionState copyWith({
    ProtectionLoadStatus? loadStatus,
    ProtectionStatus? status,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProtectionState(
      loadStatus: loadStatus ?? this.loadStatus,
      status: status ?? this.status,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Owns protection state and drives the native guard service.
class ProtectionController extends ChangeNotifier {
  ProtectionController(this._repository);

  final ProtectionRepository _repository;

  ProtectionState _state = const ProtectionState();

  ProtectionState get state => _state;

  /// Re-reads whether protection is on and able to run.
  ///
  /// Called on resume as well as at startup, because a permission revoked in
  /// Android Settings can stop the guard behind the app's back.
  Future<void> refresh({bool showSpinner = true}) async {
    if (showSpinner) {
      _emit(
        _state.copyWith(
          loadStatus: ProtectionLoadStatus.loading,
          clearError: true,
        ),
      );
    }

    try {
      final status = await _repository.loadStatus();
      _emit(
        _state.copyWith(
          loadStatus: ProtectionLoadStatus.ready,
          status: status,
          clearError: true,
        ),
      );
    } on ProtectionException catch (error) {
      _emit(
        _state.copyWith(
          loadStatus: ProtectionLoadStatus.error,
          errorMessage: error.message,
        ),
      );
    }
  }

  /// Turns protection on or off.
  ///
  /// Returns a message to show the user when the request did not take effect —
  /// most often because a required permission is missing — or null on success.
  Future<String?> setEnabled(bool enabled) async {
    _emit(_state.copyWith(isBusy: true, clearError: true));

    try {
      final status = await _repository.setEnabled(enabled);
      _emit(
        _state.copyWith(
          loadStatus: ProtectionLoadStatus.ready,
          status: status,
          isBusy: false,
        ),
      );

      if (enabled && !status.isEnabled) {
        return status.canRun
            ? 'Protection could not be started. Please try again.'
            : 'Samir Lock still needs permission to watch your apps and to '
                'show the lock screen.';
      }
      return null;
    } on ProtectionException catch (error) {
      _emit(_state.copyWith(isBusy: false, errorMessage: error.message));
      return error.message;
    }
  }

  void _emit(ProtectionState next) {
    _state = next;
    notifyListeners();
  }
}
