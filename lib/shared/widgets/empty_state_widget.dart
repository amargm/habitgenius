import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/data_service.dart';

/// Generic illustrated empty-state widget used across all list screens.
///
/// Usage:
/// ```dart
/// EmptyStateWidget(
///   icon: Icons.check_circle_outline_rounded,
///   title: 'No habits yet',
///   subtitle: 'Tap + to add your first habit.',
///   actionLabel: 'Add habit',
///   onAction: () => context.go(AppRoutes.addHabit),
/// )
/// ```
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: primary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(color: primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when DataNotifier is in error state — e.g. storage permission denied
/// or a corrupted data file.
class DataErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const DataErrorWidget({
    super.key,
    required this.error,
    required this.onRetry,
  });

  String get _title {
    if (error is DataCorruptedException) return 'Data file corrupted';
    return 'Could not load your data';
  }

  String get _body {
    if (error is DataCorruptedException) {
      return 'Your data file could not be read — it may have been damaged.\n\n'
          'Your in-app data is intact until you restart. '
          'Tap Retry to attempt recovery, or check your data folder.';
    }
    if (error is ArgumentError) {
      return 'The data folder path is invalid. '
          'Go to Settings → Data to reconfigure it.';
    }
    return 'Check that your data folder is accessible,\nthen tap Retry.';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.danger,
            ),
            const SizedBox(height: 16),
            Text(
              _title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
