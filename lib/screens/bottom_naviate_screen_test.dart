import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../services/tmap_service.dart';

class BottomNaviateScreenTest extends StatefulWidget {
  const BottomNaviateScreenTest({super.key});

  @override
  State<BottomNaviateScreenTest> createState() => _BottomNaviateScreenTestState();
}

class _BottomNaviateScreenTestState extends State<BottomNaviateScreenTest> {
  List<NLatLng> routeCoordinates = [];
  NaverMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    final tMapApi = TMapApi();
    const startX = 126.9780;
    const startY = 37.5665;
    const endX = 126.9810;
    const endY = 37.5700;

    try {
      final routeData = await tMapApi.getPedestrianRoute(startX, startY, endX, endY);
      final path = routeData['features'][0]['geometry']['coordinates'];
      routeCoordinates = path.map<NLatLng>((coord) => NLatLng(coord[1], coord[0])).toList();

      if (_mapController != null && routeCoordinates.isNotEmpty) {
        // 지도 초기화 후 오버레이 추가
        final overlay = NPathOverlay(
          id: 'route',
          coords: routeCoordinates,
          width: 6,
          color: Colors.blue,
        );
        await _mapController!.addOverlay(overlay);

        for (final coord in routeCoordinates) {
          await _mapController!.addOverlay(NMarker(
            id: coord.toString(),
            position: coord,
          ));
        }
      }

      setState(() {});
    } catch (e) {
      debugPrint('❌ 경로 가져오기 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('보행자 경로 테스트')),
      body: NaverMap(
        onMapReady: (controller) async {
          _mapController = controller;
          await _fetchRoute(); // controller가 준비된 이후 실행
        },
        options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(
            target: routeCoordinates.isNotEmpty
                ? routeCoordinates.first
                : const NLatLng(37.5665, 126.9780),
            zoom: 14,
          ),
        ),
      ),
    );
  }
}
