// lib/services/firebase_service.dart

import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart'; // 이건 Firebase 콘솔에서 설정한 후 생성됨

class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
