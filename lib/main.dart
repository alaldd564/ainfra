import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/blind_home_screen.dart';
import 'screens/guardian_screen.dart';
import 'screens/right_settings_screen.dart';
import 'screens/splash_screen.dart'; // ✅ 추가
import 'package:provider/provider.dart';
import 'package:maptest/screens/brightness_settings.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart'; // ✅ 네이버 지도 import 추가

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ 네이버 지도 초기화
  await FlutterNaverMap().init(
    clientId: 'ey5niviv8s', // ← 네이버 클라이언트 ID로 교체
    onAuthFailed: (e) => debugPrint("네이버 지도 인증 실패: $e"),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => BrightnessSettings(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BrightnessSettings>(
      builder: (context, settings, _) {
        final color = HSLColor.fromAHSL(
          1.0,
          200,
          settings.saturation,
          settings.lightness,
        ).toColor().withOpacity(settings.brightness);

        return MaterialApp(
          title: '로그인 회원가입 테스트',
          debugShowCheckedModeBanner: false,
          initialRoute: '/', // 🚨 SplashScreen으로 시작
          routes: {
            '/': (context) => const SplashScreen(), // ✅ 자동 로그인 체크
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/blind_home': (context) => const BlindHomeScreen(),
            '/guardian_home': (context) => const GuardianHomeScreen(),
            '/settings': (context) => const RightSettingsScreen(),
          },
          builder: (context, child) {
            return Stack(
              children: [
                Container(color: color),
                child ?? const SizedBox.shrink(),
              ],
            );
          },
        );
      },
    );
  }
}
