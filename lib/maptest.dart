import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 최신 네이버 지도 초기화
  await FlutterNaverMap().init(
  clientId: '4aktoebb8w',
  onAuthFailed: (e) => debugPrint("네이버 지도 인증 실패: $e"),
);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'maptest',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<NaverMapController> _controller = Completer();
  NCameraPosition? _cameraPosition;

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
          _cameraPosition = NCameraPosition(
            target: NLatLng(position.latitude, position.longitude),
            zoom: 16,
          );
        });
      } catch (e) {
        debugPrint('위치 정보를 가져오는 중 오류 발생: $e');
      }
    } else if (status.isDenied || status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('네이버 지도')),
      body: _cameraPosition == null
          ? const Center(child: CircularProgressIndicator())
          : NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition: _cameraPosition!,
                locationButtonEnable: true,
              ),
              onMapReady: (controller) {
                _controller.complete(controller);
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('위젯 표시')),
            );
          },
          child: const Text('위젯 표시'),
        ),
      ),
    );
  }
}
