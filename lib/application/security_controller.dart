import 'package:flutter/foundation.dart';

import '../domain/repositories/security_repository.dart';

/// Loading lifecycle of the security status.
enum SecurityLoadStatus { loading, ready, error }

/// Immutable snapshot rendered by the security card.
@immutable
class SecurityState {
  const SecurityState({
    this.loadStatus = SecurityLoadStatus.loading,
    this.status = const SecurityStatus.unknown(),
    this.errorMessage,
  });

  final SecurityLoadStatus loadStatus;
  final SecurityStatus status;
  final String? errorMessage;

  bool get hasPin => status.hasPin;

  bool get canUseBiometrics => status.canUseBiometrics;

  SecurityState copyWith({
    SecurityLoadStatus? loadStatus,
    SecurityStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SecurityState(
      loadStatus: loadStatus ?? this.loadStatus,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Owns the security status shown in the app.
///
/// It can ask the native layer to open the PIN screen and report whether a PIN
/// exists — nothing more. No PIN, no hash and no unlock decision passes through
/// here, by design.
class SecurityController extends ChangeNotifier {
  SecurityController(this._repository);

  final SecurityRepository _repository;

  SecurityState _state = const SecurityState();

  SecurityState get state => _state;

  /// Re-reads whether a PIN exists and whether biometrics are usable.
  ///
  /// Called on resume as well, since the PIN is created on a native screen and
  /// enrolling a fingerprint happens in Android Settings.
  Future<void> refresh({bool showSpinner = true}) async {
    if (showSpinner) {
      _emit(
        _state.copyWith(loadStatus: SecurityLoadStatus.loading, clearError: true),
      );
    }

    try {
      final status = await _repository.loadStatus();
      _emit(
        _state.copyWith(
          loadStatus: SecurityLoadStatus.ready,
          status: status,
          clearError: true,
        ),
      );
    } on SecurityException catch (error) {
      _emit(
        _state.copyWith(
          loadStatus: SecurityLoadStatus.error,
          errorMessage: error.message,
        ),
      );
    }
  }

  /// Opens the native PIN screen.
  ///
  /// Returns a message to show the user when it could not be opened, or null on
  /// success.
  Future<String?> openPinSetup() async {
    try {
      final opened = await _repository.openPinSetup();
      return opened ? null : 'Could not open the PIN screen.';
    } on SecurityException catch (error) {
      return error.message;
    }
  }

  void _emit(SecurityState next) {
    _state = next;
    notifyListeners();
  }
}
