import 'package:firebase_core/firebase_core.dart';

import 'package:ishamela/firebase_options.dart';

/// Best-effort Firebase init. Failures leave the app in permanent guest mode.
bool firebaseReady = false;

/// Initializes Firebase; sets [firebaseReady] false on any failure.
Future<void> initFirebaseBestEffort() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false;
  }
}
