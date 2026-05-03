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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kIsWeb) {
    _semanticsHandle = WidgetsBinding.instance.ensureSemantics();
  }
  runApp(const ProviderScope(child: MomentoApp()));
}
