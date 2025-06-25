import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:maptest/services/route_service.dart';
import 'package:maptest/screens/firestore_steps_screen.dart';
import '../screens/tts_manager.dart';

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
  final Completer<NaverMapController> _mapController = Completer();

  String recognizedText = '';
  NLatLng? _currentLocation;

  late stt.SpeechToText _speech;
  bool _isTtsSpeaking = false;
  bool _isReadyForDoubleTap = false;
  bool _navigating = false;

  bool isModeSelected = false;
  bool isTextMode = false;
  final TextEditingController _textController = TextEditingController();

  List<Map<String, dynamic>>? guideRoutes;
  List<bool> routeExpanded = [];

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

  Future<void> _speak(String text) async => await TtsManager.speakIfEnabled(_tts, text);

  Future<void> _speakThen(Function callback, String text) async {
    await _speak(text);
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
          _speakThen(() => setState(() => _isReadyForDoubleTap = true), '$recognizedText이 맞으신가요? 화면을 두 번 터치해주세요.');
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
    if (_navigating || !_isReadyForDoubleTap || _isTtsSpeaking || recognizedText.isEmpty) return;
    _navigating = true;
    await _speak('$recognizedText로 경로를 안내합니다.');

    try {
      final List<PlaceCandidate> places = await searchKakaoPlaces(recognizedText);

      if (places.isEmpty) {
        await _speak("목적지 위치를 찾을 수 없습니다. 가게명과 지명을 함께 말씀해 주세요.");
        setState(() {
          _navigating = false;
          _isReadyForDoubleTap = true;
        });
        return;
      }

      if (_currentLocation != null && places.length > 1) {
        sortCandidatesSmart(places, _currentLocation!, recognizedText);
      }

      await _speak('검색된 장소는 총 ${places.length}개입니다.');

      if (places.length == 1) {
        _startRoutingTo(NLatLng(places.first.latitude, places.first.longitude));
      } else {
        _showLocationSelection(places);
      }
    } catch (e) {
      print("위치 변환 오류: $e");
      _speak("목적지 변환 중 오류가 발생했습니다.");
      setState(() {
        _navigating = false;
        _isReadyForDoubleTap = true;
      });
    }
  }

  Future<List<PlaceCandidate>> searchKakaoPlaces(String query) async {
    final url = 'https://dapi.kakao.com/v2/local/search/keyword.json?query=${Uri.encodeComponent(query)}';
    final response = await http.get(Uri.parse(url), headers: {'Authorization': 'KakaoAK $KAKAO_REST_API_KEY'});

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List docs = data['documents'] ?? [];
      return docs.map((place) => PlaceCandidate(
        name: place['place_name'] ?? '',
        address: place['road_address_name'] ?? place['address_name'] ?? '',
        latitude: double.tryParse(place['y'] ?? '') ?? 0.0,
        longitude: double.tryParse(place['x'] ?? '') ?? 0.0,
      )).where((p) => p.latitude != 0.0 && p.longitude != 0.0).toList();
    } else {
      throw Exception('카카오 장소 검색 실패: ${response.body}');
    }
  }

  void sortCandidatesSmart(List<PlaceCandidate> places, NLatLng current, String keyword) {
    final exact = places.where((p) => p.name.trim() == keyword.trim()).toList();
    final others = places.where((p) => p.name.trim() != keyword.trim()).toList();

    others.sort((a, b) => calculateDistance(current, a).compareTo(calculateDistance(current, b)));
    places..clear()..addAll(exact)..addAll(others);
  }

  double calculateDistance(NLatLng from, PlaceCandidate to) {
    const double R = 6371000;
    final double dLat = (to.latitude - from.latitude) * pi / 180;
    final double dLon = (to.longitude - from.longitude) * pi / 180;
    final double a = sin(dLat / 2) * sin(dLat / 2) + cos(from.latitude * pi / 180) * cos(to.latitude * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  String formatDistance(double distanceMeters) {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
    } else {
      return '${distanceMeters.toStringAsFixed(0)}m';
    }
  }

  void _showLocationSelection(List<PlaceCandidate> places) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) => ListView.builder(
        itemCount: places.length,
        itemBuilder: (context, index) {
          final p = places[index];
          final distance = formatDistance(calculateDistance(_currentLocation!, p));
          return ListTile(
            title: Text('${p.name}'),
            subtitle: Text('${p.address}\n거리: $distance'),
            onTap: () {
              Navigator.pop(context);
              _startRoutingTo(NLatLng(p.latitude, p.longitude));
            },
          );
        },
      ),
    ).whenComplete(() {
      setState(() {
        _navigating = false;
        _isReadyForDoubleTap = true;
      });
    });
  }

  void _startRoutingTo(NLatLng dest) async {
    if (_currentLocation != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _speak("사용자 정보를 확인할 수 없습니다.");
        return;
      }
      final routes = await generateAllHybridRoutes(
        {'lat': _currentLocation!.latitude, 'lng': _currentLocation!.longitude},
        {'lat': dest.latitude, 'lng': dest.longitude},
      );
      setState(() {
        guideRoutes = routes;
        routeExpanded = List.generate(routes.length, (_) => false);
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      try {
        final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
        setState(() => _currentLocation = NLatLng(position.latitude, position.longitude));
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
      appBar: AppBar(title: const Text('경로 설정'), backgroundColor: Colors.deepPurple),
      body: guideRoutes != null ? _buildRouteList() : _buildModeSelection(),
    );
  }

  Widget _buildRouteList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: guideRoutes!.length,
      itemBuilder: (context, index) {
        final route = guideRoutes![index];
        final summary = route['lines'].isNotEmpty ? route['lines'][0] : '경로 요약 없음';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD400),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => setState(() => routeExpanded[index] = !routeExpanded[index]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('경로 ${index + 1}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    Flexible(child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(summary, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black)),
                    )),
                  ],
                ),
              ),
              if (routeExpanded[index])
                Column(
                  children: [
                    ...route['lines'].skip(1).map<Widget>((line) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
                      child: Align(alignment: Alignment.centerLeft, child: Text(line, style: const TextStyle(color: Colors.white))),
                    )),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                      onPressed: () async {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        final routeId = route['route_id'];
                        if (uid != null && routeId != null) {
                          await _speak('실시간 경로 안내를 시작합니다.');
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => FirestoreStepsScreen(uid: uid, routeId: routeId)),
                          );
                          if (result == true) {
                            setState(() {
                              guideRoutes = null;
                              isModeSelected = true;
                              isTextMode = false;
                              _isReadyForDoubleTap = false;
                              recognizedText = '';
                            });
                            await _speak('다시 목적지를 말씀해주세요.');
                            _initializeSpeech();
                          }
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
    );
  }

  Widget _buildModeSelection() {
    return !isModeSelected ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                isModeSelected = true;
                isTextMode = false;
                _speakThen(() => _initializeSpeech(), '목적지를 말씀해주세요.');
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
    ) : isTextMode ? _buildTextInputMode() : _buildSpeechPrompt();
  }

  Widget _buildTextInputMode() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: '목적지를 입력하세요',
                hintStyle: TextStyle(color: Colors.white54),
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
    );
  }

  Widget _buildSpeechPrompt() {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: _handleDoubleTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              recognizedText.isEmpty ? '말씀해주세요...' : '입력된 목적지: $recognizedText',
              style: const TextStyle(color: Colors.white, fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_isReadyForDoubleTap && !_isTtsSpeaking && recognizedText.isNotEmpty)
              ElevatedButton(
                onPressed: _handleDoubleTap,
                child: const Text('경로 안내 시작'),
              ),
            const SizedBox(height: 20),
            if (!_isTtsSpeaking && !_isReadyForDoubleTap)
              ElevatedButton(
                onPressed: () => _initializeSpeech(),
                child: const Text('다시 말하기'),
              ),
          ],
        ),
      ),
    );
  }
}