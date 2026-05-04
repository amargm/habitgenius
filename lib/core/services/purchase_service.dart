import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'entitlement_service.dart';

// ── Product IDs ───────────────────────────────────────────

/// The one-time Pro upgrade product ID on Google Play.
const kProProductId = 'habitgenius_pro_lifetime';
const _kProPurchasedKey = 'pro_purchased';

// ── Purchase result ───────────────────────────────────────

enum PurchaseResult { success, cancelled, error, alreadyOwned }

// ── Service ───────────────────────────────────────────────

/// Handles Google Play one-time Pro purchase and local persistence.
/// Singleton — access via [PurchaseService.instance].
class PurchaseService extends ChangeNotifier {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _available = false;
  bool _isPro = false;
  bool _loading = false;
  String? _error;

  bool get available => _available;
  bool get isPro => _isPro;
  bool get loading => _loading;
  String? get error => _error;

  // ── Init ──────────────────────────────────────────────────

  Future<void> init() async {
    // Restore persisted purchase state first.
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPro = prefs.getBool(_kProPurchasedKey) ?? false;
      notifyListeners();
    } catch (_) {}

    try {
      _available = await _iap.isAvailable();
    } catch (_) {
      _available = false;
      return;
    }
    if (!_available) return;

    // Listen to the purchase stream.
    _sub = _iap.purchaseStream.listen(_onPurchaseUpdates, onError: (_) {});

    // Restore any past purchases (handles reinstalls). Fire-and-forget:
    // if the store is unreachable the stream simply won't emit anything.
    try {
      await _iap.restorePurchases();
    } catch (_) {
      // Non-fatal — purchase state already loaded from SharedPreferences.
    }
  }

  // ── Buy ───────────────────────────────────────────────────

  Future<PurchaseResult> buyPro() async {
    if (_isPro) return PurchaseResult.alreadyOwned;

    _loading = true;
    _error = null;
    notifyListeners();

    if (!_available) {
      _loading = false;
      _error = 'Store not available';
      notifyListeners();
      return PurchaseResult.error;
    }

    // Load product details.
    final response = await _iap.queryProductDetails({kProProductId});
    if (response.productDetails.isEmpty) {
      _loading = false;
      _error = 'Product not found';
      notifyListeners();
      return PurchaseResult.error;
    }

    final product = response.productDetails.first;
    final param = PurchaseParam(productDetails: product);

    try {
      await _iap.buyNonConsumable(purchaseParam: param);
      // Result arrives via purchaseStream → _onPurchaseUpdates
      return PurchaseResult.success;
    } catch (e) {
      _loading = false;
      _error = e.toString();
      notifyListeners();
      return PurchaseResult.error;
    }
  }

  /// Restores a previously completed purchase (e.g. after reinstall).
  Future<void> restore() async {
    _loading = true;
    _error = null;
    notifyListeners();
    await _iap.restorePurchases();
  }

  // ── Stream handler ────────────────────────────────────────

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != kProProductId) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _deliverPro();
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        _error = purchase.error?.message;
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _deliverPro() async {
    _isPro = true;
    // Persist locally first so the app reflects Pro immediately even offline.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kProPurchasedKey, true);
    // Write to Firestore so the server record is the authoritative source.
    // Fire-and-forget — local state is already set above.
    EntitlementService.instance.grantPro();
    notifyListeners();
  }

  /// Called by [AuthNotifier] when Firestore disagrees with the local
  /// SharedPreferences value.  Syncs local storage to match the server.
  Future<void> syncProFromServer({required bool isPro}) async {
    _isPro = isPro;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kProPurchasedKey, isPro);
    } catch (_) {}
    notifyListeners();
  }

  // ── Dispose ───────────────────────────────────────────────

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
