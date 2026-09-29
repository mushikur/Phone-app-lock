import 'package:flutter/material.dart';

import '../../application/protection_controller.dart';
import '../../core/theme/app_theme.dart';

/// The headline card: is Samir Lock protecting anything right now.
class StatusHeroCard extends StatelessWidget {
  const StatusHeroCard({
    super.key,
    required this.state,
    required this.lockedCount,
    required this.onChanged,
  });

  final ProtectionState state;
  final int lockedCount;
  final ValueChanged<bool> onChanged;

  static const Key switchKey = Key('hero-protection-switch');

  bool get _isOn => state.isOn;

  String get _headline => _isOn ? 'Protected' : 'Not protected';

  String get _detail {
    if (!state.canRun) {
      return 'A permission is missing, so nothing is being watched.';
    }
    if (!state.hasPin) {
      return 'Create a PIN to turn protection on.';
    }
    if (!state.isEnabled) {
      return 'Your locked apps will open without asking.';
    }
    if (state.isEnabled && !state.isRunning) {
      return 'Starting up...';
    }
    if (lockedCount == 0) {
      return 'Protection is on. Choose an app to lock.';
    }
    return lockedCount == 1
        ? '1 app asks to be unlocked when opened.'
        : '$lockedCount apps ask to be unlocked when opened.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isOn
              ? [
                  colorScheme.primaryContainer,
                  Color.alphaBlend(
                    colorScheme.tertiaryContainer.withValues(alpha: 0.55),
                    colorScheme.primaryContainer,
                  ),
                ]
              : [
                  colorScheme.surfaceContainerHighest,
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _isOn
                      ? colorScheme.onPrimaryContainer.withValues(alpha: 0.12)
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.10),
                ),
                child: Icon(
                  _isOn ? Icons.shield : Icons.shield_outlined,
                  size: 26,
                  color: _isOn
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _headline,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: _isOn
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _detail,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _isOn
                            ? colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.85)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
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
                Semantics(
                  label: 'Protection',
                  child: Switch(
                    key: switchKey,
                    value: _isOn,
                    onChanged:
                        state.canRun && state.hasPin ? onChanged : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
