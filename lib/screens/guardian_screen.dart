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
    _getCurrentLocation();
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

        setState(() {
          _currentLocation = NLatLng(position.latitude, position.longitude);
        });

        // ✅ 위치 로그 출력
        debugPrint("📍 현재 위치: $_currentLocation");

        final controller = await _controller.future;
        controller.updateCamera(
          NCameraUpdate.withParams(
            target: _currentLocation!,
            zoom: 16,
          ),
        );
      } catch (e) {
        debugPrint('❌ 위치 가져오기 실패: $e');
      }
    } else {
      openAppSettings(); // 권한 거부 시 설정 화면
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
