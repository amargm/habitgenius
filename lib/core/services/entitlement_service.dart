import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Server-side source of truth for Pro entitlement.
///
/// Firestore document layout:
///   users/{firebase_uid} {
///     isPro: bool,
///     proGrantedAt: Timestamp
///   }
///
/// Security model:
///   • Only the document owner (matching UID) can read/write their record.
///   • A guest user has no Firebase UID → can never write anything here.
///   • You can manually revoke Pro from the Firebase console if needed.
///   • For bulletproof protection, add a Cloud Function that verifies
///     the Google Play purchase token before setting isPro = true.
class EntitlementService {
  EntitlementService._();
  static final EntitlementService instance = EntitlementService._();

  static const _kCollection = 'users';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection(_kCollection).doc(uid);
  }

  /// Checks Pro status from Firestore.
  ///
  /// Uses [Source.serverAndCache] — returns immediately from Firestore's
  /// local cache when offline, and hits the server when online.
  /// Always returns false for guest users (no UID).
  /// Non-fatal: any error returns false (falls back to SharedPreferences).
  Future<bool> checkPro() async {
    try {
      final doc = _userDoc;
      if (doc == null) return false;
      final snap = await doc.get(const GetOptions(source: Source.serverAndCache));
      return snap.data()?['isPro'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Writes Pro = true to Firestore after a confirmed purchase.
  /// Non-fatal — SharedPreferences is the offline fallback.
  Future<void> grantPro() async {
    try {
      final doc = _userDoc;
      if (doc == null) return;
      await doc.set(
        {
          'isPro': true,
          'proGrantedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}
