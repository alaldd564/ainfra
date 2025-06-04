import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_service.dart';
import 'dart:async';
import 'location_share_screen.dart';
import 'right_settings_screen.dart';
import 'top_taxi_screen.dart';
import 'bottom_naviate_screen.dart';
import 'tmap_launch_screen.dart';

class BlindHomeScreen extends StatefulWidget {
  const BlindHomeScreen({super.key});

  @override
  State<BlindHomeScreen> createState() => _BlindHomeScreenState();
}

class _BlindHomeScreenState extends State<BlindHomeScreen> {
  static final AuthService _authService = AuthService();
  final FlutterTts _tts = FlutterTts();
  String? _generatedId;

  @override
  void initState() {
    super.initState();
    _fetchGeneratedIdAndStartLocationUpload();
  }

  Future<void> _fetchGeneratedIdAndStartLocationUpload() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot =
        await FirebaseFirestore.instance
            .collection('blind_users')
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get();

    if (snapshot.docs.isEmpty) {
      final guardianLinkDoc =
          await FirebaseFirestore.instance
              .collection('guardians')
              .where('linked_user_uid', isEqualTo: uid)
              .limit(1)
              .get();

      final generatedId = guardianLinkDoc.docs.first.data()['linked_user_code'];

      await FirebaseFirestore.instance
          .collection('blind_users')
          .doc(generatedId)
          .set({
            'uid': uid,
            'user_key': '',
            'created_at': FieldValue.serverTimestamp(),
          });

      _generatedId = generatedId;
      print('🆕 생성된 고유번호: $_generatedId');
    } else {
      _generatedId = snapshot.docs.first.id;
      print('📍 기존 고유번호 로드: $_generatedId');
    }

    void _startLocationUpload() async {
      final status = await Permission.location.request();

      if (!status.isGranted) {
        debugPrint('위치 권한이 거부되었습니다.');
        return;
      }

      Timer.periodic(const Duration(seconds: 10), (_) async {
        try {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null || _generatedId == null) return;

          final doc = FirebaseFirestore.instance
              .collection('locations')
              .doc(_generatedId!);

          final snapshot = await doc.get();
          final shared = snapshot.data()?['location_shared'] ?? false;
          if (!shared) {
            print('🚫 위치 공유 꺼짐 - 업로드 안 함');
            return;
          }

          final position = await Geolocator.getCurrentPosition();

          print('📍 위치 업로드 시작: ${position.latitude}, ${position.longitude}');

          await doc.set({
            'lat': position.latitude,
            'lng': position.longitude,
            'timestamp': FieldValue.serverTimestamp(),
            'last_active': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print('✅ 위치 업로드 성공: $_generatedId');
        } catch (e) {
          print('❌ 위치 업로드 실패: $e');
        }
      });
    }

    _startLocationUpload();
  }

  Future<void> _handleSwipe(
    BuildContext context,
    DragEndDetails details,
    Offset velocity,
  ) async {
    final vx = velocity.dx;
    final vy = velocity.dy;

    Widget nextScreen;
    String screenName;

    if (vx.abs() > vy.abs()) {
      if (vx > 0) {
        nextScreen = const RightSettingsScreen();
        screenName = '설정 화면';
      } else {
        nextScreen = const LocationShareScreen();
        screenName = '위치 공유 화면';
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
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && _generatedId != null) {
          try {
            await FirebaseFirestore.instance
                .collection('locations')
                .doc(_generatedId)
                .set({
                  'last_active': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
            debugPrint('📤 로그아웃 전 last_active 저장 완료');
          } catch (e) {
            debugPrint('⚠️ 로그아웃 전 상태 저장 실패: $e');
          }
        }

        await _authService.signOut();
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
        break;

      case 'generate_id':
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final generatedId = '${uid}_$timestamp';

        await FirebaseFirestore.instance
            .collection('locations')
            .doc(generatedId)
            .set({
              'location_shared': false,
              'created_at': FieldValue.serverTimestamp(),
            });

        await Clipboard.setData(ClipboardData(text: generatedId));

        if (!context.mounted) return;
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
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
            itemBuilder:
                (context) => const [
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
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TmapLaunchScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('지도 테스트 화면 이동'),
          ),
          const Spacer(),
          Center(
            child: GestureDetector(
              onPanEnd: (details) {
                _handleSwipe(
                  context,
                  details,
                  details.velocity.pixelsPerSecond,
                );
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
