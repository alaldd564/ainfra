import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
//import 'package:firebase_auth/firebase_auth.dart';
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
    });
  }

  Future<void> _getCurrentLocation() async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );

        final userLatLng = NLatLng(position.latitude, position.longitude);

        setState(() {
          _currentLocation = userLatLng;
        });

        final controller = await _controller.future;
        controller.updateCamera(
          NCameraUpdate.withParams(
            target: userLatLng,
            zoom: 16,
          ),
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _handleMenu(String value) async {
    if (value == 'logout') {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } else if (value == 'connect') {
      showDialog(
        context: context,
        builder: (_) {
          final TextEditingController _idController = TextEditingController();
          return AlertDialog(
            title: const Text('시각장애인 고유번호 입력'),
            content: TextField(
              controller: _idController,
              decoration: const InputDecoration(hintText: '고유번호를 입력하세요'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // TODO: 연결 로직 구현
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('고유번호가 등록되었습니다.')),
                  );
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
