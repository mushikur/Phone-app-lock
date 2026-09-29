import 'package:flutter/material.dart';

import '../../application/security_controller.dart';
import '../../domain/repositories/security_repository.dart';

/// PIN and biometric status, with the way into the native PIN screen.
class SecurityCard extends StatelessWidget {
  const SecurityCard({
    super.key,
    required this.state,
    required this.onSetUpPin,
  });

  final SecurityState state;
  final VoidCallback onSetUpPin;

  static const Key actionKey = Key('pin-setup-button');

  String get _subtitle {
    if (!state.hasPin) {
      return 'Create a PIN so your locked apps can ask for it.';
    }
    return switch (state.status.biometric) {
      BiometricAvailability.available =>
        'PIN ready. Fingerprint can be used to unlock too.',
      BiometricAvailability.notEnrolled =>
        'PIN ready. Add a fingerprint in Android settings to unlock faster.',
      BiometricAvailability.temporarilyUnavailable =>
        'PIN ready. Fingerprint is unavailable right now.',
      BiometricAvailability.unavailable => 'PIN ready.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasPin = state.hasPin;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: hasPin
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.38)
            : colorScheme.errorContainer.withValues(alpha: 0.35),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: hasPin
                  ? colorScheme.primary.withValues(alpha: 0.16)
                  : colorScheme.error.withValues(alpha: 0.14),
            ),
            child: Icon(
              hasPin ? Icons.password : Icons.key_off_outlined,
              size: 20,
              color: hasPin ? colorScheme.primary : colorScheme.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPin ? 'Unlock PIN' : 'No PIN yet',
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
          const SizedBox(width: 8),
          TextButton(
            key: actionKey,
            onPressed: onSetUpPin,
            child: Text(hasPin ? 'Change' : 'Set up'),
          ),
        ],
      ),
    );
  }
}
