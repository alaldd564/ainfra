import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/blind_home_screen.dart';
import 'screens/guardian_screen.dart';
import 'screens/right_settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:maptest/screens/brightness_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
