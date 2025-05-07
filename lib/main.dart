import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// ✅ 최신 네이버 지도 SDK import
import 'package:flutter_naver_map/flutter_naver_map.dart';

// 🔥 화면 import
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/blind_home_screen.dart'; // 시각장애인 홈
import 'screens/guardian_screen.dart'; // 보호자 홈

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ 최신 방식으로 Naver 지도 SDK 초기화
  await FlutterNaverMap().init(
    clientId: '4aktoebb8w',
    onAuthFailed: (e) => debugPrint("네이버 지도 인증 실패: $e"),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '로그인 회원가입 테스트',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(), // 로그인 화면
        '/signup': (context) => const SignupScreen(), // 회원가입 화면
        '/blind_home': (context) => const BlindHomeScreen(), // 시각장애인 홈
        '/guardian_home': (context) => const GuardianHomeScreen(), // 보호자 홈
      },
    );
  }
}
