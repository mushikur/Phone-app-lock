import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/installed_app.dart';

/// A small labelled fact, three of which sit in a row under the hero card.
///
/// Status is carried by an icon and a word as well as colour, so it still reads
/// correctly without colour vision.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.isPositive,
  });

  final IconData icon;
  final String label;
  final String value;

  /// null for neutral facts that are neither good nor bad.
  final bool? isPositive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Color tint = switch (isPositive) {
      true => colorScheme.primary,
      false => colorScheme.error,
      null => colorScheme.onSurfaceVariant,
    };

    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: tint),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(color: tint),
            ),
            Text(
              label,
              maxLines: 2,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable row that leads somewhere else in the app.
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget + AppSpacing.lg,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The icons of the currently locked apps, with a way through to manage them.
class LockedAppsStrip extends StatelessWidget {
  const LockedAppsStrip({
    super.key,
    required this.apps,
    required this.onManage,
  });

  final List<InstalledApp> apps;
  final VoidCallback onManage;

  static const int _maxShown = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (apps.isEmpty) {
      return QuickActionTile(
        icon: Icons.apps_outlined,
        title: 'No apps locked yet',
        subtitle: 'Choose the apps that should ask for your PIN.',
        onTap: onManage,
      );
    }

    final shown = apps.take(_maxShown).toList(growable: false);
    final extra = apps.length - shown.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  apps.length == 1 ? '1 locked app' : '${apps.length} locked apps',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton(onPressed: onManage, child: const Text('Manage')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final app in shown)
                Semantics(
                  label: '${app.appName}, locked',
                  excludeSemantics: true,
                  child: _LockedAppIcon(app: app),
                ),
              if (extra > 0)
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  child: Text(
                    '+$extra',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LockedAppIcon extends StatelessWidget {
  const _LockedAppIcon({required this.app});

  final InstalledApp app;

  @override
  Widget build(BuildContext context) {
    final icon = app.icon;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 40,
      height: 40,
      child: icon == null
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.android, color: colorScheme.onSurfaceVariant),
            )
          : Image.memory(
              icon,
              width: 40,
              height: 40,
              cacheWidth: 120,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (context, _, _) => Icon(
                Icons.android,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

/// A heading above a group of cards.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
