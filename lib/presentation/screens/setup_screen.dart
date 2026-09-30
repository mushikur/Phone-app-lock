import 'package:flutter/material.dart';

import '../../application/permissions_controller.dart';
import '../../application/security_controller.dart';
import '../../application/setup_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/app_permission.dart';
import '../../domain/entities/setup_item.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/setup_item_tile.dart';

/// Everything Samir Lock needs, in one place.
///
/// Used both as the first thing a new user sees and as the page reached from
/// Security later, so there is only ever one screen to understand.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.setupController,
    required this.permissionsController,
    required this.securityController,
    required this.isFirstRun,
    required this.onContinue,
  });

  final SetupController setupController;
  final PermissionsController permissionsController;
  final SecurityController securityController;

  /// Changes the wording and shows the Continue button.
  final bool isFirstRun;
  final VoidCallback onContinue;

  static const Key continueKey = Key('setup-continue');

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    widget.setupController.refresh();
    // Each of these is changed in Android settings, so coming back is the only
    // moment the app can learn what happened.
    _lifecycleListener = AppLifecycleListener(
      onResume: () => widget.setupController.refresh(showSpinner: false),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _act(SetupItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await _perform(item);
    await widget.setupController.refresh(showSpinner: false);

    if (error == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  Future<String?> _perform(SetupItem item) async {
    switch (item.id) {
      case SetupItemId.usageAccess:
        return widget.permissionsController.grant(AppPermission.usageAccess);
      case SetupItemId.displayOverOtherApps:
        return widget.permissionsController
            .grant(AppPermission.displayOverOtherApps);
      case SetupItemId.notifications:
        return widget.permissionsController.grant(AppPermission.notifications);
      case SetupItemId.background:
        return widget.permissionsController
            .grant(AppPermission.batteryOptimization);
      case SetupItemId.notificationAccess:
        return widget.securityController.openNotificationAccess();
      case SetupItemId.notificationPopups:
        final warnings = widget.securityController.state.popupWarnings;
        if (warnings.isEmpty) return null;
        return widget.securityController.openChannelSettings(warnings.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFirstRun ? 'Welcome' : 'Setup'),
        automaticallyImplyLeading: !widget.isFirstRun,
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: widget.setupController,
          builder: (context, _) {
            final state = widget.setupController.state;

            if (state.isLoading && state.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    children: [
                      _Header(state: state, isFirstRun: widget.isFirstRun),
                      const SizedBox(height: AppSpacing.xl),
                      if (state.requiredItems.isNotEmpty) ...[
                        const SectionHeader('Required'),
                        for (final item in state.requiredItems)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.md),
                            child: SetupItemTile(
                              item: item,
                              onAction: () => _act(item),
                            ),
                          ),
                      ],
                      if (state.recommendedItems.isNotEmpty) ...[
                        const SectionHeader('Recommended'),
                        for (final item in state.recommendedItems)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.md),
                            child: SetupItemTile(
                              item: item,
                              onAction: () => _act(item),
                            ),
                          ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Samir Lock works entirely on this phone. Nothing is '
                        'uploaded and it never connects to the internet.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                if (widget.isFirstRun)
                  _ContinueBar(state: state, onContinue: widget.onContinue),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.isFirstRun});

  final SetupState state;
  final bool isFirstRun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ready = state.isReady;
    final outstanding = state.outstandingCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: ready
                ? colorScheme.primaryContainer
                : colorScheme.errorContainer.withValues(alpha: 0.5),
          ),
          child: Icon(
            ready ? Icons.verified_user_outlined : Icons.lock_outline,
            size: 26,
            color: ready
                ? colorScheme.onPrimaryContainer
                : colorScheme.onErrorContainer,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          isFirstRun ? 'Lock your private apps' : 'Setup',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          isFirstRun
              ? 'Samir Lock asks for your PIN before a private app opens. '
                  'Android needs you to approve a couple of things first, and '
                  'here is what each one is for.'
              : 'Everything Samir Lock needs, in one place.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Status conveyed by icon and words, not colour alone.
        Row(
          children: [
            Icon(
              ready ? Icons.check_circle : Icons.error_outline,
              size: 18,
              color: ready ? colorScheme.primary : colorScheme.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              ready
                  ? (outstanding == 0
                      ? 'Ready'
                      : 'Ready, $outstanding optional step left')
                  : outstanding == 1
                      ? '1 action required'
                      : '$outstanding actions required',
              style: theme.textTheme.titleSmall?.copyWith(
                color: ready ? colorScheme.primary : colorScheme.error,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.state, required this.onContinue});

  final SetupState state;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = state.isReady;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        children: [
          if (!ready)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'Allow the required items above to continue.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: SetupScreen.continueKey,
              onPressed: ready ? onContinue : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
