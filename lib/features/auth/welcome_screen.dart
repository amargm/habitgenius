import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/data_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/router/app_router.dart';

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
      final msg =
          e.toString().contains('cancelled')
              ? 'Sign-in cancelled.'
              : 'Sign-in failed. Check your connection and try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<bool> _showGuestUpgradeDialog() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                backgroundColor: AppColors.bgCard,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start guest session. Please try again.')),
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
                'Track habits, focus, mood, journal\nand expenses â€” all in one place.',
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
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Continue as Guest',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child:
          isLoading
              ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
              : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/google_logo.png',
                    width: 20,
                    height: 20,
                    errorBuilder:
                        (_, __, ___) => const Icon(
                          Icons.login,
                          size: 20,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Sign in with Google',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
    );
  }
}
