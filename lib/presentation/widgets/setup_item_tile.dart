import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/setup_item.dart';

/// One row on the setup screen: what it is, why, where it stands, and the one
/// button that deals with it.
class SetupItemTile extends StatelessWidget {
  const SetupItemTile({
    super.key,
    required this.item,
    required this.onAction,
  });

  final SetupItem item;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final done = !item.needsAction;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        color: done
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status reads from the icon and the label as well as the colour.
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: done
                    ? colorScheme.primary
                    : (item.isRequired
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          done
                              ? 'Enabled'
                              : (item.isRequired ? 'Required' : 'Optional'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: done
                                ? colorScheme.primary
                                : (item.isRequired
                                    ? colorScheme.error
                                    : colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        item.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (item.detail != null && item.needsAction) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              ),
              child: Text(
                item.detail!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          if (item.needsAction) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                key: Key('setup-action-${item.id.name}'),
                onPressed: onAction,
                child: Text(item.actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
