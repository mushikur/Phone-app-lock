import 'package:flutter/foundation.dart';

import '../domain/entities/app_permission.dart';
import '../domain/entities/setup_item.dart';
import '../domain/repositories/device_repository.dart';
import '../domain/repositories/permission_repository.dart';
import '../domain/repositories/security_repository.dart';

/// Builds the single list of things the user may still need to do.
///
/// It reads from the permission, security and device layers and turns them into
/// one ordered list, so setup lives in one screen rather than being scattered.
/// It owns no state of its own beyond that list: every status comes from the
/// native layer, which is the only thing that actually knows.
class SetupController extends ChangeNotifier {
  SetupController({
    required PermissionRepository permissions,
    required SecurityRepository security,
    required DeviceRepository device,
  })  // Named parameters cannot be private, so these are assigned rather than
      // taken as initialising formals.
      // ignore: prefer_initializing_formals
      : _permissions = permissions,
        // ignore: prefer_initializing_formals
        _security = security,
        // ignore: prefer_initializing_formals
        _device = device;

  final PermissionRepository _permissions;
  final SecurityRepository _security;
  final DeviceRepository _device;

  SetupState _state = const SetupState();

  SetupState get state => _state;

  DeviceCompatibility _compatibility = const DeviceCompatibility.unknown();

  DeviceCompatibility get compatibility => _compatibility;

  /// Re-reads everything.
  ///
  /// Called on every resume, because each of these can be changed in Android
  /// settings while the app is in the background.
  Future<void> refresh({bool showSpinner = true}) async {
    if (showSpinner && _state.items.isEmpty) {
      _emit(const SetupState(isLoading: true));
    }

    try {
      final snapshot = await _permissions.loadStatuses();
      final security = await _security.loadStatus();
      final popupWarnings = await _security.loadPopupWarnings();
      _compatibility = await _device.loadCompatibility();

      _emit(
        SetupState(
          isLoading: false,
          items: _build(snapshot, security, popupWarnings),
        ),
      );
    } on PermissionException {
      _emit(SetupState(isLoading: false, items: _state.items));
    } on SecurityException {
      _emit(SetupState(isLoading: false, items: _state.items));
    }
  }

  List<SetupItem> _build(
    PermissionSnapshot permissions,
    SecurityStatus security,
    List<PopupWarning> popupWarnings,
  ) {
    return [
      _usageAccess(permissions),
      _overlay(permissions),
      _notifications(permissions),
      _notificationAccess(security),
      _popups(popupWarnings),
      _background(permissions),
    ];
  }

  SetupItem _usageAccess(PermissionSnapshot permissions) {
    final granted = permissions.isSatisfied(AppPermission.usageAccess);
    return SetupItem(
      id: SetupItemId.usageAccess,
      title: 'See which app is open',
      description: 'Lets Samir Lock notice the moment you open a locked app. '
          'It never looks inside your apps.',
      status: granted ? SetupItemStatus.done : SetupItemStatus.actionNeeded,
      importance: SetupImportance.required_,
      actionLabel: 'Allow',
    );
  }

  SetupItem _overlay(PermissionSnapshot permissions) {
    final granted = permissions.isSatisfied(AppPermission.displayOverOtherApps);
    return SetupItem(
      id: SetupItemId.displayOverOtherApps,
      title: 'Show the lock screen',
      description: 'Lets the lock screen appear on top of the app you are '
          'opening, so it stays hidden until you unlock it.',
      status: granted ? SetupItemStatus.done : SetupItemStatus.actionNeeded,
      importance: SetupImportance.required_,
      actionLabel: 'Allow',
    );
  }

  /// Only asked for where Android actually requires it.
  SetupItem _notifications(PermissionSnapshot permissions) {
    final status = permissions.statusOf(AppPermission.notifications);
    if (status == PermissionStatus.unsupported ||
        !_compatibility.needsNotificationPermission) {
      return const SetupItem(
        id: SetupItemId.notifications,
        title: 'Show a running notice',
        description: '',
        status: SetupItemStatus.notApplicable,
        importance: SetupImportance.recommended,
        actionLabel: 'Allow',
      );
    }

    return SetupItem(
      id: SetupItemId.notifications,
      title: 'Show a running notice',
      description: 'Android shows a small notice while protection is on. It '
          'also stops your phone shutting Samir Lock down.',
      status: status.isSatisfied
          ? SetupItemStatus.done
          : SetupItemStatus.actionNeeded,
      importance: SetupImportance.recommended,
      actionLabel: 'Allow',
    );
  }

