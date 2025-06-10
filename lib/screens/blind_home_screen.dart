import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'location_share_screen.dart';
import 'right_settings_screen.dart';
import 'top_taxi_screen.dart';
import 'bottom_naviate_screen.dart';
import 'tmap_launch_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';


class BlindHomeScreen extends StatefulWidget {
  const BlindHomeScreen({super.key});

  @override
  State<BlindHomeScreen> createState() => _BlindHomeScreenState();
}

class _BlindHomeScreenState extends State<BlindHomeScreen> {
  static final AuthService _authService = AuthService();

  final List<Map<String, dynamic>> _menuItems = [
    {'label': '위치 공유하기', 'screen': const LocationShareScreen()},
    {'label': '길찾기', 'screen': const BottomNavigateScreen()},
    {'label': '택시 호출', 'screen': const TopTaxiScreen()},
    {'label': '설정', 'screen': const RightSettingsScreen()},
    {'label': '지도 테스트', 'screen': const TmapLaunchScreen()},
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
            content: const Text('기능 목록을 선택하면 해당 화면으로 이동합니다.'),
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
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final generatedId = '${uid}_$timestamp';

        await FirebaseFirestore.instance
            .collection('blind_users')
            .doc(generatedId)
            .set({
          'uid': uid,
          'user_key': '',
          'created_at': FieldValue.serverTimestamp(),
        });

        await Clipboard.setData(ClipboardData(text: generatedId));

        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('고유번호 생성됨'),
            content: Text('고유번호: $generatedId\n(자동 복사되었습니다)'),
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
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                return Card(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.yellow[100],
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => item['screen']),
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
