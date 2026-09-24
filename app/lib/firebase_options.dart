// Platform ids for Firebase project `shamelaonline`.
// API keys live in gitignored `firebase_local_secrets.dart`
// (copy from `firebase_config/firebase_local_secrets.example.dart`,
// or run `tool/ensure_firebase_config.sh`).
// Do not paste API keys into this file. `flutterfire configure` will
// overwrite it — move any new keys back into the gitignored file.
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'package:ishamela/firebase_local_secrets.dart';

/// Default [FirebaseOptions] for use with [Firebase.initializeApp].
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux — '
          'run flutterfire configure.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: FirebaseLocalSecrets.webApiKey,
    appId: '1:940987204287:web:13a1f889d5e61ca46ffc0a',
    messagingSenderId: '940987204287',
    projectId: 'shamelaonline',
    authDomain: 'shamelaonline.firebaseapp.com',
    storageBucket: 'shamelaonline.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: FirebaseLocalSecrets.androidApiKey,
    appId: '1:940987204287:android:a9ebff3f923179046ffc0a',
    messagingSenderId: '940987204287',
    projectId: 'shamelaonline',
    storageBucket: 'shamelaonline.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: FirebaseLocalSecrets.iosApiKey,
    appId: '1:940987204287:ios:a77beb756aefd5ba6ffc0a',
    messagingSenderId: '940987204287',
    projectId: 'shamelaonline',
    storageBucket: 'shamelaonline.firebasestorage.app',
    iosBundleId: 'org.ishamela.ishamela',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: FirebaseLocalSecrets.iosApiKey,
    appId: '1:940987204287:ios:a77beb756aefd5ba6ffc0a',
    messagingSenderId: '940987204287',
    projectId: 'shamelaonline',
    storageBucket: 'shamelaonline.firebasestorage.app',
    iosBundleId: 'org.ishamela.ishamela',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: FirebaseLocalSecrets.webApiKey,
    appId: '1:940987204287:web:625836845e9053f36ffc0a',
    messagingSenderId: '940987204287',
    projectId: 'shamelaonline',
    authDomain: 'shamelaonline.firebaseapp.com',
    storageBucket: 'shamelaonline.firebasestorage.app',
  );
}
