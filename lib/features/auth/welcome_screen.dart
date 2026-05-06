import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/data_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/app_toast.dart';

/// Auth entry point: Google Sign-In or Continue as Guest.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _signingIn = false;

  Future<void> _onGoogleSignIn() async {
    // If guest data exists, warn that it won't carry over.
    final dataService = ref.read(dataServiceProvider);
    final guestPath = await dataService.resolveFilePath(
      isGuest: true,
      customDirPath: null,
    );
    final hasGuestData = await dataService.fileExists(guestPath);

    if (!mounted) return;

    if (hasGuestData) {
      final confirmed = await _showGuestUpgradeDialog();
      if (!confirmed || !mounted) return;
    }

    setState(() => _signingIn = true);
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
      if (!mounted) return;
      // New registered user: check if they've set up a data folder.
      final prefs = ref.read(sharedPreferencesProvider);
      final dataDir = prefs.getString(PrefKeys.dataFilePath);
      if (dataDir == null || dataDir.isEmpty) {
        context.go(AppRoutes.onboarding);
      } else {
        await ref
            .read(dataNotifierProvider.notifier)
            .load(isGuest: false, customDir: dataDir);
        if (mounted) context.go(AppRoutes.home);
      }
    } catch (e) {
      if (!mounted) return;
      final String msg;
      final s = e.toString();
      if (s.contains('cancelled') || s.contains('sign_in_cancelled')) {
        msg = 'Sign-in cancelled.';
      } else if (s.contains('sign_in_failed') ||
          s.contains('10:') ||
          s.contains('DEVELOPER_ERROR')) {
        msg =
            'Sign-in failed: SHA-1 certificate not registered in Firebase. '
            'Error: $s';
      } else {
        msg = 'Sign-in failed: $s';
      }
      AppToast.show(context, msg, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<bool> _showGuestUpgradeDialog() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Sign in with Google?'),
                content: const Text(
                  'Signing in will start fresh with a new data file.\n\n'
                  'Your Guest data will remain on this device but will not carry '
                  'over. You can manually export it from Settings if needed.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Continue'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<void> _onContinueAsGuest() async {
    setState(() => _signingIn = true);
    try {
      await ref.read(authNotifierProvider.notifier).continueAsGuest();
      await ref
          .read(dataNotifierProvider.notifier)
          .load(isGuest: true, customDir: null);
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        'Could not start guest session. Please try again.',
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              // Logo
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primary, const Color(0xFF00CEC9)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.4),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'HabitGenius',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.displayLarge?.copyWith(letterSpacing: -1),
              ),
              const SizedBox(height: 12),
              Text(
                'Track habits, focus, mood, journal\nand expenses — all in one place.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              const Spacer(flex: 3),
              // Google Sign-In
              _GoogleSignInButton(
                onTap: _signingIn ? null : _onGoogleSignIn,
                isLoading: _signingIn,
              ),
              const SizedBox(height: 14),
              // Continue as Guest
              OutlinedButton(
                onPressed: _signingIn ? null : _onContinueAsGuest,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Continue as Guest',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Guest: 1 habit · 5 journal entries · no expenses or mood tracking',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Guest data is stored locally only and is not\nmigrated if you sign in later.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const _GoogleSignInButton({required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        // Google branding requires a neutral/white background so the logo
        // colours are visible and the brand is clearly recognised.
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF3C4043),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFDADCE0), width: 1),
        ),
        elevation: 0,
      ),
      child:
          isLoading
              ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
                ),
              )
              : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google "G" logo drawn in code — four-colour quadrant design
                  _GoogleGLogo(),
                  const SizedBox(width: 12),
                  const Text(
                    'Sign in with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3C4043),
                    ),
                  ),
                ],
              ),
    );
  }
}

/// Draws the Google "G" logo using four brand colours, matching the official
/// Google Sign-In button specification.
class _GoogleGLogo extends StatelessWidget {
  const _GoogleGLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Blue (top-right arc)
    canvas.drawArc(
      rect,
      -1.047, // -60°
      2.094,  // 120°
      true,
      Paint()..color = const Color(0xFF4285F4),
    );
    // Red (top-left arc)
    canvas.drawArc(
      rect,
      -3.665, // -210°
      2.094,  // 120°
      true,
      Paint()..color = const Color(0xFFDB4437),
    );
    // Yellow (bottom-left arc)
    canvas.drawArc(
      rect,
      2.618, // 150°
      1.047, // 60°
      true,
      Paint()..color = const Color(0xFFF4B400),
    );
    // Green (bottom-right arc)
    canvas.drawArc(
      rect,
      1.047, // 60°
      1.571, // 90°
      true,
      Paint()..color = const Color(0xFF0F9D58),
    );

    // White centre circle to create the "G" ring effect
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.56,
      Paint()..color = Colors.white,
    );

    // White bar for the horizontal stem of the "G"
    final barLeft = cx;
    final barRight = cx + r * 0.95;
    final barTop = cy - r * 0.14;
    final barBottom = cy + r * 0.14;
    canvas.drawRect(
      Rect.fromLTRB(barLeft, barTop, barRight, barBottom),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
