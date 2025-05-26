import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';

class RouteWithWaypointsScreen extends StatefulWidget {
  const RouteWithWaypointsScreen({Key? key}) : super(key: key);

  @override
  State<RouteWithWaypointsScreen> createState() =>
      _RouteWithWaypointsScreenState();
}

class _RouteWithWaypointsScreenState extends State<RouteWithWaypointsScreen> {
  static const platform = MethodChannel('com.example.taxi/navigation');

  late double startLat, startLng;
  final List<Map<String, double>> waypoints = [
    {'lat': 37.5651, 'lng': 126.9827}, // 경유지 예시
    {'lat': 37.5660, 'lng': 126.9850}, // 또 다른 경유지
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndStartNavigation();
  }

  Future<void> _getCurrentLocationAndStartNavigation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    startLat = position.latitude;
    startLng = position.longitude;

    try {
      await platform.invokeMethod('startNavigationWithWaypoints', {
        'startLat': startLat,
        'startLng': startLng,
        'endLat': 37.5665,
        'endLng': 126.9875,
        'waypoints': waypoints,
      });
    } on PlatformException catch (e) {
      print("Failed to start navigation: ${e.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text("경로 안내 시작 중...")));
  }
}
