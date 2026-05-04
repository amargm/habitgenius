import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_colors.dart';

/// Centralised runtime permission requests for HabitGenius.
///
/// All permission prompts go through this service so the UI stays consistent
/// and every OS dialog is preceded by a clear in-app rationale sheet.
///
/// Android permission map:
///   POST_NOTIFICATIONS  — API 33+ runtime grant required
///   SCHEDULE_EXACT_ALARM — API 31-32 (Android 12) user grant via Settings
///   USE_EXACT_ALARM     — API 33+ auto-granted when declared in manifest
///   READ/WRITE_EXTERNAL_STORAGE — SAF (Storage Access Framework) handles
///     folder access without needing runtime grants; manifest entries kept
///     for API ≤ 29 compatibility only.
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  // ── Notifications ─────────────────────────────────────────

  /// Raw notification permission status (granted / denied / permanentlyDenied).
  Future<PermissionStatus> get notificationStatus async {
    if (!Platform.isAndroid) return PermissionStatus.granted;
    return Permission.notification.status;
  }

  /// Returns true if POST_NOTIFICATIONS is already granted (or the platform
  /// doesn't require the runtime grant, e.g. Android < 13).
  Future<bool> get notificationsGranted async {
    if (!Platform.isAndroid) return true;
    return (await Permission.notification.status).isGranted;
  }

  /// Shows a rationale sheet, then requests POST_NOTIFICATIONS.
  ///
  /// Returns true when the permission is ultimately granted.
  /// Safe to call multiple times — skips rationale if already granted.
  Future<bool> requestNotifications(BuildContext context) async {
    if (await notificationsGranted) return true;

    // Show rationale before the OS dialog.
    if (!context.mounted) return false;
    final proceed = await _showRationaleSheet(
      context: context,
      icon: Icons.notifications_active_rounded,
      title: 'Enable habit reminders',
      body:
          'HabitGenius sends you a gentle nudge at your chosen time each day so you never miss a habit.\n\nNo spam — only the reminders you set.',
      allowLabel: 'Enable notifications',
    );
    if (!proceed || !context.mounted) return false;

    final status = await Permission.notification.request();

    if (status.isPermanentlyDenied && context.mounted) {
      await _showPermanentlyDeniedDialog(
        context: context,
        permissionName: 'Notifications',
      );
    }

    return status.isGranted;
  }

  // ── Exact alarm (Android 12 only) ─────────────────────────

  /// Whether the app can schedule exact alarms.
  ///
  /// On Android 13+ [USE_EXACT_ALARM] is auto-granted when declared in the
  /// manifest, so we always return true. On Android < 12 exact alarms need
  /// no permission at all. Only Android 12 (API 31-32) needs a user grant.
  Future<bool> get exactAlarmGranted async {
    if (!Platform.isAndroid) return true;
    // On API 33+ USE_EXACT_ALARM is granted implicitly via manifest.
    // On API < 31 no permission is needed.
    // Only API 31-32 (Android 12) requires checking SCHEDULE_EXACT_ALARM.
    return (await Permission.scheduleExactAlarm.status).isGranted;
  }

  /// Requests SCHEDULE_EXACT_ALARM on Android 12 devices.
  ///
  /// On Android 13+ and earlier, this is a no-op (already granted).
  /// On Android 12, the user is sent to the system settings page for exact
  /// alarms — there is no in-app dialog for this permission.
  Future<bool> requestExactAlarm(BuildContext context) async {
    if (await exactAlarmGranted) return true;

    if (!context.mounted) return false;
    final proceed = await _showRationaleSheet(
      context: context,
      icon: Icons.alarm_rounded,
      title: 'Allow precise reminders',
      body:
          'To fire your habit reminders at the exact time you choose, HabitGenius needs permission to schedule precise alarms.\n\nYou\'ll be taken to your device\'s Settings page to enable this.',
      allowLabel: 'Go to Settings',
    );
    if (!proceed || !context.mounted) return false;

    final status = await Permission.scheduleExactAlarm.request();
    // If still not granted (user navigated away or denied), offer app settings.
    if (!status.isGranted && context.mounted) {
      await openAppSettings();
    }
    return status.isGranted;
  }

  // ── Convenient combined request ───────────────────────────

  /// Requests both notification and exact-alarm permissions in sequence.
  ///
  /// Designed to be called once after first launch, at the point of need.
  /// The exact-alarm request is skipped if notifications were denied (moot).
  Future<void> requestAllRequired(BuildContext context) async {
    await requestNotifications(context);
    if (!context.mounted) return;
    final notifGranted = await notificationsGranted;
    if (notifGranted && context.mounted) {
      await requestExactAlarm(context);
    }
  }

  // ── Private helpers ───────────────────────────────────────

  /// Shows a bottom sheet with a rationale before triggering the OS dialog.
  /// Returns true when the user presses the allow button.
  Future<bool> _showRationaleSheet({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String body,
    required String allowLabel,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => _RationaleSheet(
            icon: icon,
            title: title,
            body: body,
            allowLabel: allowLabel,
          ),
    );
    return result ?? false;
  }

  /// Shows an alert explaining the permission was permanently denied and
  /// offers to open the app's system settings page.
  Future<void> _showPermanentlyDeniedDialog({
    required BuildContext context,
    required String permissionName,
  }) async {
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('$permissionName permission required'),
            content: Text(
              '$permissionName permission was denied. '
              'You can enable it in Settings → Apps → HabitGenius → Permissions.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Not now'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }
}

// ── Rationale bottom sheet ────────────────────────────────

class _RationaleSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String allowLabel;

  const _RationaleSheet({
    required this.icon,
    required this.title,
    required this.body,
    required this.allowLabel,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).viewInsets.bottom + 36,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: primary),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          const SizedBox(height: 12),

          // Body
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.65)
                      : Colors.black.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 32),

          // Allow button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                allowLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Not now
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Not now',
                style: TextStyle(
                  color:
                      isDark
                          ? Colors.white.withValues(alpha: 0.45)
                          : Colors.black.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
