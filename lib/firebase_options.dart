// PLACEHOLDER: Replace with actual Firebase configuration
// Run `flutterfire configure` to generate this file automatically.
// See: https://firebase.google.com/docs/flutter/setup

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // TODO: Replace these placeholder values with your actual Firebase project config.
  // Run `flutterfire configure` from the project root to auto-generate this file.

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: 'YOUR_WEB_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC26qebPvsWXxHscoLW0MZI9U6IWJAafrc',
    appId: '1:836907422627:android:51937926060e46ff280016',
    messagingSenderId: '836907422627',
    projectId: 'finflow-3ae88',
    storageBucket: 'finflow-3ae88.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAON3J-UjCqLP7w8kTrcB6k9DkNQZunNNA',
    appId: '1:836907422627:ios:c2b754e879cd3d42280016',
    messagingSenderId: '836907422627',
    projectId: 'finflow-3ae88',
    storageBucket: 'finflow-3ae88.firebasestorage.app',
    iosBundleId: 'com.finflow.finflow',
  );

}