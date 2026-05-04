import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An authenticated user — either a Firebase/Google account or a Guest session.
class AppUser {
  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isGuest;

  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    required this.isGuest,
  });

  factory AppUser.guest() => const AppUser(id: 'guest', isGuest: true);

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isGuest,
  }) => AppUser(
    id: id ?? this.id,
    email: email ?? this.email,
    displayName: displayName ?? this.displayName,
    photoUrl: photoUrl ?? this.photoUrl,
    isGuest: isGuest ?? this.isGuest,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && other.id == id && other.isGuest == isGuest;

  @override
  int get hashCode => Object.hash(id, isGuest);
}

/// Manages authentication via Firebase Auth (Google Sign-In) and guest sessions.
///
/// Firebase Auth persists the signed-in token automatically — no manual
/// SharedPreferences needed for Google users.  Only the guest-session flag
/// is stored in SharedPreferences.
class AuthService {
  // Only the guest flag lives in SharedPreferences; everything else comes
  // from FirebaseAuth.currentUser which Firebase refreshes automatically.
  static const _kIsGuest = 'auth_is_guest';

  final SharedPreferences _prefs;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn =
      GoogleSignIn(scopes: ['email', 'profile']);

  AuthService(this._prefs);

  /// Restores a previous session on app start.
  ///
  /// Priority:
  ///   1. Firebase user (token refreshed silently by the SDK).
  ///   2. Guest flag in SharedPreferences.
  ///   3. No session → return null.
  Future<AppUser?> restoreSession() async {
    final fbUser = _auth.currentUser;
    if (fbUser != null) return _mapUser(fbUser);

    if (_prefs.getBool(_kIsGuest) == true) return AppUser.guest();

    return null;
  }

  /// Attempts a silent re-authentication (no UI).
  /// Returns null if no cached Google credential exists.
  Future<AppUser?> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return null;
      final gAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      final userCred = await _auth.signInWithCredential(credential);
      return userCred.user != null ? _mapUser(userCred.user!) : null;
    } catch (_) {
      return null;
    }
  }

  /// Launches the Google Sign-In picker and signs into Firebase.
  /// Throws if the user cancels or an error occurs.
  Future<AppUser> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Sign-in cancelled');

    final gAuth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    if (userCred.user == null) throw Exception('Firebase sign-in failed');
    return _mapUser(userCred.user!);
  }

  /// Creates and persists a guest session.
  Future<AppUser> continueAsGuest() async {
    await _prefs.setBool(_kIsGuest, true);
    return const AppUser(id: 'guest', isGuest: true);
  }

  /// Signs out of Firebase and Google, and removes the guest flag.
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
    await _prefs.remove(_kIsGuest);
  }

  // ── Helpers ───────────────────────────────────────────────

  AppUser _mapUser(User user) => AppUser(
    id: user.uid, // Firebase UID — stable across reinstalls
    email: user.email,
    displayName: user.displayName,
    photoUrl: user.photoURL,
    isGuest: false,
  );
}
