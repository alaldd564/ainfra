import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class BottomNavigateScreen extends StatefulWidget {
  const BottomNavigateScreen({super.key});

  @override
  State<BottomNavigateScreen> createState() => _BottomNavigateScreenState();
}

class _BottomNavigateScreenState extends State<BottomNavigateScreen> {
  final FlutterTts _tts = FlutterTts();
  final Completer<NaverMapController> _mapController = Completer();
  static const platform = MethodChannel('com.example.taxi/navigation');

  String recognizedText = '';
  bool showMap = false;
  NLatLng? _currentLocation;

  late stt.SpeechToText _speech;
  bool _isTtsSpeaking = false;
  bool _isReadyForDoubleTap = false;
  bool _navigating = false; // 중복 실행 방지용

  StreamSubscription<Position>? _positionStream; // 위치 스트림 구독

  @override
  void initState() {
    super.initState();

    _tts.setLanguage("ko-KR");
    _tts.setSpeechRate(0.5);

    _tts.setStartHandler(() {
      setState(() {
        _isTtsSpeaking = true;
      });
    });

    _tts.setCompletionHandler(() {
      setState(() {
        _isTtsSpeaking = false;
      });
    });

    _speech = stt.SpeechToText();

    _speakThen(() {
      _initializeSpeech(); // TTS 끝나고 음성 인식 시작
    }, '목적지를 말씀해주세요.');

    _getCurrentLocation();
    _startLocationUpdates();
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> _speakThen(Function callback, String text) async {
    await _tts.speak(text);
    // TTS 완료까지 대기
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
      _startListening();
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

    if (_currentLocation != null) {
      try {
        await platform.invokeMethod('startNavigation', {
          'startLat': _currentLocation!.latitude,
          'startLng': _currentLocation!.longitude,
          'destination': recognizedText,
        });
      } catch (e) {
        await _speak('내비게이션을 시작하는 중 오류가 발생했습니다.');
      }
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
        setState(() {
          _currentLocation = NLatLng(position.latitude, position.longitude);
        });
      } catch (e) {
        _speak('위치 정보를 가져오지 못했습니다.');
      }
    } else if (status.isPermanentlyDenied) {
      _speak('위치 권한이 필요합니다. 설정에서 허용해주세요.');
      openAppSettings();
    } else {
      _speak('위치 권한이 필요합니다. 설정에서 허용해주세요.');
    }
  }

  void _startLocationUpdates() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      setState(() {
        _currentLocation = NLatLng(position.latitude, position.longitude);
      });
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _speech.stop();
    _tts.stop();
    super.dispose();
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
                      if (!_mapController.isCompleted) {
                        _mapController.complete(controller);
                      }
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
                    ],
                  ),
                ),
              ),
    );
  }
}
