import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
}

class TmapLaunchScreen extends StatefulWidget {
  const TmapLaunchScreen({super.key});

  @override
  State<TmapLaunchScreen> createState() => _TmapLaunchScreenState();
}

class _TmapLaunchScreenState extends State<TmapLaunchScreen> {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  LatLng? _currentLocation;
  LatLng? _originLocation;
  LatLng? _destinationLocation;

  final String odsayApiKey = 'hgj6%2FnV14Hz6Y%2BIxuxdcrtJUeQRpNO0X53L2GDBVCmk'; //API 키값

  static const platform = MethodChannel('tmap_channel');

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    print('DEBUG: _getCurrentLocation 함수 시작');
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 서비스를 활성화해주세요.')),
        );
      }
      print('DEBUG: 위치 서비스 비활성화됨.');
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
        print('DEBUG: 위치 권한 거부됨.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.')),
        );
      }
      print('DEBUG: 위치 권한 영구 거부됨.');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _originLocation = _currentLocation; // 현재 위치를 출발지로 기본 설정
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 위치를 불러왔습니다.')),
        );
      }
      print('DEBUG: 현재 위치 불러오기 성공: ${_currentLocation!
          .latitude}, ${_currentLocation!.longitude}');
    } catch (e) {
      developer.log('현재 위치를 불러오는 중 오류 발생', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 위치를 불러오는데 실패했습니다.')),
        );
      }
      print('DEBUG: 현재 위치 불러오기 실패: $e');
    }
  }

  Future<LatLng?> _geocodeAddress(String address, String type) async {
    print('DEBUG: _geocodeAddress 함수 시작 (타입: $type, 주소: $address)');
    if (address.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$type 지명을 입력해주세요.')),
        );
      }
      print('DEBUG: $type 지명 입력 안됨.');
      return null;
    }

    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        Location firstLocation = locations.first;
        final latLng = LatLng(firstLocation.latitude, firstLocation.longitude);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
                '$type (${latLng.latitude.toStringAsFixed(4)}, ${latLng
                    .longitude.toStringAsFixed(4)})를 찾았습니다.')),
          );
        }
        print('DEBUG: $type 지명 검색 성공: ${latLng.latitude}, ${latLng.longitude}');
        return latLng;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('해당 $type 지명을 찾을 수 없습니다.')),
          );
        }
        print('DEBUG: $type 지명 검색 결과 없음.');
        return null;
      }
    } catch (e) {
      developer.log('$type 지명 검색 중 오류 발생', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$type 지명 검색에 실패했습니다.')),
        );
      }
      print('DEBUG: $type 지명 검색 실패: $e');
      return null;
    }
  }

  Future<void> _searchOriginCoordinates() async {
    print('DEBUG: _searchOriginCoordinates 함수 시작');
    final result = await _geocodeAddress(_originController.text.trim(), '출발지');
    setState(() {
      _originLocation = result;
    });
    print('DEBUG: _originLocation 업데이트 완료: $_originLocation');
  }

  // 목적지 지명 검색 및 _destinationLocation 업데이트
  Future<void> _searchDestinationCoordinates() async {
    print('DEBUG: _searchDestinationCoordinates 함수 시작');
    final result = await _geocodeAddress(
        _destinationController.text.trim(), '목적지');
    setState(() {
      _destinationLocation = result;
    });
    print('DEBUG: _destinationLocation 업데이트 완료: $_destinationLocation');
  }

  Future<void> _searchPublicTransitRouteWithODsay() async {
    print('--- _searchPublicTransitRouteWithODsay 함수 시작 ---');

    if (_originLocation == null) {
      print('DEBUG: 출발지 좌표가 null입니다.');
      if (_originController.text
          .trim()
          .isNotEmpty) {
        print('DEBUG: 출발지 입력 필드에 내용이 있으므로 지명 검색을 시도합니다.');
        await _searchOriginCoordinates();
      } else {
        print('DEBUG: 출발지 입력 필드도 비어있습니다. 현재 위치 가져오기를 시도합니다.');
        await _getCurrentLocation();
      }

      if (_originLocation == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('유효한 출발지 좌표를 설정해주세요.')),
          );
        }
        print('DEBUG: 출발지 좌표 확보 최종 실패, 함수 종료.');
        return;
      }
    }
    print('DEBUG: 출발지 좌표 확보 완료: ${_originLocation!.latitude}, ${_originLocation!
        .longitude}'); // 3단계 로그

    if (_destinationLocation == null) {
      print('DEBUG: 목적지 좌표가 null입니다.');
      if (_destinationController.text
          .trim()
          .isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('목적지를 먼저 입력하고 검색해주세요.')),
          );
        }
        print('DEBUG: 목적지 지명 입력 필요, 함수 종료.');
        return;
      }
      await _searchDestinationCoordinates();
      if (_destinationLocation == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('유효한 목적지 좌표를 찾을 수 없습니다.')),
          );
        }
        print('DEBUG: 목적지 좌표 확보 최종 실패, 함수 종료.');
        return;
      }
    }
    print('DEBUG: 목적지 좌표 확보 완료: ${_destinationLocation!
        .latitude}, ${_destinationLocation!.longitude}'); // 5단계 로그

    final String url =
        'https://api.odsay.com/v1/api/searchPubTransPath?SX=${_originLocation!
        .longitude}&SY=${_originLocation!.latitude}&EX=${_destinationLocation!
        .longitude}&EY=${_destinationLocation!.latitude}&apiKey=$odsayApiKey';

    print('DEBUG: ODsay API 호출 URL: $url');

    String routeText = '';
    try {
      final response = await http.get(Uri.parse(url));
      print('DEBUG: API 호출 응답 받음. StatusCode: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        print('ODsay API Response: ${response.body}');

        if (decodedData['result'] != null &&
            decodedData['result']['path'] != null) {
          final List paths = decodedData['result']['path'];
          if (paths.isNotEmpty) {
            routeText += 'ODsay 검색 결과:\n';
            for (var path in paths) {
              routeText += '\n--- ODsay 경로 ---\n';
              routeText += '총 소요 시간: ${path['info']['totalTime']}분\n';
              routeText += '총 요금: ${path['info']['totalFare']}원\n';
              routeText += '총 이동 거리: ${path['info']['totalDistance']}m\n';

              final List<dynamic> subPath = path['subPath'];
              for (var sp in subPath) {
                if (sp['trafficType'] == 1) { // 지하철
                  routeText +=
                  '- [지하철] ${sp['startName']}역 -> ${sp['endName']}역 (${sp['sectionTime']}분)\n';
                } else if (sp['trafficType'] == 2) { // 버스
                  routeText +=
                  '- [버스] ${sp['startName']} 정류장 승차 (${sp['busNo'] ??
                      ''}), ${sp['endName']} 정류장 하차 (${sp['sectionTime']}분)\n';
                } else if (sp['trafficType'] == 3) { // 도보
                  routeText += '- [도보] ${sp['distance']}m 이동\n';
                }
              }
            }
          } else {
            routeText = '해당하는 대중교통 경로가 없습니다.';
          }
        } else {
          routeText = 'ODsay 검색 결과가 없습니다. (result 또는 path 필드 없음)';
        }
      } else {
        routeText = 'ODsay API 호출 실패: ${response.statusCode}\n${response.body}';
        print('ODsay API Error: ${response.body}');
        developer.log('ODsay API Error', error: response.body);
      }
    } catch (e) {
      routeText = '오류 발생: $e';
      print('EXCEPTION: ODsay API Request Error: $e');
      developer.log('ODsay API Request Error', error: e);
    }

    _showRouteResultDialog(routeText);
    print('--- _searchPublicTransitRouteWithODsay 함수 종료 ---');
  }

  void _showRouteResultDialog(String resultText) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('대중교통 경로 안내'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Text(resultText),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
    );
  }

  Future<void> _launchMapActivityWithPublicTransitRouteTmapApp() async {
    print('DEBUG: Tmap 앱 길찾기 함수 시작');
    final originLat = _originLocation?.latitude.toString() ?? '';
    final originLon = _originLocation?.longitude.toString() ?? '';
    final destLat = _destinationLocation?.latitude.toString() ?? '';
    final destLon = _destinationLocation?.longitude.toString() ?? '';
    final destinationName = _destinationController.text.trim();

    if (_originLocation == null || _destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('출발지와 목적지 좌표를 모두 가져온 후에 Tmap 앱으로 시도해주세요.')),
      );
      print('DEBUG: Tmap 앱 길찾기 - 출발지 또는 목적지 좌표 없음.');
      return;
    }

    try {
      await platform.invokeMethod(
        'launchMapActivityWithPublicTransitRoute',
        {
          'originLat': originLat,
          'originLon': originLon,
          'destinationLat': destLat,
          'destinationLon': destLon,
          'destinationName': destinationName,
        },
      );
      print('DEBUG: Tmap 앱 길찾기 호출 성공 (네이티브 구현 필요).');
    } on PlatformException catch (e) {
      developer.log('Tmap 대중교통 길찾기 앱 실행 실패: ${e.message}', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tmap 앱 실행에 실패했습니다: ${e.message}')),
      );
      print('DEBUG: Tmap 앱 길찾기 호출 실패: ${e.message}');
    }
  }

  Future<void> _launchDefaultMapActivity() async {
    print('DEBUG: Tmap 앱 기본 지도 함수 시작');
    try {
      await platform.invokeMethod('launchMapActivity');
      print('DEBUG: Tmap 앱 기본 지도 호출 성공 (네이티브 구현 필요).');
    } on PlatformException catch (e) {
      developer.log('기본 지도 띄우기 실패', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tmap 앱 실행에 실패했습니다: ${e.message}')),
      );
      print('DEBUG: Tmap 앱 기본 지도 호출 실패: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tmap & ODsay 경로 테스트')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _currentLocation != null
                    ? '현재 기기 위치: ${_currentLocation!.latitude.toStringAsFixed(
                    6)}, ${_currentLocation!.longitude.toStringAsFixed(6)}'
                    : '현재 기기 위치 불러오는 중...',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _getCurrentLocation,
                child: const Text('현재 위치로 출발지 설정'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _originController,
                decoration: const InputDecoration(
                  labelText: '출발지 지명 (예: 강남역)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) => _searchOriginCoordinates(),
              ),
              const SizedBox(height: 8.0),
              ElevatedButton(
                onPressed: _searchOriginCoordinates,
                child: const Text('출발지 검색 (좌표 얻기)'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _originLocation != null
                      ? '설정된 출발지: ${_originLocation!.latitude.toStringAsFixed(
                      6)}, ${_originLocation!.longitude.toStringAsFixed(6)}'
                      : '설정된 출발지 없음',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _destinationController,
                decoration: const InputDecoration(
                  labelText: '목적지 지명 (예: 부산역)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) => _searchDestinationCoordinates(),
              ),
              const SizedBox(height: 8.0),
              ElevatedButton(
                onPressed: _searchDestinationCoordinates,
                child: const Text('목적지 검색 (좌표 얻기)'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _destinationLocation != null
                      ? '설정된 목적지: ${_destinationLocation!.latitude
                      .toStringAsFixed(6)}, ${_destinationLocation!.longitude
                      .toStringAsFixed(6)}'
                      : '설정된 목적지 없음',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: _searchPublicTransitRouteWithODsay,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('ODsay 대중교통 텍스트 안내'),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _launchMapActivityWithPublicTransitRouteTmapApp,
                child: const Text('Tmap 앱으로 대중교통 길찾기'),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _launchDefaultMapActivity,
                child: const Text('Tmap 앱 기본 지도 띄우기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
