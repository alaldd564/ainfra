import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart'; // 웹뷰 패키지 임포트

// LatLng 클래스 정의
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

  final String odsayApiKey = 'hgj6%2FnV14Hz6Y%2BIxuxdcrtJUeQRpNO0X53L2GDBVCmk'; // 실제 사용하시는 ODsay API 키

  WebViewController? _webViewController;
  bool _isWebViewReady = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {},
          onPageFinished: (String url) {
            setState(() {
              _isWebViewReady = true;
            });
            if (_currentLocation != null) {
              _webViewController?.runJavaScript(
                  'setCurrentLocation(${_currentLocation!.latitude}, ${_currentLocation!.longitude})');
            }
          },
          onWebResourceError: (WebResourceError error) {
            developer.log('Webview error: ${error.description}', name: 'TmapLaunchScreen');
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadFlutterAsset('assets/tmap_webview.html');
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
      Position position = await Geolocator.getCurrentPosition( // 'position' 변수 정의
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude); // LatLng 클래스 사용
        _originLocation = _currentLocation;
      });

      if (_isWebViewReady && _webViewController != null && _currentLocation != null) {
        _webViewController!.runJavaScript(
            'setCurrentLocation(${_currentLocation!.latitude}, ${_currentLocation!.longitude})');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 위치를 불러왔습니다.')),
        );
      }
      print('DEBUG: 현재 위치 불러오기 성공: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
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
                '$type (${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)})를 찾았습니다.')),
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
    // 출발지 좌표를 웹뷰의 지도로 전달 (선택적 기능)
    if (_isWebViewReady && _webViewController != null && _originLocation != null) {
      _webViewController!.runJavaScript(
          'setCurrentLocation(${_originLocation!.latitude}, ${_originLocation!.longitude})');
    }
    print('DEBUG: _originLocation 업데이트 완료: $_originLocation');
  }

  Future<void> _searchDestinationCoordinates() async {
    print('DEBUG: _searchDestinationCoordinates 함수 시작');
    final result = await _geocodeAddress(
        _destinationController.text.trim(), '목적지');
    setState(() {
      _destinationLocation = result;
    });
    // 목적지 좌표를 웹뷰의 지도로 전달 (선택적 기능)
    if (_isWebViewReady && _webViewController != null && _destinationLocation != null) {
      // 목적지 검색 시에는 중심 이동보다는 마커 추가 등의 다른 동작을 고려할 수 있습니다.
      // 여기서는 일단 중심 이동으로 처리합니다.
      // _webViewController!.runJavaScript(
      //     'setCurrentLocation(${_destinationLocation!.latitude}, ${_destinationLocation!.longitude})');
    }
    print('DEBUG: _destinationLocation 업데이트 완료: $_destinationLocation');
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

  Future<void> _searchPublicTransitRouteWithODsay() async {
    print('--- _searchPublicTransitRouteWithODsay 함수 시작 ---');

    if (_originLocation == null) {
      print('DEBUG: 출발지 좌표가 null입니다.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출발지를 먼저 설정하거나 검색해주세요.')),
        );
      }
      return;
    }
    if (_destinationLocation == null) {
      print('DEBUG: 목적지 좌표가 null입니다.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('목적지를 먼저 입력하고 검색해주세요.')),
        );
      }
      return;
    }

    print('DEBUG: 출발지: ${_originLocation!.latitude}, ${_originLocation!.longitude}');
    print('DEBUG: 목적지: ${_destinationLocation!.latitude}, ${_destinationLocation!.longitude}');

    final String url =
        'https://api.odsay.com/v1/api/searchPubTransPath?SX=${_originLocation!.longitude}&SY=${_originLocation!.latitude}&EX=${_destinationLocation!.longitude}&EY=${_destinationLocation!.latitude}&apiKey=$odsayApiKey&OPT=0'; // OPT=0 최적경로

    print('DEBUG: ODsay API 호출 URL: $url');

    String routeResultTextForDialog = '';
    List<Map<String, double>> routeCoordinatesForMap = [];

    try {
      final response = await http.get(Uri.parse(url));
      print('DEBUG: ODsay API 응답 받음. StatusCode: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        // print('ODsay API Response: ${response.body.substring(0, (response.body.length > 500) ? 500 : response.body.length)}...');

        if (decodedData['error'] != null) {
          routeResultTextForDialog = 'ODsay API 오류: ${decodedData['error']['message']} (코드: ${decodedData['error']['code']})';
          print('ODsay API Error Response: ${response.body}');
        } else if (decodedData['result'] != null &&
            decodedData['result']['path'] != null) {
          final List paths = decodedData['result']['path'];
          if (paths.isNotEmpty) {
            final firstPath = paths.first;
            routeResultTextForDialog += 'ODsay 검색 결과 (첫 번째 경로):\n';
            routeResultTextForDialog += '총 소요 시간: ${firstPath['info']['totalTime']}분\n';
            routeResultTextForDialog += '총 요금: ${firstPath['info']['payment']}원\n'; // 'payment' 필드 사용
            routeResultTextForDialog += '총 이동 거리: ${firstPath['info']['totalDistance']}m\n';
            routeResultTextForDialog += '총 도보 시간: ${firstPath['info']['totalWalkTime']}분\n';

            // 경로 상세 정보 텍스트 구성
            final List<dynamic> subPaths = firstPath['subPath'];
            for (var sp in subPaths) {
              if (sp['trafficType'] == 1) { // 지하철
                routeResultTextForDialog += '- [지하철 ${sp['lane'][0]['name']}] ${sp['startName']}역 -> ${sp['endName']}역 (${sp['sectionTime']}분)\n';
              } else if (sp['trafficType'] == 2) { // 버스
                routeResultTextForDialog += '- [버스 ${sp['lane'][0]['busNo']}] ${sp['startName']} 정류장 승차 -> ${sp['endName']} 정류장 하차 (${sp['sectionTime']}분)\n';
              } else if (sp['trafficType'] == 3) { // 도보
                routeResultTextForDialog += '- [도보] ${sp['distance']}m 이동 (${sp['sectionTime']}분)\n';
              }
            }


            // 지도에 표시할 경로 좌표 추출
            routeCoordinatesForMap.add({'lat': _originLocation!.latitude, 'lon': _originLocation!.longitude});

            for (var subPath in subPaths) {
              // subPath의 시작점, 중간 경유지(passStopList), 끝점 좌표를 추가합니다.
              // ODsay 응답에서 'x', 'y' 좌표는 경도(longitude), 위도(latitude) 순서입니다.
              if (subPath['startX'] != null && subPath['startY'] != null) {
                routeCoordinatesForMap.add({'lat': double.parse(subPath['startY'].toString()), 'lon': double.parse(subPath['startX'].toString())});
              }

              // passStopList (경유 정류장/역) 좌표 추출 (있는 경우)
              if (subPath['passStopList'] != null && subPath['passStopList']['stations'] != null) {
                List<dynamic> stations = subPath['passStopList']['stations'];
                for (var station in stations) {
                  if (station['x'] != null && station['y'] != null) {
                    routeCoordinatesForMap.add({'lat': double.parse(station['y'].toString()), 'lon': double.parse(station['x'].toString())});
                  }
                }
              }

              if (subPath['endX'] != null && subPath['endY'] != null) {
                routeCoordinatesForMap.add({'lat': double.parse(subPath['endY'].toString()), 'lon': double.parse(subPath['endX'].toString())});
              }
            }
            routeCoordinatesForMap.add({'lat': _destinationLocation!.latitude, 'lon': _destinationLocation!.longitude});

            // 중복 제거 및 순서 유지를 위해 Set을 사용하지 않고, 연속된 중복만 제거하는 방식을 고려하거나,
            // 또는 Tmap Web API의 경로 그리기 기능이 중복을 알아서 처리하도록 기대할 수 있습니다.
            // 여기서는 일단 그대로 전달합니다.
            // List<Map<String, double>> uniqueCoordinates = [];
            // if (routeCoordinatesForMap.isNotEmpty) {
            //   uniqueCoordinates.add(routeCoordinatesForMap.first);
            //   for (int i = 1; i < routeCoordinatesForMap.length; i++) {
            //     if (routeCoordinatesForMap[i]['lat'] != routeCoordinatesForMap[i-1]['lat'] ||
            //         routeCoordinatesForMap[i]['lon'] != routeCoordinatesForMap[i-1]['lon']) {
            //       uniqueCoordinates.add(routeCoordinatesForMap[i]);
            //     }
            //   }
            // }
            // routeCoordinatesForMap = uniqueCoordinates;


            if (_isWebViewReady && _webViewController != null && routeCoordinatesForMap.length >= 2) {
              String routePointsJson = jsonEncode(routeCoordinatesForMap);
              // JSON 문자열 내의 특수문자(따옴표 등) 문제를 피하기 위해 Base64 인코딩 후 전달하는 방법도 고려할 수 있습니다.
              // 여기서는 직접 전달합니다. JavaScript에서 JSON.parse 시 오류가 발생하면 이 부분을 확인해야 합니다.
              _webViewController!.runJavaScript('drawPath(\'$routePointsJson\');');
              print('DEBUG: WebView에 경로 그리기 요청 (좌표 ${routeCoordinatesForMap.length}개)');
            } else {
              print('DEBUG: WebView가 준비되지 않았거나 경로 좌표가 부족하여 지도에 표시할 수 없습니다.');
              if (routeCoordinatesForMap.length < 2) {
                routeResultTextForDialog += "\n(지도에 경로를 표시하기에는 좌표 정보가 부족합니다.)";
              }
            }

          } else {
            routeResultTextForDialog = '해당하는 대중교통 경로가 없습니다.';
          }
        } else {
          routeResultTextForDialog = 'ODsay 검색 결과 형식이 올바르지 않습니다.';
          print('ODsay API Unexpected Response: ${response.body}');
        }
      } else {
        routeResultTextForDialog = 'ODsay API 호출 실패: ${response.statusCode}\n${response.body}';
        print('ODsay API Error: ${response.body}');
      }
    } catch (e, stacktrace) {
      routeResultTextForDialog = '경로 탐색 중 오류 발생: $e';
      print('EXCEPTION: ODsay API Request Error: $e');
      print('STACKTRACE: $stacktrace');
    }

    _showRouteResultDialog(routeResultTextForDialog);
    print('--- _searchPublicTransitRouteWithODsay 함수 종료 ---');
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('앱 내 Tmap 지도 경로 테스트')),
      body: Column(
        children: [
          Expanded(
            child: _webViewController != null
                ? WebViewWidget(controller: _webViewController!)
                : const Center(child: CircularProgressIndicator(semanticsLabel: "지도 로딩 중",)),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _currentLocation != null
                        ? '현재: ${_currentLocation!.latitude.toStringAsFixed(5)}, ${_currentLocation!.longitude.toStringAsFixed(5)}'
                        : '현재 위치 로딩 중...',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    _originLocation != null
                        ? '출발: ${_originController.text} (${_originLocation!.latitude.toStringAsFixed(5)}, ${_originLocation!.longitude.toStringAsFixed(5)})'
                        : '출발지 미설정',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    _destinationLocation != null
                        ? '도착: ${_destinationController.text} (${_destinationLocation!.latitude.toStringAsFixed(5)}, ${_destinationLocation!.longitude.toStringAsFixed(5)})'
                        : '목적지 미설정',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  ElevatedButton(
                    onPressed: _getCurrentLocation,
                    child: const Text('현재위치로 출발지 설정 & 지도중심'),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _originController,
                        decoration: const InputDecoration(
                            labelText: '출발지 지명', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0)),
                        onSubmitted: (value) => _searchOriginCoordinates(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _searchOriginCoordinates, child: const Text('검색')),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _destinationController,
                        decoration: const InputDecoration(
                            labelText: '목적지 지명', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0)),
                        onSubmitted: (value) => _searchDestinationCoordinates(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _searchDestinationCoordinates, child: const Text('검색')),
                  ]),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (!_isWebViewReady) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('지도가 아직 로딩 중입니다.')),
                        );
                        return;
                      }
                      _searchPublicTransitRouteWithODsay();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('ODsay 경로 탐색 및 지도에 표시', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}