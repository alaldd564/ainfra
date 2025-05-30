// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBvZLvUTe3WQ5w27ydBz0riwQC7NsIDI8M',
    appId: '1:1051908844794:web:d5baf2d654e1061af42d43',
    messagingSenderId: '1051908844794',
    projectId: 't111-5d2a9',
    authDomain: 't111-5d2a9.firebaseapp.com',
    databaseURL: 'https://t111-5d2a9-default-rtdb.firebaseio.com',
    storageBucket: 't111-5d2a9.firebasestorage.app',
    measurementId: 'G-F6ZC03W342',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBKL_9h3HjOa0KmcjqzYaVlTlSuGja8JfE',
    appId: '1:1051908844794:android:52d02895e0351e26f42d43',
    messagingSenderId: '1051908844794',
    projectId: 't111-5d2a9',
    databaseURL: 'https://t111-5d2a9-default-rtdb.firebaseio.com',
    storageBucket: 't111-5d2a9.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBYTEmb4XAasHB3HXsuLAfRU71sZnM3jEY',
    appId: '1:1051908844794:ios:464eab34cf7914e0f42d43',
    messagingSenderId: '1051908844794',
    projectId: 't111-5d2a9',
    databaseURL: 'https://t111-5d2a9-default-rtdb.firebaseio.com',
    storageBucket: 't111-5d2a9.firebasestorage.app',
    iosBundleId: 'com.example.aiNFra',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBYTEmb4XAasHB3HXsuLAfRU71sZnM3jEY',
    appId: '1:1051908844794:ios:464eab34cf7914e0f42d43',
    messagingSenderId: '1051908844794',
    projectId: 't111-5d2a9',
    databaseURL: 'https://t111-5d2a9-default-rtdb.firebaseio.com',
    storageBucket: 't111-5d2a9.firebasestorage.app',
    iosBundleId: 'com.example.aiNFra',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBvZLvUTe3WQ5w27ydBz0riwQC7NsIDI8M',
    appId: '1:1051908844794:web:73174a365f558cc4f42d43',
    messagingSenderId: '1051908844794',
    projectId: 't111-5d2a9',
    authDomain: 't111-5d2a9.firebaseapp.com',
    databaseURL: 'https://t111-5d2a9-default-rtdb.firebaseio.com',
    storageBucket: 't111-5d2a9.firebasestorage.app',
    measurementId: 'G-VWFRDC24VP',
  );
}