  /// Only relevant once the user wants notification hiding.
  SetupItem _notificationAccess(SecurityStatus security) {
    if (!security.isNotificationPrivacyEnabled &&
        !security.isNotificationAccessGranted) {
      return const SetupItem(
        id: SetupItemId.notificationAccess,
        title: 'Hide notification content',
        description: '',
        status: SetupItemStatus.notApplicable,
        importance: SetupImportance.recommended,
        actionLabel: 'Enable',
      );
    }

    return SetupItem(
      id: SetupItemId.notificationAccess,
      title: 'Hide notification content',
      description: 'Lets Samir Lock replace notifications from locked apps so '
          'their messages are not readable until you unlock.',
      status: security.isNotificationAccessGranted
          ? SetupItemStatus.done
          : SetupItemStatus.actionNeeded,
      importance: SetupImportance.recommended,
      actionLabel: 'Enable',
    );
  }

  /// Only shown for apps that can still pop up.
  SetupItem _popups(List<PopupWarning> warnings) {
    if (warnings.isEmpty) {
      return const SetupItem(
        id: SetupItemId.notificationPopups,
        title: 'Stop message pop-ups',
        description: '',
        status: SetupItemStatus.notApplicable,
        importance: SetupImportance.recommended,
        actionLabel: 'Configure',
      );
    }

    final names = warnings.map((warning) => warning.appName).join(', ');
    return SetupItem(
      id: SetupItemId.notificationPopups,
      title: 'Stop message pop-ups',
      description: 'Android shows a pop-up before Samir Lock is told a message '
          'arrived, so it can be read for a moment. Samir Lock cannot switch '
          'these off for you, but you can.',
      status: SetupItemStatus.actionNeeded,
      importance: SetupImportance.recommended,
      actionLabel: 'Configure',
      detail: 'Still popping up: $names',
    );
  }

  /// Only shown on phones where it actually matters.
  SetupItem _background(PermissionSnapshot permissions) {
    if (!_compatibility.needsBackgroundGuidance) {
      return const SetupItem(
        id: SetupItemId.background,
        title: 'Keep running in the background',
        description: '',
        status: SetupItemStatus.notApplicable,
        importance: SetupImportance.recommended,
        actionLabel: 'Review',
      );
    }

    return SetupItem(
      id: SetupItemId.background,
      title: 'Keep running in the background',
      description: _compatibility.isBackgroundRestricted
          ? 'This phone is currently stopping Samir Lock from running in the '
              'background, so locked apps may open without asking.'
          : 'Phones like yours pause background apps to save power, which can '
              'leave your apps unlocked.',
      status: permissions.isSatisfied(AppPermission.batteryOptimization)
          ? SetupItemStatus.done
          : SetupItemStatus.actionNeeded,
      importance: SetupImportance.recommended,
      actionLabel: 'Review',
      detail: backgroundHint(),
    );
  }

  /// Where the setting lives on this phone.
  ///
  /// Wording only: Samir Lock never changes these itself, and never claims to.
  String backgroundHint() {
    return switch (_compatibility.vendor) {
      DeviceVendor.samsung =>
        'On Samsung: Battery > Background usage limits > Never sleeping apps.',
      DeviceVendor.xiaomi =>
        'On Xiaomi, Redmi and POCO: Apps > Samir Lock > Battery saver > No '
            'restrictions, and turn on Autostart.',
      DeviceVendor.oppo || DeviceVendor.realme =>
        'On OPPO and realme: Battery > App battery usage > Samir Lock > Allow '
            'background activity.',
      DeviceVendor.oneplus =>
        'On OnePlus: Battery > Battery optimisation > Samir Lock > Do not '
            'optimise.',
      DeviceVendor.vivo =>
        'On vivo: Battery > High background power consumption > allow Samir '
            'Lock, and turn on Autostart.',
      DeviceVendor.huawei =>
        'On Huawei and Honor: Battery > App launch > Samir Lock > Manage '
            'manually, with all three switches on.',
      DeviceVendor.motorola || DeviceVendor.google || DeviceVendor.other =>
        'Apps > Samir Lock > Battery > Unrestricted.',
    };
  }

  void _emit(SetupState next) {
    _state = next;
    notifyListeners();
  }
}
