import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An authenticated user — either a Google account or a Guest session.
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

/// Manages Google Sign-In and guest sessions.
/// The current session is persisted to [SharedPreferences] so it survives
/// app restarts without showing the Google picker again.
class AuthService {
  static const _kUserId = 'auth_user_id';
  static const _kIsGuest = 'auth_is_guest';
  static const _kEmail = 'auth_user_email';
  static const _kDisplayName = 'auth_display_name';
  static const _kPhotoUrl = 'auth_photo_url';

  final SharedPreferences _prefs;
  final GoogleSignIn _googleSignIn;

  AuthService(this._prefs)
    : _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  /// Restores a previous session from SharedPreferences.
  /// Returns null if no session exists.
  Future<AppUser?> restoreSession() async {
    final id = _prefs.getString(_kUserId);
    if (id == null) return null;
    return AppUser(
      id: id,
      isGuest: _prefs.getBool(_kIsGuest) ?? false,
      email: _prefs.getString(_kEmail),
      displayName: _prefs.getString(_kDisplayName),
      photoUrl: _prefs.getString(_kPhotoUrl),
    );
  }

  /// Attempts a silent (no-UI) re-authentication using a cached Google token.
  /// Returns null if no cached credential exists.
  Future<AppUser?> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return null;
      final user = _mapAccount(account);
      await _persist(user);
      return user;
    } catch (_) {
      return null;
    }
  }

  /// Launches the interactive Google Sign-In picker.
  /// Throws if the user cancels or an error occurs.
  Future<AppUser> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Sign-in cancelled');
    final user = _mapAccount(account);
    await _persist(user);
    return user;
  }

  /// Creates and persists a guest session (no Google account required).
  Future<AppUser> continueAsGuest() async {
    const user = AppUser(id: 'guest', isGuest: true);
    await _persist(user);
    return user;
  }

  /// Signs out of Google and clears the persisted session.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    for (final key in [
      _kUserId,
      _kIsGuest,
      _kEmail,
      _kDisplayName,
      _kPhotoUrl,
    ]) {
      await _prefs.remove(key);
    }
  }

  // ── Helpers ───────────────────────────────────────────────

  AppUser _mapAccount(GoogleSignInAccount a) => AppUser(
    id: a.id,
    email: a.email,
    displayName: a.displayName,
    photoUrl: a.photoUrl,
    isGuest: false,
  );

  Future<void> _persist(AppUser user) async {
    await _prefs.setString(_kUserId, user.id);
    await _prefs.setBool(_kIsGuest, user.isGuest);
    if (user.email != null) await _prefs.setString(_kEmail, user.email!);
    if (user.displayName != null) {
      await _prefs.setString(_kDisplayName, user.displayName!);
    }
    if (user.photoUrl != null)
      await _prefs.setString(_kPhotoUrl, user.photoUrl!);
  }
}
