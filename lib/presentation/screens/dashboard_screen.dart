import 'package:flutter/material.dart';

import '../../application/app_list_controller.dart';
import '../../application/permissions_controller.dart';
import '../../application/protection_controller.dart';
import '../../application/security_controller.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/status_hero_card.dart';

/// The first thing the user sees: is everything protected, and what to do next.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.appListController,
    required this.protectionController,
    required this.securityController,
    required this.permissionsController,
    required this.onManageApps,
    required this.onOpenSecurity,
    required this.onOpenPermissions,
    required this.onProtectionChanged,
  });

  final AppListController appListController;
  final ProtectionController protectionController;
  final SecurityController securityController;
  final PermissionsController permissionsController;

  final VoidCallback onManageApps;
  final VoidCallback onOpenSecurity;
  final VoidCallback onOpenPermissions;
  final ValueChanged<bool> onProtectionChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Samir Lock')),
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
            // Each card listens only to what it needs, so a change in one does
            // not rebuild the rest of the dashboard.
            ListenableBuilder(
              listenable: Listenable.merge([
                protectionController,
                appListController,
              ]),
              builder: (context, _) => StatusHeroCard(
                state: protectionController.state,
                lockedCount: appListController.state.lockedCount,
                onChanged: onProtectionChanged,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ListenableBuilder(
              listenable: permissionsController,
              builder: (context, _) {
                final snapshot = permissionsController.state.snapshot;
                if (snapshot.isReady) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _WarningCard(
                    message: 'Samir Lock is missing a permission it needs to '
                        'lock your apps.',
                    actionLabel: 'Review',
                    onAction: onOpenPermissions,
                  ),
                );
              },
            ),
            ListenableBuilder(
              listenable: Listenable.merge([
                appListController,
                securityController,
              ]),
              builder: (context, _) {
                final appState = appListController.state;
                final security = securityController.state;

                // IntrinsicHeight so the three chips match height even when one
                // wraps onto a second line; a plain stretch has no bounded
                // height to stretch to inside a scrolling list.
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: StatChip(
                          icon: Icons.lock_outline,
                          label: 'Locked apps',
                          value: '${appState.lockedCount}',
                          isPositive: appState.lockedCount > 0 ? true : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: StatChip(
                          icon: security.hasPin
                              ? Icons.password
                              : Icons.key_off_outlined,
                          label: 'Unlock PIN',
                          value: security.hasPin ? 'Set' : 'Not set',
                          isPositive: security.hasPin,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: StatChip(
                          icon: security.biometricsActive
                              ? Icons.fingerprint
                              : Icons.fingerprint_outlined,
                          label: 'Fingerprint',
                          value: security.biometricsActive ? 'On' : 'Off',
                          isPositive: security.biometricsActive ? true : null,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SectionHeader('Protected apps'),
            ListenableBuilder(
              listenable: appListController,
              builder: (context, _) => LockedAppsStrip(
                apps: appListController.state.lockedApps,
                onManage: onManageApps,
              ),
            ),
            const SectionHeader('Quick actions'),
            QuickActionTile(
              icon: Icons.apps_outlined,
              title: 'Manage locked apps',
              subtitle: 'Choose which apps ask for your PIN.',
              onTap: onManageApps,
            ),
            const SizedBox(height: AppSpacing.md),
            QuickActionTile(
              icon: Icons.security_outlined,
              title: 'Security settings',
              subtitle: 'PIN, fingerprint and permissions.',
              onTap: onOpenSecurity,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Samir Lock works entirely on this phone. Nothing is uploaded and '
              'it never connects to the internet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        color: colorScheme.errorContainer.withValues(alpha: 0.4),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
