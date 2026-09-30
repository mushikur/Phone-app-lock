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
    this.popupWarnings = const [],
  });

  final SecurityLoadStatus loadStatus;
  final SecurityStatus status;
  final String? errorMessage;

  /// Locked apps that can still show notification pop-ups.
  final List<PopupWarning> popupWarnings;

  bool get hasPin => status.hasPin;

  bool get canUseBiometrics => status.canUseBiometrics;

  bool get biometricsActive => status.biometricsActive;

  SecurityState copyWith({
    SecurityLoadStatus? loadStatus,
    SecurityStatus? status,
    String? errorMessage,
    List<PopupWarning>? popupWarnings,
    bool clearError = false,
  }) {
    return SecurityState(
      loadStatus: loadStatus ?? this.loadStatus,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      popupWarnings: popupWarnings ?? this.popupWarnings,
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
      // Which apps can still pop up is read alongside the rest, so returning
      // from Android settings refreshes it.
      final warnings = await _repository.loadPopupWarnings();
      _emit(
        _state.copyWith(
          loadStatus: SecurityLoadStatus.ready,
          status: status,
          popupWarnings: warnings,
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

  /// Turns the biometric option on or off.
  ///
  /// Returns a message to show the user on failure, or null on success.
  Future<String?> setBiometricEnabled(bool enabled) async {
    try {
      final status = await _repository.setBiometricEnabled(enabled);
      _emit(
        _state.copyWith(
          loadStatus: SecurityLoadStatus.ready,
          status: status,
          clearError: true,
        ),
      );
      return null;
    } on SecurityException catch (error) {
      _emit(_state.copyWith(errorMessage: error.message));
      return error.message;
    }
  }

  /// Turns notification hiding on or off.
  ///
  /// Returns a message to show the user when it could not take effect, or null
  /// on success.
  Future<String?> setNotificationPrivacyEnabled(bool enabled) async {
    try {
      final status = await _repository.setNotificationPrivacyEnabled(enabled);
      _emit(
        _state.copyWith(
          loadStatus: SecurityLoadStatus.ready,
          status: status,
          clearError: true,
        ),
      );

      if (enabled && !status.isNotificationPrivacyEnabled) {
        return 'Samir Lock needs notification access before it can hide '
            'notifications.';
      }
      return null;
    } on SecurityException catch (error) {
      _emit(_state.copyWith(errorMessage: error.message));
      return error.message;
    }
  }

  /// Opens the Android screen where notification access is granted.
  Future<String?> openNotificationAccess() async {
    try {
      final opened = await _repository.openNotificationAccess();
      return opened ? null : 'Could not open notification access settings.';
    } on SecurityException catch (error) {
      return error.message;
    }
  }

  /// Turns troubleshooting logs on or off.
  Future<String?> setDiagnosticsEnabled(bool enabled) async {
    try {
      final status = await _repository.setDiagnosticsEnabled(enabled);
      _emit(
        _state.copyWith(
          loadStatus: SecurityLoadStatus.ready,
          status: status,
          clearError: true,
        ),
      );
      return null;
    } on SecurityException catch (error) {
      _emit(_state.copyWith(errorMessage: error.message));
      return error.message;
    }
  }

  /// Opens the Android page where an app's pop-ups can be turned off.
  ///
  /// Returns a message to show the user on failure, or null on success.
  Future<String?> openChannelSettings(PopupWarning warning) async {
    try {
      final opened = await _repository.openChannelSettings(
        packageName: warning.packageName,
        channelId: warning.channelId,
      );
      return opened
          ? null
          : 'Could not open notification settings for ${warning.appName}.';
    } on SecurityException catch (error) {
      return error.message;
    }
  }

  void _emit(SecurityState next) {
    _state = next;
    notifyListeners();
  }
}
