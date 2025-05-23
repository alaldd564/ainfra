import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minimal Naver Map Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
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
  NaverMapController? _mapController;
  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  final TextEditingController _searchController = TextEditingController();
  final List<NMarker> _markers = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // 위젯 초기화 시 현재 위치 불러오기
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // 현재 위치 불러오기
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스 활성화 여부 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 서비스를 활성화해주세요.')),
        );
      }
      return;
    }

    // 위치 권한 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치 권한이 필요합니다.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 거부되었습니다. 설정에서 변경해주세요.')),
        );
      }
      return;
    }

    // 현재 위치 가져오기
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      // 현재 위치로 지도 이동
      if (_mapController != null && _currentLocation != null) {
        _mapController!.updateCamera(
          NCameraUpdate.fromCameraPosition(
            NCameraPosition(target: _currentLocation!, zoom: 15),
          ),
        );
      }
    } catch (e) {
      print('현재 위치를 불러오는 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 위치를 불러오는데 실패했습니다.')),
        );
      }
    }
  }

  Future<void> _searchDestination(String address) async {
    if (address.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주소를 입력해주세요.')),
        );
      }
      return;
    }

    try {
      List<Location> locations = await geocoding.locationFromAddress(address);

      if (locations.isNotEmpty) {
        Location firstLocation = locations.first;
        setState(() {
          _destinationLocation =
              LatLng(firstLocation.latitude, firstLocation.longitude);
          _addDestinationMarker();
        });

        // 목적지로 지도 이동
        if (_mapController != null && _destinationLocation != null) {
          _mapController!.updateCamera(
            NCameraUpdate.fromCameraPosition(
              NCameraPosition(target: _destinationLocation!, zoom: 15),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('해당 주소를 찾을 수 없습니다.')),
          );
        }
      }
    } catch (e) {
      print('주소 검색 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주소 검색에 실패했습니다.')),
        );
      }
    }
  }

  // 목적지 마커
  void _addDestinationMarker() {
    if (_destinationLocation == null) return;

    _markers.removeWhere((marker) => marker.info.id == 'destination');

    // 새 목적지 마커 생성 및 추가
    final destinationMarker = NMarker(
        id: 'destination',
        position: _destinationLocation!,
        caption: const NOverlayCaption(text: '목적지'),\
    );

    setState(() {
      _markers.add(destinationMarker);
    });
    \
    if (_mapController != null) {
    _mapController!.updateMarkers(markers: _markers);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Naver Map Test'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '목적지를 입력하세요 (예: 서울역)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                ElevatedButton(
                  onPressed: () {
                    _searchDestination(_searchController.text);
                  },
                  child: const Text('검색'),
                ),
              ],
            ),
          ),
          // 지도 위젯
          Expanded(
            child: NaverMap(
              options: NaverMapViewOptions(
                //기본 위치(서울 시청)
                initialCameraPosition: NCameraPosition(
                  target: _currentLocation ?? const LatLng(37.5665, 126.9780),
                  zoom: 15,
                ),
                mapType: NMapType.basic,
                buildingLayerGroup: NLayerGroup.building,
                lightArticulationAndBuildingHeight: true,
              ),
              onMapReady: (controller) {
                _mapController = controller;
                if (_currentLocation != null) {
                  _mapController!.updateCamera(
                    NCameraUpdate.fromCameraPosition(
                      NCameraPosition(target: _currentLocation!, zoom: 15),
                    ),
                  );
                }
              },
              markers: _markers,
            ),
          ),
          if (_currentLocation != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                  '현재 위치: ${_currentLocation!.latitude.toStringAsFixed(6)}, ${_currentLocation!.longitude.toStringAsFixed(6)}'),
            ),
          if (_destinationLocation != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                  '목적지 위치: ${_destinationLocation!.latitude.toStringAsFixed(6)}, ${_destinationLocation!.longitude.toStringAsFixed(6)}'),
            ),
        ],
      ),
    );
  }
}