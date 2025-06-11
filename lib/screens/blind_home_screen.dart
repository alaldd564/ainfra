import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'location_share_screen.dart';
import 'right_settings_screen.dart';
import 'top_taxi_screen.dart';
import 'bottom_naviate_screen.dart';
import 'tmap_launch_screen.dart';
import 'firestore_steps_screen.dart';
import 'tts_manager.dart'; // ✅ 추가

class BlindHomeScreen extends StatefulWidget {
  const BlindHomeScreen({super.key});

  @override
  State<BlindHomeScreen> createState() => _BlindHomeScreenState();
}

class _BlindHomeScreenState extends State<BlindHomeScreen> {
  static final AuthService _authService = AuthService();
  final FlutterTts _tts = FlutterTts();

  final List<Map<String, dynamic>> _menuItems = [
    {'label': '위치 공유하기', 'screen': const LocationShareScreen()},
    {'label': '길찾기', 'screen': const BottomNavigateScreen()},
    {'label': '택시 호출', 'screen': const TopTaxiScreen()},
    {'label': '설정', 'screen': const RightSettingsScreen()},
    // {'label': '지도 테스트', 'screen': const FirestoreStepsScreen()},
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      LocationService().startTrackingAndSend(userId: user.uid);
    } else {
      print("❌ 사용자 인증 정보 없음");
    }
  }

  Future<void> _speak(String text) async {
    await TtsManager.speakIfEnabled(_tts, text); // ✅ TtsManager 적용
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
            content: const Text('기능 목록을 선택하면 TTS 안내 후 이동합니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
        );
        break;

      case 'generate_id':
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

        await FirebaseFirestore.instance
            .collection('blind_users')
            .doc(uid)
            .set({
          'uid': uid,
          'user_key': '',
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await Clipboard.setData(ClipboardData(text: uid));

        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('UID 복사됨'),
            content: Text('UID: $uid\n(자동 복사되었습니다)'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
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
              PopupMenuItem(value: 'generate_id', child: Text('UID 복사')),
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
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.yellow[100],
                  child: InkWell(
                    onTap: () async {
                      await _speak('${item['label']} 화면으로 이동합니다');
                      await Future.delayed(const Duration(milliseconds: 500));
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => item['screen']),
                      );
                    },
                    child: Container(
                      height: 80,
                      alignment: Alignment.center,
                      child: Text(
                        item['label'],
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
