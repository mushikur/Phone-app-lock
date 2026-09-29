import 'package:flutter/material.dart';

/// Dashboard header summarising how many apps are currently locked.
class LockSummaryCard extends StatelessWidget {
  const LockSummaryCard({
    super.key,
    required this.lockedCount,
    required this.totalCount,
  });

  final int lockedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = totalCount == 0 ? 0.0 : lockedCount / totalCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            Color.alphaBlend(
              colorScheme.tertiaryContainer.withValues(alpha: 0.55),
              colorScheme.primaryContainer,
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Protected apps',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: Text(
                        '$lockedCount of $totalCount locked',
                        key: ValueKey('$lockedCount/$totalCount'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: progress),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor:
                    colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(
                  colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
