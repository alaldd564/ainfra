import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// 🔥 로그인, 회원가입 화면 import
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart'; // 이것도 필요해!

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '로그인 회원가입 테스트',
      initialRoute: '/', // 🔥 초기 라우트
      routes: {
        '/': (context) => const LoginScreen(),     // 로그인 화면
        '/signup': (context) => const SignupScreen(), // 회원가입 화면
      },
    );
  }
}
