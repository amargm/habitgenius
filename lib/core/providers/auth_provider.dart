import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import 'settings_provider.dart';

// ── Service ───────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(sharedPreferencesProvider));
});

// ── State ──────────────────────────────────────────────────

class AuthState {
  final AppUser? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isGuest => user?.isGuest == true;
  bool get isAuthenticated => user != null && !user!.isGuest;

  /// Derived tier used for feature-gating throughout the app.
  // TODO(sprint6): elevate to [UserTier.pro] when purchase is confirmed.
  UserTier get tier {
    if (user == null || user!.isGuest) return UserTier.guest;
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
      state = AuthState(user: user);
    } catch (_) {
      state = const AuthState();
    }
  }

  /// Launches the Google Sign-In UI and saves the resulting session.
  Future<AppUser> signInWithGoogle() async {
    state = AuthState(isLoading: true);
    try {
      final user = await _service.signInWithGoogle();
      state = AuthState(user: user);
      return user;
    } catch (e) {
      state = AuthState(error: e.toString());
      rethrow;
    }
  }

  /// Creates and saves a guest session (no account required).
  Future<void> continueAsGuest() async {
    state = AuthState(isLoading: true);
    final user = await _service.continueAsGuest();
    state = AuthState(user: user);
  }

  /// Signs out and clears the session state.
  Future<void> signOut() async {
    await _service.signOut();
    state = const AuthState();
  }
}

// ── Provider ──────────────────────────────────────────────

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
