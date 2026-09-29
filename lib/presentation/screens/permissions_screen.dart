import 'package:flutter/material.dart';

import '../../application/permissions_controller.dart';
import '../../domain/entities/app_permission.dart';
import '../widgets/permission_tile.dart';
import '../widgets/state_views.dart';

/// Plain-language copy for one permission. Kept in the presentation layer so the
/// domain stays free of user-facing wording.
class _PermissionCopy {
  const _PermissionCopy({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

const Map<AppPermission, _PermissionCopy> _copy = {
  AppPermission.usageAccess: _PermissionCopy(
    icon: Icons.visibility_outlined,
    title: 'See which app is open',
    description:
        'Samir Lock needs to know which app you just opened so it can ask for '
        'your PIN at the right moment. It never looks inside your apps.',
  ),
  AppPermission.displayOverOtherApps: _PermissionCopy(
    icon: Icons.layers_outlined,
    title: 'Show the lock screen',
    description:
        'Lets Samir Lock place its lock screen on top of the app you are '
        'opening, so the app stays hidden until you unlock it.',
  ),
  AppPermission.notifications: _PermissionCopy(
    icon: Icons.notifications_outlined,
    title: 'Show a running notice',
    description:
        'Android needs to show a small notice while protection is switched on. '
        'It also stops your phone from shutting Samir Lock down.',
  ),
  AppPermission.batteryOptimization: _PermissionCopy(
    icon: Icons.battery_charging_full_outlined,
    title: 'Keep running in the background',
    description:
        'Some phones pause apps to save power, which can leave your apps '
        'unlocked. Turning battery saving off for Samir Lock keeps it reliable.',
  ),
};

/// Onboarding screen where the user grants the permissions Samir Lock needs.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({
    super.key,
    required this.controller,
    required this.onContinue,
  });

  final PermissionsController controller;

  /// Called when the user continues with every required permission granted.
  final VoidCallback onContinue;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // The user grants these in Android Settings, so the only reliable moment to
    // re-check is when the app comes back to the foreground.
    _lifecycleListener = AppLifecycleListener(
      onResume: () => widget.controller.refresh(showSpinner: false),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _onGrant(AppPermission permission) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await widget.controller.grant(permission);
    if (error == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final state = widget.controller.state;

            if (state.status == PermissionsStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.status == PermissionsStatus.error) {
              return AppListMessageView(
                icon: Icons.error_outline,
                title: 'Could not check permissions',
                message: state.errorMessage ??
                    'Samir Lock could not read its permission settings.',
                actionLabel: 'Try again',
                onAction: widget.controller.refresh,
              );
            }

            final snapshot = state.snapshot;

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    children: [
                      _Header(isReady: snapshot.isReady),
                      const SizedBox(height: 24),
                      for (final permission in AppPermission.values)
                        PermissionTile(
                          icon: _copy[permission]!.icon,
                          title: _copy[permission]!.title,
                          description: _copy[permission]!.description,
                          status: snapshot.statusOf(permission),
                          isRequired: permission.isRequired,
                          isBusy: state.pending == permission,
                          onGrant: () => _onGrant(permission),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Samir Lock works entirely on this phone. Nothing is '
                        'uploaded and it never connects to the internet.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _ContinueBar(
                  isReady: snapshot.isReady,
                  missingCount: snapshot.missingRequired.length,
                  onContinue: widget.onContinue,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isReady});

  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: colorScheme.primaryContainer,
          ),
          child: Icon(
            isReady ? Icons.verified_user_outlined : Icons.lock_outline,
            size: 28,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          isReady ? 'You are all set' : 'Let us set up protection',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isReady
              ? 'Samir Lock has everything it needs. You can change any of '
                  'this later.'
              : 'Android asks you to approve a couple of things before an app '
                  'can lock other apps. Here is exactly what each one is for.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({
    required this.isReady,
    required this.missingCount,
    required this.onContinue,
  });

  final bool isReady;
  final int missingCount;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isReady
                ? const SizedBox.shrink()
                : Padding(
                    key: const ValueKey('hint'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      missingCount == 1
                          ? 'One more permission to go.'
                          : '$missingCount permissions still needed.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isReady ? onContinue : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
