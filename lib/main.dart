import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

// 🔥 화면 import
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/blind_home_screen.dart';
import 'screens/guardian_screen.dart';
import 'screens/right_settings_screen.dart'; // 밝기/채도/명도 조절화면
import 'package:provider/provider.dart';

// ✅ 전역 설정 클래스
class BrightnessSettings extends ChangeNotifier {
  double brightness = 1.0;
  double saturation = 1.0;
  double lightness = 0.5;

  void updateBrightness(double value) {
    brightness = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void updateSaturation(double value) {
    saturation = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void updateLightness(double value) {
    lightness = value.clamp(0.0, 1.0);
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FlutterNaverMap().init(
    clientId: '4aktoebb8w',
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
          initialRoute: '/',
          routes: {
            '/': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/blind_home': (context) => const BlindHomeScreen(),
            '/guardian_home': (context) => const GuardianHomeScreen(),
            '/settings': (context) => const RightSettingsScreen(),
          },
          builder: (context, child) {
            return Stack(
              children: [
                Container(color: color), // 전역 색상 필터
                child ?? const SizedBox.shrink(),
              ],
            );
          },
        );
      },
    );
  }
}
