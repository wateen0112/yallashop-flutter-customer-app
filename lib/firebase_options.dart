import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Default Firebase configuration for the current platform.
///
/// Generated from `android/app/google-services.json` (project
/// `my-next13-test-b9bc0`, Android app `com.yallaCode.superMommy`).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only generated for the Android platform '
          '(project my-next13-test-b9bc0).',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBW5jIccrDtI_9SQnDOy-3RtdBGeub7WsU',
    appId: '1:42320449318:android:3c04aa06d9bb93d4ccfbe7',
    messagingSenderId: '42320449318',
    projectId: 'my-next13-test-b9bc0',
    storageBucket: 'my-next13-test-b9bc0.firebasestorage.app',
  );
}