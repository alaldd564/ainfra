import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// 🔥 화면 import
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/blind_home_screen.dart';     // 시각장애인 홈
import 'screens/guardian_screen.dart';  // 보호자 홈

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
      debugShowCheckedModeBanner: false, // 🔕 우측 상단 debug 배너 제거
      initialRoute: '/', // 🔥 초기 라우트는 로그인
      routes: {
        '/': (context) => const LoginScreen(),           // 로그인 화면
        '/signup': (context) => const SignupScreen(),     // 회원가입 화면
        '/blind_home': (context) => const BlindHomeScreen(), // 시각장애인 홈
        '/guardian_home': (context) => const GuardianHomeScreen(), // 보호자 홈
      },
    );
  }
}
