import 'package:maptest/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;

class TmapLaunchScreen extends StatefulWidget {
  const TmapLaunchScreen({super.key});

  @override
  State<TmapLaunchScreen> createState() => _TmapLaunchScreenState();
}

class _TmapLaunchScreenState extends State<TmapLaunchScreen> {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final LocationService locationService = LocationService(); // ✅ 위치 서비스 인스턴스

  static const platform = MethodChannel('tmap_channel');

  @override
  void initState() {
    super.initState();
    // ✅ 앱 실행 시 위치 추적 시작
    locationService.startTrackingAndSend(userId: "blind001");
  }

  Future<void> _launchMapActivityWithPublicTransitRoute() async {
    final origin = _originController.text.trim();
    final destination = _destinationController.text.trim();

    if (origin.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출발지와 도착지를 모두 입력해주세요.')),
      );
      return;
    }

    try {
      await platform.invokeMethod(
        'launchMapActivityWithPublicTransitRoute',
        {
          'origin': origin,
          'destination': destination,
        },
      );
    } on PlatformException catch (e) {
      developer.log('Tmap 대중교통 길찾기 실패', error: e);
    }
  }

  Future<void> _launchDefaultMapActivity() async {
    try {
      await platform.invokeMethod('launchMapActivity');
    } on PlatformException catch (e) {
      developer.log('기본 지도 띄우기 실패', error: e);
    }
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tmap 지도 테스트')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '출발지와 도착지를 입력하면 대중교통 경로를 탐색할 수 있습니다.\n입력하지 않으면 기본 지도만 열립니다.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _originController,
                decoration: const InputDecoration(
                  labelText: '출발지',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _destinationController,
                decoration: const InputDecoration(
                  labelText: '도착지',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: _launchMapActivityWithPublicTransitRoute,
                child: const Text('대중교통 길찾기'),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _launchDefaultMapActivity,
                child: const Text('기본 지도 띄우기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
