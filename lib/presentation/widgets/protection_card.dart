import 'package:flutter/material.dart';

import '../../application/protection_controller.dart';

/// Master switch for the background guard.
class ProtectionCard extends StatelessWidget {
  const ProtectionCard({
    super.key,
    required this.state,
    required this.lockedCount,
    required this.onChanged,
  });

  final ProtectionState state;
  final int lockedCount;
  final ValueChanged<bool> onChanged;

  static const Key switchKey = Key('protection-switch');

  String get _subtitle {
    if (!state.canRun) {
      return 'Needs permission to watch your apps and show the lock screen.';
    }
    if (!state.hasPin) {
      return 'Create a PIN above to turn protection on.';
    }
    if (state.isEnabled && !state.isRunning) {
      return 'Starting up...';
    }
    if (!state.isEnabled) {
      return 'Your locked apps will open without asking.';
    }
    if (lockedCount == 0) {
      return 'Protection is on. Choose an app below to lock it.';
    }
    return lockedCount == 1
        ? 'Watching 1 app. It will ask to be unlocked when opened.'
        : 'Watching $lockedCount apps. They will ask to be unlocked when opened.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOn = state.isOn;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isOn
            ? colorScheme.secondaryContainer.withValues(alpha: 0.45)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: isOn
                  ? colorScheme.primary.withValues(alpha: 0.16)
                  : colorScheme.surfaceContainerHighest,
            ),
            child: Icon(
              isOn ? Icons.shield : Icons.shield_outlined,
              size: 20,
              color: isOn ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOn ? 'Protection is on' : 'Protection is off',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (state.isBusy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Switch(
              key: switchKey,
              value: isOn,
              onChanged: state.canRun && state.hasPin ? onChanged : null,
            ),
        ],
      ),
    );
  }
}
