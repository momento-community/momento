// firebase_app_check renamed `webProvider` / `androidProvider` /
// `appleProvider` to `providerWeb` / `providerAndroid` / `providerApple`,
// but the new params take a different `*AppCheckProvider` type that the
// SDK hasn't published migration guidance for yet. Stay on the deprecated
// signature until the upgrade path is clear.
// ignore_for_file: deprecated_member_use

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

// Held for the lifetime of the process so Flutter's accessibility tree stays
// enabled on web. Without this, text rendered into the CanvasKit surface is
// invisible to Playwright / screen readers — they can only see the canvas.
// Side effect on prod is small, and a queryable DOM is a real a11y win.
// ignore: unused_element
SemanticsHandle? _semanticsHandle;

/// Web reCAPTCHA v3 site key for Firebase App Check. Empty on builds that
/// haven't configured App Check (mock-mode CI, local dev). Production CI
/// passes via `--dart-define=APP_CHECK_RECAPTCHA_SITE_KEY=...` after the
/// site key is created in Firebase Console → App Check → Web.
const _appCheckRecaptchaSiteKey = String.fromEnvironment(
  'APP_CHECK_RECAPTCHA_SITE_KEY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _initAppCheck();
  if (kIsWeb) {
    _semanticsHandle = WidgetsBinding.instance.ensureSemantics();
  }
  runApp(const ProviderScope(child: MomentoApp()));
}

/// Activate Firebase App Check. Bound to:
///  * Web → reCAPTCHA v3 (skipped without a site-key dart-define so dev
///    builds don't break before Console setup).
///  * Android → Play Integrity in release, debug provider in dev.
///  * iOS → DeviceCheck in release, debug provider in dev.
///
/// App Check tokens are advisory until you flip "Enforce" on each Firebase
/// product (Firestore, Storage, Functions) in the Firebase Console — until
/// then this is a no-op for unverified clients. Once enforced, requests
/// without a valid token are rejected. **Don't enable Enforce mode until
/// the site key + provider are confirmed working in production.**
Future<void> _initAppCheck() async {
  try {
    if (kIsWeb) {
      if (_appCheckRecaptchaSiteKey.isEmpty) {
        // No-op — keeps mock-mode + early-stage builds working before the
        // Console-side reCAPTCHA key is created.
        return;
      }
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(_appCheckRecaptchaSiteKey),
      );
    } else {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kReleaseMode
            ? AndroidProvider.playIntegrity
            : AndroidProvider.debug,
        appleProvider: kReleaseMode
            ? AppleProvider.deviceCheck
            : AppleProvider.debug,
      );
    }
  } catch (e) {
    // Activation failures must not crash the app. Without a valid token
    // the SDK still issues unverified requests, which Firebase only
    // rejects when Enforce is on — and if Enforce is on and activation
    // failed, the user sees auth errors anyway. Surface the cause to the
    // console for diagnostics.
    debugPrint('App Check activation failed: $e');
  }
}
