import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/auth_service.dart';

class GuardianHomeScreen extends StatefulWidget {
  const GuardianHomeScreen({super.key});

  @override
  State<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends State<GuardianHomeScreen> {
  final Completer<NaverMapController> _controller = Completer();
  NaverMapController? _mapController;
  NLatLng? _currentLocation;
  NMarker? _blindUserMarker;
  final AuthService _authService = AuthService();
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
      _startLocationUpdates();
      _initFCM();
      _saveFcmToken();
      _checkPendingSos();
    });
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        final latLng = NLatLng(position.latitude, position.longitude);
        setState(() => _currentLocation = latLng);

        final controller = await _controller.future;
        _mapController = controller;
        await controller.updateCamera(NCameraUpdate.withParams(target: latLng, zoom: 16));
      } catch (e) {
        _showErrorSnackBar('위치 정보를 가져오지 못했습니다.');
      }
    } else {
      _showErrorSnackBar('위치 권한이 필요합니다. 설정에서 허용해주세요.');
      openAppSettings();
    }
  }

  void _startLocationUpdates() {
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final guardianDoc = await FirebaseFirestore.instance.collection('guardians').doc(uid).get();
      final linkedUid = guardianDoc.data()?['linked_user_uid'];
      if (linkedUid == null) return;

      final locationDoc = await FirebaseFirestore.instance.collection('locations').doc(linkedUid).get();
      final data = locationDoc.data();
      if (data == null || !(data['location_shared'] ?? false)) return;

      final lat = data['lat'];
      final lng = data['lng'];
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
      final newLocation = NLatLng(lat, lng);

      final newMarker = NMarker(
        id: 'blind_marker',
        position: newLocation,
        caption: NOverlayCaption(
          text: timestamp != null
              ? '시각장애인 위치 (${timestamp.hour}시 ${timestamp.minute}분)'
              : '시각장애인 위치',
        ),
      );

      final controller = _mapController;
      if (controller != null) {
        if (_blindUserMarker != null) {
          await controller.deleteOverlay(_blindUserMarker!.info);
        }
        await controller.addOverlay(newMarker);
        await controller.updateCamera(NCameraUpdate.withParams(target: newLocation, zoom: 16));
      }

      setState(() {
        _currentLocation = newLocation;
        _blindUserMarker = newMarker;
      });
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
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

  void _initFCM() {
    FirebaseMessaging.instance.requestPermission();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? '알림';
      final body = message.notification?.body ?? '내용 없음';
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('확인'))],
        ),
      );
    });
  }

  Future<void> _checkPendingSos() async {
    final guardianUid = FirebaseAuth.instance.currentUser?.uid;
    if (guardianUid == null) return;
    final guardianDoc = await FirebaseFirestore.instance.collection('guardians').doc(guardianUid).get();
    final linkedUserUid = guardianDoc.data()?['linked_user_uid'];
    if (linkedUserUid == null) return;
    final sosSnapshot = await FirebaseFirestore.instance
        .collection('sos_signals')
        .where('user', isEqualTo: linkedUserUid)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    if (sosSnapshot.docs.isEmpty) return;
    final timestamp = sosSnapshot.docs.first['timestamp'] as Timestamp;
    if (DateTime.now().difference(timestamp.toDate()).inMinutes < 10) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('긴급신호 수신'),
          content: const Text('연결된 시각장애인이 SOS 버튼을 눌렀습니다.'),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('확인'))],
        ),
      );
    }
  }

  void _handleMenu(String value) async {
    if (value == 'logout') {
      await _authService.signOut();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } else if (value == 'connect') {
      showDialog(
        context: context,
        builder: (_) {
          final TextEditingController idController = TextEditingController();
          return AlertDialog(
            title: const Text('시각장애인 UID 입력'),
            content: TextField(
              controller: idController,
              decoration: const InputDecoration(hintText: '시각장애인 UID를 입력하세요'),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final blindUid = idController.text.trim();
                  if (blindUid.isEmpty) return;

                  try {
                    final blindDoc = await FirebaseFirestore.instance.collection('blind_users').doc(blindUid).get();
                    if (!blindDoc.exists) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('UID가 올바르지 않습니다.')),
                      );
                      return;
                    }

                    final guardianUid = FirebaseAuth.instance.currentUser?.uid;
                    if (guardianUid == null) throw '로그인된 보호자 없음';

                    await FirebaseFirestore.instance.collection('guardians').doc(guardianUid).set({
                      'linked_user_uid': blindUid,
                    }, SetOptions(merge: true));

                    await FirebaseFirestore.instance.collection('blind_users').doc(blindUid).update({
                      'user_key': guardianUid,
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('연결이 완료되었습니다.')),
                    );
                  } catch (e) {
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
        title: const Text('보호자 홈'),
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFFFFD400)),
            onSelected: _handleMenu,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('로그아웃')),
              PopupMenuItem(value: 'connect', child: Text('UID 입력')),
            ],
          ),
        ],
      ),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : NaverMap(
              onMapReady: (controller) {
                _controller.complete(controller);
                _mapController = controller;
              },
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(target: _currentLocation!, zoom: 16),
                locationButtonEnable: true,
              ),
            ),
    );
  }
}