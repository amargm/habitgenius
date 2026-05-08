import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/data_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch any unhandled Flutter framework errors — log, don't crash.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };

  // Catch unhandled async/platform errors — log, don't crash.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformError] $error\n$stack');
    return true; // handled — prevents crash-to-desktop
  };

  final prefs = await SharedPreferences.getInstance();

  // Resolve and stamp the real app version so AppMeta.appVersion is accurate.
  try {
    final info = await PackageInfo.fromPlatform();
    DataService.setAppVersion(info.version);
  } catch (e) {
    debugPrint('[Startup] PackageInfo.fromPlatform failed: $e');
  }

  // Initialize Firebase — reads configuration from google-services.json
  // which is processed at build time by the Google Services Gradle plugin.
  // Non-fatal: a missing or invalid config is logged but never crashes the app.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[Startup] Firebase.initializeApp failed: $e');
  }

  // Non-fatal startup services — failures must never prevent the app from
  // reaching runApp().
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('[Startup] NotificationService.init failed: $e');
  }

  try {
    await PurchaseService.instance.init();
  } catch (e) {
    debugPrint('[Startup] PurchaseService.init failed: $e');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const HabitGeniusApp(),
    ),
  );
}
