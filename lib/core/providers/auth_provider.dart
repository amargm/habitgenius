import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/entitlement_service.dart';
import '../services/purchase_service.dart';
import 'settings_provider.dart';
// ── Purchase service provider ─────────────────────────────────

final purchaseServiceProvider = Provider<PurchaseService>(
  (_) => PurchaseService.instance,
);
// ── Service ───────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(sharedPreferencesProvider));
});

// ── State ──────────────────────────────────────────────────

class AuthState {
  final AppUser? user;
  final bool isLoading;
  final String? error;
  final bool isPro;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isPro = false,
  });

  bool get isGuest => user?.isGuest == true;
  bool get isAuthenticated => user != null && !user!.isGuest;

  UserTier get tier {
    if (user == null || user!.isGuest) return UserTier.guest;
    if (isPro) return UserTier.pro;
    return UserTier.registered;
  }
}

// ── Notifier ──────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _service;

  AuthNotifier(this._service) : super(const AuthState());

  /// Restores a previously saved session. Called by [SplashScreen] on startup.
  Future<void> restore() async {
    state = AuthState(isLoading: true);
    try {
      final user = await _service.restoreSession();
      // SharedPreferences gives us instant, offline-safe Pro status.
      final localIsPro = PurchaseService.instance.isPro;
      state = AuthState(user: user, isPro: localIsPro);

      // Then verify against Firestore (authoritative server-side record).
      // Only meaningful for signed-in users — guest has no Firebase UID.
      if (user != null && !user.isGuest) {
        final serverIsPro = await EntitlementService.instance.checkPro();
        if (serverIsPro != localIsPro) {
          // Server wins: sync SharedPreferences to match.
          await PurchaseService.instance.syncProFromServer(isPro: serverIsPro);
          state = AuthState(user: user, isPro: serverIsPro);
        }
      }
    } catch (_) {
      state = const AuthState();
    }
  }

  /// Launches the Google Sign-In UI and saves the resulting session.
  Future<AppUser> signInWithGoogle() async {
    state = AuthState(isLoading: true);
    try {
      final user = await _service.signInWithGoogle();
      // After a fresh sign-in always check the server — the user may have
      // purchased Pro on another device or after a reinstall.
      final serverIsPro = await EntitlementService.instance.checkPro();
      if (serverIsPro) {
        await PurchaseService.instance.syncProFromServer(isPro: true);
      }
      state = AuthState(user: user, isPro: serverIsPro);
      return user;
    } catch (e) {
      state = AuthState(error: e.toString());
      rethrow;
    }
  }

  /// Creates and saves a guest session (no account required).
  Future<void> continueAsGuest() async {
    state = AuthState(isLoading: true);
    try {
      final user = await _service.continueAsGuest();
      state = AuthState(user: user);
    } catch (e) {
      state = AuthState(error: e.toString());
      rethrow;
    }
  }

  /// Signs out and clears the session state.
  Future<void> signOut() async {
    await _service.signOut();
    state = const AuthState();
  }

  /// Called after a successful IAP purchase to elevate the user to Pro.
  void upgradeToPro() {
    state = AuthState(user: state.user, isPro: true);
  }
}

// ── Provider ──────────────────────────────────────────────

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
