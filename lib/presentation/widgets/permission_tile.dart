import 'package:flutter/material.dart';

import '../../domain/entities/app_permission.dart';

/// One permission with its plain-language explanation and grant action.
class PermissionTile extends StatelessWidget {
  const PermissionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.isRequired,
    required this.isBusy,
    required this.onGrant,
  });

  final IconData icon;
  final String title;
  final String description;
  final PermissionStatus status;
  final bool isRequired;
  final bool isBusy;
  final VoidCallback onGrant;

  bool get _isSatisfied => status.isSatisfied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _isSatisfied
            ? colorScheme.primaryContainer.withValues(alpha: 0.32)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusBadge(icon: icon, isSatisfied: _isSatisfied),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusLabel(
                          status: status,
                          isRequired: isRequired,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_isSatisfied) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: isBusy ? null : onGrant,
                child: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Allow'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.icon, required this.isSatisfied});

  final IconData icon;
  final bool isSatisfied;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isSatisfied
            ? colorScheme.primary.withValues(alpha: 0.16)
            : colorScheme.surfaceContainerHighest,
      ),
      child: Icon(
        isSatisfied ? Icons.check_rounded : icon,
        color: isSatisfied ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status, required this.isRequired});

  final PermissionStatus status;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (String label, Color color) = switch (status) {
      PermissionStatus.granted => ('Granted', colorScheme.primary),
      PermissionStatus.unsupported => ('Not needed', colorScheme.onSurfaceVariant),
      PermissionStatus.denied => isRequired
          ? ('Required', colorScheme.error)
          : ('Recommended', colorScheme.onSurfaceVariant),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          status.isSatisfied
              ? Icons.check_circle
              : Icons.radio_button_unchecked,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
