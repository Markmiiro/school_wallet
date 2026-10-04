// The two states every fetching screen shares: still loading, and could
// not load. Both are plain on purpose. An empty state is not here: what
// "nothing yet" should say depends on the screen.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

/// Grey blocks standing in for content that is on its way.
class LoadingBlocks extends StatelessWidget {
  final int count;
  final double height;

  const LoadingBlocks({super.key, this.count = 3, this.height = 64});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Container(
              height: height,
              margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(
                  duration: 1200.ms,
                  color: AppColors.surfaceContainerHighest,
                ),
        ],
      ),
    );
  }
}

/// Says what could not be loaded and offers to try again. Nothing here
/// is the parent's fault, so no red and no warning icon.
class LoadFailed extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const LoadFailed({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.level1CardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.headlineMd.copyWith(fontSize: 17)),
          const SizedBox(height: AppTheme.spaceXs),
          Text(message,
              style: AppTheme.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: AppTheme.spaceMd),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
