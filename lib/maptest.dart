import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NaverMapSdk.instance.initialize(clientId: '4aktoebb8w'); // 클라이언트 ID
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'maptest',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      try {
        final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        final controller = await _controller.future;
        controller.moveCamera(CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          16,
        ));
      } catch (e) {
        print('위치 정보를 가져오는 중 오류 발생: $e');
      }
    } else if (status.isDenied) {
      // 위치 권한이 거부되었을 경우
      print('위치 권한이 거부되었습니다.');
    } else if (status.isPermanentlyDenied) {
      // 위치 권한이 영구적으로 거부되었을 경우
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('네이버 지도'),
      ),
      body: Stack(
        children: [
          if (_currentLocation != null)
            NaverMap(
              onMapReady: (controller) {
                _controller.complete(controller);
              },
              options: NaverMapViewOptions(
                initialCameraPosition: CameraPosition(
                  target: _currentLocation!,
                  zoom: 16,
                ),
                locationButtonEnable: true,
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
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
          ),
        ],
      ),
    );
  }
}
