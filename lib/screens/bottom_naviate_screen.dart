import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:maptest/services/route_service.dart';

const String KAKAO_REST_API_KEY = '4245537ef826b9dd79d729df8fa5c2a3';

class BottomNavigateScreen extends StatefulWidget {
  const BottomNavigateScreen({super.key});

  @override
  State<BottomNavigateScreen> createState() => _BottomNavigateScreenState();
}

class PlaceCandidate {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  PlaceCandidate({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class _BottomNavigateScreenState extends State<BottomNavigateScreen> {
  final FlutterTts _tts = FlutterTts();

  String recognizedText = '';
  NLatLng? _currentLocation;

  late stt.SpeechToText _speech;
  bool _isTtsSpeaking = false;
  bool _isReadyForDoubleTap = false;
  bool _navigating = false;

  bool isModeSelected = false;
  bool isTextMode = false;
  final TextEditingController _textController = TextEditingController();

  List<List<String>>? guideRoutes;
  List<bool> routeExpanded = [];
  int selectedRouteIndex = -1;

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _speech = stt.SpeechToText();
    _getCurrentLocation();
  }

  void _initializeTTS() {
    _tts.setLanguage("ko-KR");
    _tts.setSpeechRate(0.5);
    _tts.setStartHandler(() => _isTtsSpeaking = true);
    _tts.setCompletionHandler(() => _isTtsSpeaking = false);
  }

  Future<void> _speak(String text) async => await _tts.speak(text);

  Future<void> _speakThen(Function callback, String text) async {
    await _tts.speak(text);
    while (_isTtsSpeaking) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    callback();
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('STT status: $status'),
      onError: (error) => print('STT error: $error'),
    );
    if (available) {
      _startListening();
    } else {
      _speak('음성 인식을 사용할 수 없습니다.');
    }
  }

  void _startListening() {
    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          recognizedText = result.recognizedWords;
          _speech.stop();
          _speakThen(
            () => setState(() => _isReadyForDoubleTap = true),
            '$recognizedText이 맞으신가요? 맞으시다면 화면을 두 번 터치해주세요.\n혹시 잘못 인식되었다면, 아래의 버튼을 눌러 다시 입력해주세요.',
          );
        }
      },
      localeId: 'ko_KR',
      partialResults: true,
      cancelOnError: false,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 10),
      listenMode: stt.ListenMode.dictation,
    );
  }

  Future<void> _handleDoubleTap() async {
    if (_navigating ||
        !_isReadyForDoubleTap ||
        _isTtsSpeaking ||
        recognizedText.isEmpty)
      return;
    _navigating = true;
    await _speak('$recognizedText로 경로를 안내합니다.');

    try {
      final List<PlaceCandidate> places = await searchKakaoPlaces(
        recognizedText,
      );

      if (places.isEmpty) {
        _speak("목적지 위치를 찾을 수 없습니다. 가게명과 지명을 함께 입력하면 더 정확한 결과를 얻을 수 있습니다.");
        return;
      }

      // 스마트 정렬: 정확 일치 먼저, 나머지는 거리순
      if (_currentLocation != null && places.length > 1) {
        sortCandidatesSmart(places, _currentLocation!, recognizedText);
      }

      if (places.length == 1) {
        final single = places.first;
        _startRoutingTo(NLatLng(single.latitude, single.longitude));
      } else {
        _showKakaoLocationSelection(places);
      }
    } catch (e) {
      print("위치 변환 오류: $e");
      _speak("목적지 변환 중 오류가 발생했습니다.");
    }
  }

  // 카카오 장소 검색 API
  Future<List<PlaceCandidate>> searchKakaoPlaces(String query) async {
    final apiUrl =
        'https://dapi.kakao.com/v2/local/search/keyword.json?query=${Uri.encodeComponent(query)}';
    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {'Authorization': 'KakaoAK $KAKAO_REST_API_KEY'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List docs = data['documents'] ?? [];
      return docs
          .map(
            (place) => PlaceCandidate(
              name: place['place_name'] ?? '',
              address:
                  place['road_address_name'] ?? place['address_name'] ?? '',
              latitude: double.tryParse(place['y'] ?? '') ?? 0.0,
              longitude: double.tryParse(place['x'] ?? '') ?? 0.0,
            ),
          )
          .where((p) => p.latitude != 0.0 && p.longitude != 0.0)
          .toList();
    } else {
      print(response.body);
      throw Exception('카카오 장소검색 실패: ${response.body}');
    }
  }

  // 거리 계산 (Haversine 공식)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // 지구 반지름 (m)
    final double dLat = (lat2 - lat1) * (pi / 180);
    final double dLon = (lon2 - lon1) * (pi / 180);
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  // 스마트 정렬: 입력값과 정확 일치한 이름을 1순위로, 나머지는 거리순 정렬
  void sortCandidatesSmart(
    List<PlaceCandidate> places,
    NLatLng currentLocation,
    String keyword,
  ) {
    final exactMatches =
        places.where((p) => p.name.trim() == keyword.trim()).toList();
    final others =
        places.where((p) => p.name.trim() != keyword.trim()).toList();

    others.sort((a, b) {
      final distA = calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        a.latitude,
        a.longitude,
      );
      final distB = calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        b.latitude,
        b.longitude,
      );
      return distA.compareTo(distB);
    });

    places
      ..clear()
      ..addAll(exactMatches)
      ..addAll(others);
  }

  void _showKakaoLocationSelection(List<PlaceCandidate> places) async {
    await _speak('검색 결과, ${places.length}가지의 후보가 있습니다. 화면에서 원하는 장소를 선택해 주세요.');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder:
          (_) => ListView.builder(
            itemCount: places.length,
            itemBuilder: (context, index) {
              final p = places[index];
              String distanceString = '';
              if (_currentLocation != null) {
                final distance = calculateDistance(
                  _currentLocation!.latitude,
                  _currentLocation!.longitude,
                  p.latitude,
                  p.longitude,
                );
                if (distance < 1000) {
                  distanceString = "  📍${distance.toStringAsFixed(0)}m";
                } else {
                  distanceString =
                      "  📍${(distance / 1000).toStringAsFixed(1)}km";
                }
              }
              return Semantics(
                label: '${index + 1}번, ${p.name}, ${p.address}',
                child: ListTile(
                  title: Text('${p.name}$distanceString'),
                  subtitle: Text(
                    '${p.address}\n위도: ${p.latitude}, 경도: ${p.longitude}',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _startRoutingTo(NLatLng(p.latitude, p.longitude));
                  },
                ),
              );
            },
          ),
    );
  }

  void _startRoutingTo(NLatLng dest) async {
    if (_currentLocation != null) {
      final routes = await getAllTransitRoutes(
        {'lat': _currentLocation!.latitude, 'lng': _currentLocation!.longitude},
        {'lat': dest.latitude, 'lng': dest.longitude},
      );
      setState(() {
        guideRoutes = routes;
        selectedRouteIndex = -1;
        routeExpanded = List.generate(routes.length, (_) => false);
      });
    }
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
        setState(
          () =>
              _currentLocation = NLatLng(position.latitude, position.longitude),
        );
      } catch (e) {
        _speak('위치 정보를 가져오지 못했습니다.');
      }
    } else {
      _speak('위치 권한이 필요합니다. 설정에서 허용해주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('경로 설정'),
        backgroundColor: Colors.deepPurple,
      ),
      body:
          guideRoutes != null
              ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: guideRoutes!.length,
                itemBuilder: (context, index) {
                  final route = guideRoutes![index];
                  final summary = route.isNotEmpty ? route.first : '경로 요약 없음';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD400),
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(
                              () =>
                                  routeExpanded[index] = !routeExpanded[index],
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '경로 ${index + 1}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Text(
                                    summary,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (routeExpanded[index])
                          Column(
                            children: [
                              ...route
                                  .skip(1)
                                  .map(
                                    (line) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                        horizontal: 12,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          line,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                ),
                                onPressed: () async {
                                  await _speak('실시간 경로 안내를 시작합니다.');
                                  for (final line in route) {
                                    await _speak(line);
                                  }
                                },
                                child: const Text('🚀 실시간 경로 안내'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              )
              : !isModeSelected
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          isModeSelected = true;
                          isTextMode = false;
                          _speakThen(
                            () => _initializeSpeech(),
                            '목적지를 말씀해주세요. 더 정확한 검색을 위해 가게명과 지명을 함께 말씀하시면 좋습니다.',
                          );
                        });
                      },
                      icon: const Icon(Icons.mic),
                      label: const Text('음성으로 목적지 입력하기'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          isModeSelected = true;
                          isTextMode = true;
                        });
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('텍스트로 목적지 입력하기'),
                    ),
                  ],
                ),
              )
              : isTextMode
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: '목적지를 입력하세요 (예: 스타벅스 하단역)',
                          hintStyle: TextStyle(color: Colors.white54),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white54),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            recognizedText = _textController.text;
                            _isReadyForDoubleTap = true;
                          });
                          _handleDoubleTap();
                        },
                        child: const Text('경로 안내 시작'),
                      ),
                    ],
                  ),
                ),
              )
              : Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: _handleDoubleTap,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        recognizedText.isEmpty
                            ? '말씀해주세요...'
                            : '입력된 목적지: $recognizedText',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (_isReadyForDoubleTap &&
                          !_isTtsSpeaking &&
                          recognizedText.isNotEmpty)
                        ElevatedButton(
                          onPressed: _handleDoubleTap,
                          child: const Text('경로 안내 시작'),
                        ),
                      if (_isReadyForDoubleTap &&
                          !_isTtsSpeaking &&
                          recognizedText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                recognizedText = '';
                                _isReadyForDoubleTap = false;
                                _startListening();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[700],
                            ),
                            child: const Text('다시 말하기'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
    );
  }
}
