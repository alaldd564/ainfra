import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:geocoding/geocoding.dart';
import 'package:maptest/services/route_service.dart';

class BottomNavigateScreen extends StatefulWidget {
  const BottomNavigateScreen({super.key});

  @override
  State<BottomNavigateScreen> createState() => _BottomNavigateScreenState();
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
          _speakThen(() => setState(() => _isReadyForDoubleTap = true),
              '$recognizedText이 맞으신가요? 맞으시다면 화면을 두 번 터치해주세요.');
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
      final locations = await locationFromAddress(recognizedText);
      if (locations.isEmpty) {
        _speak("목적지 위치를 찾을 수 없습니다.");
        return;
      }

      if (locations.length == 1) {
        _startRoutingTo(locations.first);
      } else {
        _showLocationSelection(locations);
      }
    } catch (e) {
      print("위치 변환 오류: $e");
      _speak("목적지 변환 중 오류가 발생했습니다.");
    }
  }

  void _showLocationSelection(List<Location> locations) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) => ListView.builder(
        itemCount: locations.length,
        itemBuilder: (context, index) {
          final loc = locations[index];
          final locText = '위도: ${loc.latitude}, 경도: ${loc.longitude}';
          return Semantics(
            label: '지점 ${index + 1}, ${locText}',
            child: ListTile(
              title: Text('지점 ${index + 1}'),
              subtitle: Text(locText),
              onTap: () {
                Navigator.pop(context);
                _startRoutingTo(loc);
              },
            ),
          );
        },
      ),
    );
  }

  void _startRoutingTo(Location dest) async {
    final destination = NLatLng(dest.latitude, dest.longitude);
    if (_currentLocation != null) {
      final routes = await generateAllHybridRoutes(
        {
          'lat': _currentLocation!.latitude,
          'lng': _currentLocation!.longitude,
        },
        {
          'lat': destination.latitude,
          'lng': destination.longitude,
        },
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
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
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
      appBar: AppBar(
        title: const Text('경로 설정'),
        backgroundColor: Colors.deepPurple,
      ),
      body: guideRoutes != null
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          setState(() => routeExpanded[index] = !routeExpanded[index]);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('경로 ${index + 1}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                            ...route.skip(1).map((line) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(line, style: const TextStyle(color: Colors.white)),
                                  ),
                                )),
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
                            )
                          ],
                        )
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
                                hintText: '목적지를 입력하세요',
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
                          ],
                        ),
                      ),
                    ),
    );
  }
}
