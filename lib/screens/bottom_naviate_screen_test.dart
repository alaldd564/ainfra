import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:latlong2/latlong.dart'; // 경로 좌표를 나타내는 데 필요한 패키지
import 'tmap_api.dart'; // TMapApi 임포트

class BottomNaviateScreenTest extends StatefulWidget {
  const BottomNaviateScreenTest({Key? key}) : super(key: key);

  @override
  _BottomNaviateScreenTestState createState() => _BottomNaviateScreenTestState();
}

class _BottomNaviateScreenTestState extends State<BottomNaviateScreenTest> {
  List<LatLng> routeCoordinates = [];

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    TMapApi tMapApi = TMapApi();
    double startX = 126.9780;  // 출발지 경도 (예시)
    double startY = 37.5665;  // 출발지 위도 (예시)
    double endX = 126.9810;   // 도착지 경도 (예시)
    double endY = 37.5700;    // 도착지 위도 (예시)

    try {
      var routeData = await tMapApi.getPedestrianRoute(startX, startY, endX, endY);
      var path = routeData['features'][0]['geometry']['coordinates'];
      setState(() {
        routeCoordinates = path.map<LatLng>((coord) {
          return LatLng(coord[1], coord[0]);
        }).toList();
      });
    } catch (e) {
      print('Error fetching route: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pedestrian Route'),
      ),
      body: NaverMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(37.5665, 126.9780), // 서울의 경도, 위도
          zoom: 14.0,
        ),
        mapType: NaverMapType.Basic,
        markers: routeCoordinates.map((coord) {
          return Marker(
            markerId: coord.toString(),
            position: coord,
          );
        }).toSet(),
        polylines: {
          Polyline(
            points: routeCoordinates,
            color: Colors.blue,
            width: 4,
          ),
        },
      ),
    );
  }
}
