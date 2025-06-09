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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 서비스를 활성화해주세요.')),
        );
      }
      return;
    }

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

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

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
      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        Location firstLocation = locations.first;
        setState(() {
          _destinationLocation = LatLng(firstLocation.latitude, firstLocation.longitude);
        });

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
          Expanded(
            child: NaverMap(
              options: NaverMapViewOptions(
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
