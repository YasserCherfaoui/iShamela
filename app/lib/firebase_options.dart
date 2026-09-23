// Placeholder Firebase options so the app compiles without `flutterfire configure`.
// Replace this file by running:
//   cd app && flutterfire configure
//
// Dummy projectId: ishamela-dev — not a live project.
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
    apiKey: 'AIzaSyB1oBRY1JDhRuFB0JhT70grWNe5DNdfouk',
    appId: '1:940987204287:web:13a1f889d5e61ca46ffc0a',
    messagingSenderId: '940987204287',
    projectId: 'shamelaonline',
    authDomain: 'shamelaonline.firebaseapp.com',
    storageBucket: 'shamelaonline.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC5w5DkPmLYBhxN6VjD74Uqj_USNuljjik',
    appId: '1:940987204287:android:a9ebff3f923179046ffc0a',
    messagingSenderId: '940987204287',
    projectId: 'shamelaonline',
    storageBucket: 'shamelaonline.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBlnOrKWCbG95HUY_yjm_RFYeHKRGS0MBY',
    appId: '1:940987204287:ios:a77beb756aefd5ba6ffc0a',
    messagingSenderId: '940987204287',
    projectId: 'shamelaonline',
    storageBucket: 'shamelaonline.firebasestorage.app',
    iosBundleId: 'org.ishamela.ishamela',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBlnOrKWCbG95HUY_yjm_RFYeHKRGS0MBY',
    appId: '1:940987204287:ios:a77beb756aefd5ba6ffc0a',
    messagingSenderId: '940987204287',
    projectId: 'shamelaonline',
    storageBucket: 'shamelaonline.firebasestorage.app',
    iosBundleId: 'org.ishamela.ishamela',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyB1oBRY1JDhRuFB0JhT70grWNe5DNdfouk',
    appId: '1:940987204287:web:625836845e9053f36ffc0a',
    messagingSenderId: '940987204287',
    projectId: 'shamelaonline',
    authDomain: 'shamelaonline.firebaseapp.com',
    storageBucket: 'shamelaonline.firebasestorage.app',
  );
}
