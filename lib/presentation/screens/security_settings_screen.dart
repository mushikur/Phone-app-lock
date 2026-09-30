import 'package:flutter/material.dart';

import '../../application/permissions_controller.dart';
import '../../application/protection_controller.dart';
import '../../application/security_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/repositories/security_repository.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/settings_tile.dart';

/// PIN, biometrics, attempt protection and permissions, in one place.
class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({
    super.key,
    required this.securityController,
    required this.protectionController,
    required this.permissionsController,
    required this.onOpenPermissions,
  });

  final SecurityController securityController;
  final ProtectionController protectionController;
  final PermissionsController permissionsController;
  final VoidCallback onOpenPermissions;

  static const Key biometricSwitchKey = Key('biometric-switch');
  static const Key changePinKey = Key('change-pin-tile');
  static const Key notificationPrivacyKey = Key('notification-privacy-switch');
  static const Key notificationAccessKey = Key('notification-access-tile');

  Future<void> _setUpPin(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await securityController.openPinSetup();
    if (error == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _setBiometric(BuildContext context, bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await securityController.setBiometricEnabled(enabled);
    if (error == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _setNotificationPrivacy(BuildContext context, bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await securityController.setNotificationPrivacyEnabled(enabled);
    if (error == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _openNotificationAccess(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await securityController.openNotificationAccess();
    if (error == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  String _biometricSubtitle(SecurityState state) {
    return switch (state.status.biometric) {
      BiometricAvailability.available => state.status.isBiometricEnabled
          ? 'Unlock with your fingerprint instead of typing your PIN.'
          : 'Switched off. Your PIN is always accepted.',
      BiometricAvailability.notEnrolled =>
        'Add a fingerprint in Android settings to use this.',
      BiometricAvailability.temporarilyUnavailable =>
        'Not available on this device right now.',
      BiometricAvailability.unavailable =>
        'This device does not support fingerprint unlock.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            const SectionHeader('Unlocking'),
            ListenableBuilder(
              listenable: securityController,
              builder: (context, _) {
                final state = securityController.state;
                final canToggle = state.canUseBiometrics;

                return SettingsGroup(
                  children: [
                    SettingsTile(
                      key: changePinKey,
                      icon: state.hasPin ? Icons.password : Icons.key_off_outlined,
                      title: state.hasPin ? 'Change PIN' : 'Create a PIN',
                      subtitle: state.hasPin
                          ? 'Used to unlock your protected apps.'
                          : 'Needed before protection can be switched on.',
                      onTap: () => _setUpPin(context),
                    ),
                    SettingsTile(
                      icon: Icons.fingerprint,
                      title: 'Fingerprint unlock',
                      subtitle: _biometricSubtitle(state),
                      isEnabled: canToggle,
                      trailing: Semantics(
                        label: 'Fingerprint unlock',
                        child: Switch(
                          key: biometricSwitchKey,
                          value: state.status.biometricsActive,
                          onChanged: canToggle
                              ? (value) => _setBiometric(context, value)
                              : null,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SectionHeader('Protection'),
            ListenableBuilder(
              listenable: Listenable.merge([
                securityController,
                protectionController,
              ]),
              builder: (context, _) {
                final security = securityController.state;
                final protection = protectionController.state;
                final failed = security.status.failedAttempts;

                return SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: Icons.timer_outlined,
                      title: 'Wrong PIN protection',
                      subtitle: failed > 0
                          ? '$failed wrong ${failed == 1 ? 'attempt' : 'attempts'} '
                              'so far. After ${security.status.freeAttempts}, '
                              'there is a growing wait.'
                          : 'After ${security.status.freeAttempts} wrong attempts '
                              'there is a growing wait, up to five minutes.',
                    ),
                    SettingsTile(
                      icon: protection.isOn
                          ? Icons.play_circle_outline
                          : Icons.pause_circle_outline,
                      title: 'Background monitoring',
                      subtitle: protection.isOn
                          ? 'Running. Locked apps ask for your PIN when opened.'
                          : 'Not running. Locked apps open without asking.',
                    ),
                    SettingsTile(
                      icon: Icons.lock_clock,
                      title: 'When apps relock',
                      subtitle: 'As soon as you leave the app, and whenever the '
                          'screen turns off.',
                    ),
                  ],
                );
              },
            ),
            const SectionHeader('Privacy'),
            ListenableBuilder(
              listenable: securityController,
              builder: (context, _) {
                final status = securityController.state.status;
                final granted = status.isNotificationAccessGranted;

                return SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: status.isNotificationPrivacyActive
                          ? Icons.notifications_off
                          : Icons.notifications_none,
                      title: 'Hide notification content',
                      // Says which precondition is unmet rather than showing a
                      // switch that looks on and quietly does nothing.
                      subtitle: switch (status.notificationPrivacyBlocker) {
                        NotificationPrivacyBlocker.none => switch (status) {
                          _ when status.notificationsHidden > 0 =>
                            'Active. ${status.notificationsHidden} hidden so far.',
                          _ when status.notificationsSeen > 0 =>
                            'Active, but nothing has matched yet. Only locked '
                                'apps you are not currently in are hidden.',
                          _ =>
                            'Active. Notifications from locked apps will show '
                                'only the app name until you unlock them.',
                        },
                        NotificationPrivacyBlocker.noAccess =>
                          'Needs notification access before it can work.',
                        NotificationPrivacyBlocker.off =>
                          'Notifications from locked apps show their content.',
                        NotificationPrivacyBlocker.protectionOff =>
                          'Waiting: turn protection on, otherwise nothing is '
                              'locked to hide.',
                        NotificationPrivacyBlocker.noLockedApps =>
                          'Waiting: lock at least one app for this to apply to.',
                      },
                      isEnabled: granted,
                      trailing: Semantics(
                        label: 'Hide notification content',
                        child: Switch(
                          key: notificationPrivacyKey,
                          value: status.isNotificationPrivacyEnabled,
                          onChanged: granted
                              ? (value) => _setNotificationPrivacy(context, value)
                              : null,
                        ),
                      ),
                    ),
                    if (!granted)
                      SettingsTile(
                        key: notificationAccessKey,
                        icon: Icons.open_in_new,
                        title: 'Grant notification access',
                        subtitle: 'Opens Android settings. Samir Lock reads which '
                            'app a notification came from, never what it says.',
                        onTap: () => _openNotificationAccess(context),
                      ),
                  ],
                );
              },
            ),
            const SectionHeader('Permissions'),
            ListenableBuilder(
              listenable: permissionsController,
              builder: (context, _) {
                final snapshot = permissionsController.state.snapshot;
                final missing = snapshot.missingRequired.length +
                    snapshot.missingRecommended.length;

                return SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: missing == 0
                          ? Icons.verified_user_outlined
                          : Icons.warning_amber_rounded,
                      title: 'Android permissions',
                      subtitle: missing == 0
                          ? 'Everything Samir Lock needs is granted.'
                          : '$missing ${missing == 1 ? 'permission needs' : 'permissions need'} '
                              'your attention.',
                      onTap: onOpenPermissions,
                    ),
                  ],
                );
              },
            ),
            const SectionHeader('About'),
            const SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.wifi_off_outlined,
                  title: 'Works offline',
                  subtitle: 'No account, no cloud, no internet access. Your PIN '
                      'and your app list never leave this phone.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
