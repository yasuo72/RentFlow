import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Manual Firebase options for the provided Firebase project.
///
/// Note:
/// The values supplied by the user were from a Firebase Web app. They are used
/// here to connect the Flutter client to the same Firebase project. For full
/// Android/iOS FCM production support, Firebase apps matching the native
/// package ids should also be registered in Firebase:
/// - Android: com.rentflow.rentflow
/// - iOS: com.rentflow.rentflow
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

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
        return ios;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCP2mo10POyz7xpgCJhhML6WvSs8vQcN7U',
    appId: '1:19233495180:web:1e2cd777af27dc2f2a83a9',
    messagingSenderId: '19233495180',
    projectId: 'roomrent-b536d',
    authDomain: 'roomrent-b536d.firebaseapp.com',
    storageBucket: 'roomrent-b536d.firebasestorage.app',
    measurementId: 'G-ZFTQZ9Y5HV',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDDwttFlxYsY726CIJWiTISJ1htwzet7eg',
    appId: '1:19233495180:android:10ee82adbe5742922a83a9',
    messagingSenderId: '19233495180',
    projectId: 'roomrent-b536d',
    storageBucket: 'roomrent-b536d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCP2mo10POyz7xpgCJhhML6WvSs8vQcN7U',
    appId: '1:19233495180:web:1e2cd777af27dc2f2a83a9',
    messagingSenderId: '19233495180',
    projectId: 'roomrent-b536d',
    storageBucket: 'roomrent-b536d.firebasestorage.app',
    iosBundleId: 'com.rentflow.rentflow',
  );
}
