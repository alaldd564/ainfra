import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class GuardianHomeScreen extends StatefulWidget {
  const GuardianHomeScreen({super.key});

  @override
  State<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends State<GuardianHomeScreen> {
  final Completer<NaverMapController> _controller = Completer();
  NLatLng? _currentLocation;

  @override
  void initState() {
    super.initState();

    // 💡 화면이 다 그려지고 나서 위치 권한 요청
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

        debugPrint("📍 현재 위치: $_currentLocation");

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('보호자 홈')),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : NaverMap(
              onMapReady: (controller) {
                _controller.complete(controller);
              },
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
