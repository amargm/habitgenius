import 'package:flutter/material.dart';

/// Lightweight toast helper that shows a styled, short-lived SnackBar.
///
/// Usage:
///   AppToast.show(context, 'Saved ✓');
///   AppToast.show(context, 'Error occurred', type: ToastType.error);
enum ToastType { info, success, error }

class AppToast {
  AppToast._();

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    IconData icon;
    Color iconColor;
    switch (type) {
      case ToastType.success:
        icon = Icons.check_circle_outline_rounded;
        iconColor = const Color(0xFF2ECC71);
      case ToastType.error:
        icon = Icons.error_outline_rounded;
        iconColor = const Color(0xFFE17055);
      case ToastType.info:
        icon = Icons.info_outline_rounded;
        iconColor = const Color(0xFFA0A0A8);
    }

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1800),
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 92),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
