import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class GuardianHomeScreen extends StatefulWidget {
  const GuardianHomeScreen({super.key});

  @override
  State<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends State<GuardianHomeScreen> {
  final Completer<NaverMapController> _controller = Completer();
  NLatLng? _currentLocation;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
      _initFCM();
      _checkPendingSos();
      _saveFcmToken();
    });
  }

  Future<void> _saveFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final token = await FirebaseMessaging.instance.getToken();
    if (uid != null && token != null) {
      await FirebaseFirestore.instance.collection('guardians').doc(uid).set({
        'fcm_token': token,
      }, SetOptions(merge: true));
    }
  }

  void _initFCM() async {
    await FirebaseMessaging.instance.requestPermission();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? '알림';
      final body = message.notification?.body ?? '내용 없음';

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _checkPendingSos() async {
    final guardianUid = FirebaseAuth.instance.currentUser?.uid;
    if (guardianUid == null) return;

    final guardianDoc = await FirebaseFirestore.instance.collection('guardians').doc(guardianUid).get();
    if (!guardianDoc.exists) return;

    final linkedUserUid = guardianDoc.data()?['linked_user_uid'];
    if (linkedUserUid == null) return;

    final sosSnapshot = await FirebaseFirestore.instance
        .collection('sos_signals')
        .where('user', isEqualTo: linkedUserUid)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (sosSnapshot.docs.isEmpty) return;

    final latest = sosSnapshot.docs.first;
    final timestamp = latest['timestamp'] as Timestamp;
    final now = DateTime.now();

    if (now.difference(timestamp.toDate()).inMinutes < 10) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('긴급신호 수신'),
          content: const Text('연결된 시각장애인이 SOS 버튼을 눌렀습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );

        final userLatLng = NLatLng(position.latitude, position.longitude);

        if (!mounted) return;
        setState(() {
          _currentLocation = userLatLng;
        });

        final controller = await _controller.future;
        controller.updateCamera(
          NCameraUpdate.withParams(target: userLatLng, zoom: 16),
        );
      } catch (e) {
        debugPrint('❌ 위치 가져오기 실패: $e');
        _showErrorSnackBar('위치 정보를 가져오지 못했습니다.');
      }
    } else if (status.isDenied || status.isPermanentlyDenied) {
      _showErrorSnackBar('위치 권한이 필요합니다. 설정에서 허용해주세요.');
      openAppSettings();
    } else {
      _showErrorSnackBar('위치 권한 상태: $status');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleMenu(String value) async {
    if (value == 'logout') {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } else if (value == 'connect') {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) {
          final TextEditingController idController = TextEditingController();
          return AlertDialog(
            title: const Text('시각장애인 고유번호 입력'),
            content: TextField(
              controller: idController,
              decoration: const InputDecoration(hintText: '고유번호를 입력하세요'),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final code = idController.text.trim();
                  if (code.isEmpty) return;

                  try {
                    final blindDoc = await FirebaseFirestore.instance.collection('blind_users').doc(code).get();

                    if (!blindDoc.exists) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('고유번호가 올바르지 않습니다.')),
                      );
                      return;
                    }

                    final blindData = blindDoc.data()!;
                    final guardianUid = FirebaseAuth.instance.currentUser?.uid;
                    if (guardianUid == null) throw '로그인된 보호자 없음';

                    await FirebaseFirestore.instance.collection('guardians').doc(guardianUid).set({
                      'linked_user_code': code,
                      'linked_user_uid': blindData['uid'],
                    }, SetOptions(merge: true));

                    await FirebaseFirestore.instance.collection('blind_users').doc(code).update({
                      'user_key': guardianUid,
                    });

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('고유번호가 등록되었습니다.')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('연결 실패: $e')),
                    );
                  }
                },
                child: const Text('등록'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
        title: const Text('보호자 홈', style: TextStyle(color: Color(0xFFFFD400))),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFFFFD400)),
            onSelected: _handleMenu,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('로그아웃')),
              PopupMenuItem(value: 'connect', child: Text('고유번호 입력')),
            ],
          ),
        ],
      ),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : NaverMap(
              onMapReady: (controller) => _controller.complete(controller),
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: _currentLocation!,
                  zoom: 16,
                ),
                locationButtonEnable: true,
              ),
            ),
    );
  }
}
