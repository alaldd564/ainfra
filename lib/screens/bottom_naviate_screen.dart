import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';

class BottomNavigateScreen extends StatefulWidget {
  const BottomNavigateScreen({super.key});

  @override
  State<BottomNavigateScreen> createState() => _BottomNavigateScreenState();
}

class _BottomNavigateScreenState extends State<BottomNavigateScreen> {
  final FlutterTts _tts = FlutterTts();
  final Completer<NaverMapController> _mapController = Completer();

  String recognizedText = '';
  bool showMap = false;
  NLatLng? _currentLocation;

  late stt.SpeechToText _speech;
  bool _isTtsSpeaking = false;
  bool _isReadyForDoubleTap = false;
  bool _navigating = false; // 중복 실행 방지용

  @override
  void initState() {
    super.initState();

    _tts.setLanguage("ko-KR");
    _tts.setSpeechRate(0.5);

    _tts.setStartHandler(() {
      _isTtsSpeaking = true;
    });

    _tts.setCompletionHandler(() {
      _isTtsSpeaking = false;
    });

    _speech = stt.SpeechToText();

    _speakThen(() {
      _initializeSpeech(); // TTS 끝나고 음성 인식 시작
    }, '목적지를 말씀해주세요.');

    _getCurrentLocation();
  }

  // ✅ 추가됨: 마이크 권한 요청 함수
  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      await _speak('마이크 권한이 필요합니다. 설정에서 허용해주세요.');
    }
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> _speakThen(Function callback, String text) async {
    await _tts.speak(text);
    while (_isTtsSpeaking) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    callback();
  }

  // ✅ STT 추가: 음성 인식 초기화
  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        print('STT status: $status');
      },
      onError: (error) => print('STT error: $error'),
    );

    if (available) {
      _startListening(); // ✅ STT 추가
    } else {
      _speak('음성 인식을 사용할 수 없습니다.');
    }
  }

  // ✅ STT 추가: 음성 인식 시작
  void _startListening() {
    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          recognizedText = result.recognizedWords;
          _speech.stop();

          _speakThen(() {
            setState(() {
              _isReadyForDoubleTap = true;
            });
          }, '$recognizedText이 맞으신가요? 맞으시다면 화면을 두 번 터치해주세요.');
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

  void _handleDoubleTap() async {
    // ✅ 추가: 더블탭 핸들러 분리
    if (_navigating ||
        !_isReadyForDoubleTap ||
        _isTtsSpeaking ||
        recognizedText.isEmpty)
      return;
    _navigating = true;
    await _speak('$recognizedText로 경로를 안내합니다.');
    setState(() {
      showMap = true;
    });
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
        setState(() {
          _currentLocation = NLatLng(position.latitude, position.longitude);
        });
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
          showMap
              ? (_currentLocation == null
                  ? const Center(child: CircularProgressIndicator())
                  : NaverMap(
                    onMapReady: (controller) {
                      _mapController.complete(controller);
                    },
                    options: NaverMapViewOptions(
                      initialCameraPosition: NCameraPosition(
                        target: _currentLocation!,
                        zoom: 16,
                      ),
                      locationButtonEnable: true,
                    ),
                  ))
              : Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque, // ✅ 추가: 빈 공간도 탭 인식
                  onDoubleTap: _handleDoubleTap, // ✅ 수정: 별도 함수로 분리
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
                          recognizedText.isNotEmpty) // ✅ 선택적 보조 버튼
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
