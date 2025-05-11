import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/auth_service.dart';

import 'left_sos_screen.dart';
import 'right_settings_screen.dart';
import 'top_taxi_screen.dart';
import 'bottom_naviate_screen.dart';

class BlindHomeScreen extends StatefulWidget {
  const BlindHomeScreen({super.key});

  @override
  State<BlindHomeScreen> createState() => _BlindHomeScreenState();
}

class _BlindHomeScreenState extends State<BlindHomeScreen> {
  static final AuthService _authService = AuthService();
  final FlutterTts _tts = FlutterTts();

  Future<void> _handleSwipe(BuildContext context, DragEndDetails details, Offset velocity) async {
    final vx = velocity.dx;
    final vy = velocity.dy;

    Widget nextScreen;
    String screenName;

    if (vx.abs() > vy.abs()) {
      if (vx > 0) {
        nextScreen = const RightSettingsScreen();
        screenName = '설정 화면';
      } else {
        nextScreen = const LeftSosScreen();
        screenName = 'SOS 호출 화면';
      }
    } else {
      if (vy > 0) {
        nextScreen = const BottomNavigateScreen();
        screenName = '길찾기 화면';
      } else {
        nextScreen = const TopTaxiScreen();
        screenName = '택시 호출 화면';
      }
    }

    await _tts.setLanguage("ko-KR");
    await _tts.setSpeechRate(0.5);
    await _tts.awaitSpeakCompletion(true);
    await _tts.speak('$screenName으로 이동합니다');

    // 음성 재생 후 화면 전환
    await Future.delayed(const Duration(milliseconds: 500));

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => nextScreen),
      );
    }
  }

  void _handleMenu(BuildContext context, String value) async {
    switch (value) {
      case 'logout':
        await _authService.signOut();
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
        break;

      case 'help':
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('도움말'),
            content: const Text('화면을 상하좌우로 스와이프하면 기능을 이동할 수 있습니다.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
            ],
          ),
        );
        break;

      case 'generate_id':
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final generatedId = '${uid}_$timestamp';

        await Clipboard.setData(ClipboardData(text: generatedId));

        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('고유번호 생성됨'),
            content: Text('고유번호: $generatedId\n(자동 복사되었습니다)'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
            ],
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
        title: const Text(
          '시각장애인 홈',
          style: TextStyle(color: Color(0xFFFFD400)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFFFD400)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFFFFD400)),
            onSelected: (value) => _handleMenu(context, value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('로그아웃')),
              PopupMenuItem(value: 'help', child: Text('도움말')),
              PopupMenuItem(value: 'generate_id', child: Text('고유번호 생성')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.topCenter,
            child: Text(
              '시각장애인 전용 서비스',
              style: TextStyle(color: Color(0xFFFFE51F), fontSize: 20),
            ),
          ),
          const Spacer(),
          Center(
            child: GestureDetector(
              onPanEnd: (details) {
                _handleSwipe(context, details, details.velocity.pixelsPerSecond);
              },
              child: Container(
                width: screenWidth * 0.8,
                height: screenHeight * 2 / 3,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE51F),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
