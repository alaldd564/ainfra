import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
<<<<<<< HEAD

  // ✅ 최신 네이버 지도 초기화
  await FlutterNaverMap().init(
  clientId: '4aktoebb8w',
  onAuthFailed: (e) => debugPrint("네이버 지도 인증 실패: $e"),
);

=======
  await NaverMapSdk.instance.initialize(
      clientId: '4aktoebb8w', // 클라이언트 ID
      onAuthFailed: (ex) {
        print("네이버맵 인증 오류 (새 프로젝트) : $ex");
      }
  );
>>>>>>> 8e3f5f8fe182417b8d2539bebe72561d6e0c4267
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
<<<<<<< HEAD
  NCameraPosition? _cameraPosition;
=======
  NLatLng? _currentLocation;
>>>>>>> 8e3f5f8fe182417b8d2539bebe72561d6e0c4267

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
<<<<<<< HEAD

        setState(() {
          _cameraPosition = NCameraPosition(
            target: NLatLng(position.latitude, position.longitude),
            zoom: 16,
          );
        });
=======
        final NLatLng userLatLng = NLatLng(position.latitude, position.longitude);

        setState(() {
          _currentLocation = userLatLng;
        });

        if (_controller.isCompleted) {
          final controller = await _controller.future;
          controller.updateCamera(
            NCameraUpdate.fromCameraPosition(
              NCameraPosition(
                target: userLatLng,
                zoom: 16,
              ),
            ),
          );
        }


>>>>>>> 8e3f5f8fe182417b8d2539bebe72561d6e0c4267
      } catch (e) {
        debugPrint('위치 정보를 가져오는 중 오류 발생: $e');
      }
<<<<<<< HEAD
    } else if (status.isDenied || status.isPermanentlyDenied) {
=======
    } else if (status.isDenied) {
      print('위치 권한이 거부되었습니다.');
      setState(() { _currentLocation = NLatLng(0,0); });
    } else if (status.isPermanentlyDenied) {
      print('위치 권한이 영구적으로 거부되었습니다. 설정에서 허용해주세요.');
>>>>>>> 8e3f5f8fe182417b8d2539bebe72561d6e0c4267
      openAppSettings();
      setState(() { _currentLocation = NLatLng(0,0); });
    } else {
      print('위치 권한 상태: $status');
      setState(() { _currentLocation = NLatLng(0,0); });
    }
  }

  void _onMapReady(NaverMapController controller) async {
    _controller.complete(controller);
    print("네이버 맵 로딩 완료!");

    if (_currentLocation != null) {
      controller.updateCamera(
        NCameraUpdate.fromCameraPosition(
          NCameraPosition(
            target: _currentLocation!,
            zoom: 16,
          ),
        ),
      );
    }

  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
<<<<<<< HEAD
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
=======
      appBar: AppBar(
        title: const Text('네이버 지도'),
      ),
      body: Stack(
        children: [
          if (_currentLocation != null)
            NaverMap(
              onMapReady: _onMapReady,
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
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
>>>>>>> 8e3f5f8fe182417b8d2539bebe72561d6e0c4267
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