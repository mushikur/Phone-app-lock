import 'package:flutter/material.dart';

import '../../domain/entities/installed_app.dart';

/// A single installed app with its lock toggle.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.app,
    required this.isLocked,
    required this.onToggle,
  });

  final InstalledApp app;
  final bool isLocked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isLocked
            ? colorScheme.primaryContainer.withValues(alpha: 0.38)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _AppIcon(app: app),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: isLocked,
                  onChanged: (_) => onToggle(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app});

  static const double _size = 44;

  final InstalledApp app;

  @override
  Widget build(BuildContext context) {
    final icon = app.icon;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: _size,
      height: _size,
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
              width: _size,
              height: _size,
              cacheWidth: 132,
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
