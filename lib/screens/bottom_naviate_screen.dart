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
import 'package:cloud_firestore/cloud_firestore.dart';
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

  List<Map<String, dynamic>> _frequentPlaces = [];

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _speech = stt.SpeechToText();
    _getCurrentLocation();
    _loadFrequentPlaces();
  }

  // 🔹 장소 검색용 입력창 (자주 가는 장소 등록용)
  Future<String?> _showPlaceSearchDialog(BuildContext context) async {
    String query = '';
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('장소 검색'),
            content: TextField(
              autofocus: true,
              onChanged: (value) => query = value,
              decoration: const InputDecoration(hintText: '등록할 장소를 검색해주세요'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, query),
                child: const Text('검색'),
              ),
            ],
          ),
    );
  }

  // 🔹 장소 저장용 입력창
  Future<String?> _showNameInputDialog(BuildContext context) async {
    String inputName = '';
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('장소 이름 입력'),
            content: TextField(
              autofocus: true,
              onChanged: (value) => inputName = value,
              decoration: const InputDecoration(hintText: '예: 집, 회사'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, inputName),
                child: const Text('저장'),
              ),
            ],
          ),
    );
  }

  // 🔹 장소 검색 결과 중 선택 후 저장
  void _showSearchResultsForSaving(List<PlaceCandidate> places) {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => ListView.builder(
            itemCount: places.length,
            itemBuilder: (context, index) {
              final place = places[index];
              return ListTile(
                title: Text(place.name),
                subtitle: Text(place.address),
                onTap: () async {
                  final name = await _showNameInputDialog(context);
                  if (name == null || name.trim().isEmpty) return;

                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) return;

                  final placeData = {
                    'lat': place.latitude,
                    'lng': place.longitude,
                    'added_at': FieldValue.serverTimestamp(),
                  };

                  await FirebaseFirestore.instance
                      .collection('frequent_places')
                      .doc(uid)
                      .set({name.trim(): placeData}, SetOptions(merge: true));

                  await _loadFrequentPlaces();
                  Navigator.pop(context);
                  await _speak('$name 장소를 저장했습니다.');
                },
              );
            },
          ),
    );
  }

  // 🔹 장소 저장 로직 (검색 기반)
  Future<void> _searchAndSavePlace(String query) async {
    final places = await searchKakaoPlaces(query);
    if (places.isEmpty) {
      await _speak('검색 결과가 없습니다.');
      return;
    }
    _showSearchResultsForSaving(places);
  }

  // 🔹 현재 위치 저장
  Future<void> _saveCurrentLocationAsFrequentPlace(
    BuildContext context,
    NLatLng? currentLocation,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || currentLocation == null) {
      await TtsManager.speakIfEnabled(_tts, '사용자 정보나 현재 위치가 없습니다.');
      return;
    }

    final name = await _showNameInputDialog(context);
    if (name == null || name.trim().isEmpty) return;

    final placeData = {
      'lat': currentLocation.latitude,
      'lng': currentLocation.longitude,
      'added_at': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection('frequent_places').doc(uid).set(
      {name.trim(): placeData},
      SetOptions(merge: true),
    );

    await _loadFrequentPlaces();
    await TtsManager.speakIfEnabled(_tts, '$name 장소를 저장했습니다.');
  }

  Future<void> _loadFrequentPlaces() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('frequent_places')
            .doc(uid)
            .get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      setState(() {
        _frequentPlaces =
            data.entries.map((e) {
              final v = e.value;
              return {'name': e.key, 'lat': v['lat'], 'lng': v['lng']};
            }).toList();
      });
    }
  }

  // 🔸 자주 가는 장소 삭제 함수 추가
  Future<void> _deleteFrequentPlace(String name) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('frequent_places')
        .doc(uid);
    await docRef.update({name: FieldValue.delete()});

    await _loadFrequentPlaces();
    await _speak('$name 장소를 삭제했습니다.');
  }

  // 🔹 UI: 장소 검색 후 자주 가는 장소로 저장 버튼 동작
  Future<void> _handleSearchAndSaveButtonPressed() async {
    final query = await _showPlaceSearchDialog(context);
    if (query != null && query.trim().isNotEmpty) {
      _searchAndSavePlace(query.trim());
    }
  }

  // 🔹 장소 등록 방식 선택 다이얼로그는 State 클래스 내에 위치 (예: _saveCurrentLocationAsFrequentPlace 아래)
  void _handleUnifiedSaveButtonPressed() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("장소 등록 방식 선택"),
            content: const Text("어떤 방식으로 자주 가는 장소를 등록할까요?"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveCurrentLocationAsFrequentPlace(
                    context,
                    _currentLocation,
                  );
                },
                child: const Text("📍 현재 위치 저장"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleSearchAndSaveButtonPressed();
                },
                child: const Text("🔍 장소 검색 후 저장"),
              ),
            ],
          ),
    );
  }

  void _initializeTTS() {
    _tts.setLanguage("ko-KR");
    _tts.setSpeechRate(0.5);
    _tts.setStartHandler(() => _isTtsSpeaking = true);
    _tts.setCompletionHandler(() => _isTtsSpeaking = false);
  }

  Future<void> _speak(String text) async =>
      await TtsManager.speakIfEnabled(_tts, text);

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
          _speakThen(
            () => setState(() => _isReadyForDoubleTap = true),
            '$recognizedText이 맞으신가요? 화면을 두 번 터치해주세요.',
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
    final url =
        'https://dapi.kakao.com/v2/local/search/keyword.json?query=${Uri.encodeComponent(query)}';
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'KakaoAK $KAKAO_REST_API_KEY'},
    );

    print('📥 응답 상태 코드: ${response.statusCode}');
    print('📥 응답 본문: ${response.body}');

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
      throw Exception('카카오 장소 검색 실패: ${response.body}');
    }
  }

  void sortCandidatesSmart(
    List<PlaceCandidate> places,
    NLatLng current,
    String keyword,
  ) {
    final exact = places.where((p) => p.name.trim() == keyword.trim()).toList();
    final others =
        places.where((p) => p.name.trim() != keyword.trim()).toList();

    others.sort(
      (a, b) => calculateDistance(
        current,
        a,
      ).compareTo(calculateDistance(current, b)),
    );
    places
      ..clear()
      ..addAll(exact)
      ..addAll(others);
  }

  double calculateDistance(NLatLng from, PlaceCandidate to) {
    const double R = 6371000;
    final double dLat = (to.latitude - from.latitude) * pi / 180;
    final double dLon = (to.longitude - from.longitude) * pi / 180;
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(from.latitude * pi / 180) *
            cos(to.latitude * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
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
      builder:
          (_) => ListView.builder(
            itemCount: places.length,
            itemBuilder: (context, index) {
              final p = places[index];
              final distance = formatDistance(
                calculateDistance(_currentLocation!, p),
              );
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
      body: guideRoutes != null ? _buildRouteList() : _buildModeSelection(),
    );
  }

  Widget _buildRouteList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: guideRoutes!.length,
      itemBuilder: (context, index) {
        final route = guideRoutes![index];
        final summary =
            route['lines'].isNotEmpty ? route['lines'][0] : '경로 요약 없음';

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
                onPressed:
                    () => setState(
                      () => routeExpanded[index] = !routeExpanded[index],
                    ),
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
                    ...route['lines']
                        .skip(1)
                        .map<Widget>(
                          (line) => Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 2,
                              horizontal: 12,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                line,
                                style: const TextStyle(color: Colors.white),
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
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        final routeId = route['route_id'];
                        if (uid != null && routeId != null) {
                          await _speak('실시간 경로 안내를 시작합니다.');
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => FirestoreStepsScreen(
                                    uid: uid,
                                    routeId: routeId,
                                  ),
                            ),
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
    return !isModeSelected
        ? Center(
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
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _handleUnifiedSaveButtonPressed,
                icon: const Icon(Icons.add_location_alt),
                label: const Text('자주 가는 장소 등록'),
              ),
              if (_frequentPlaces.isNotEmpty)
                Column(
                  children: [
                    const SizedBox(height: 30),
                    const Text(
                      '자주 가는 장소',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _frequentPlaces.map((place) {
                            final name = place['name'];
                            final lat = place['lat'];
                            final lng = place['lng'];

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade400,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      _startRoutingTo(NLatLng(lat, lng));
                                    },
                                    icon: const Icon(
                                      Icons.place,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder:
                                            (_) => AlertDialog(
                                              title: Text('$name 삭제'),
                                              content: const Text(
                                                '정말로 이 장소를 삭제하시겠습니까?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                      ),
                                                  child: const Text('취소'),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    Navigator.pop(context);
                                                    await _deleteFrequentPlace(
                                                      name,
                                                    );
                                                  },
                                                  child: const Text('삭제'),
                                                ),
                                              ],
                                            ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                    tooltip: '삭제',
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
            ],
          ),
        )
        : isTextMode
        ? _buildTextInputMode()
        : _buildSpeechPrompt();
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
            if (_isReadyForDoubleTap &&
                !_isTtsSpeaking &&
                recognizedText.isNotEmpty)
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
