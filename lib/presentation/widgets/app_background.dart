import 'package:flutter/material.dart';

/// The app's background: a soft brand-tinted wash, with the Samir wordmark
/// behind the content.
///
/// The tint is derived from the active colour scheme rather than hard-coded, so
/// it stays correct in light and dark without a second palette to maintain. The
/// watermark sits far enough back to be decoration, never something competing
/// with the text in front of it.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.07),
              colorScheme.surface,
            ),
            colorScheme.surface,
            Color.alphaBlend(
              colorScheme.tertiary.withValues(alpha: isDark ? 0.10 : 0.05),
              colorScheme.surface,
            ),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: 8,
            child: IgnorePointer(
              // Decoration only: it must never be read out or focused.
              child: ExcludeSemantics(
                child: Text(
                  'SAMIR',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: colorScheme.primary
                        .withValues(alpha: isDark ? 0.055 : 0.04),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
