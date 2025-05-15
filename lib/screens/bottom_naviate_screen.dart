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

  // ✅ 음성 인식 인스턴스 추가
  late stt.SpeechToText _speech;
  bool _isSpeechAvailable = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText(); // ✅ 초기화
    _initSpeechRecognition(); // ✅ 음성 인식 초기화 함수 호출
    _getCurrentLocation();
  }

  Future<void> _speak(String text) async {
    await _tts.setLanguage("ko-KR");
    await _tts.setSpeechRate(0.5);
    await _tts.speak(text);
  }

  // ✅ 실제 음성 인식을 수행하는 함수
  Future<void> _initSpeechRecognition() async {
    _isSpeechAvailable = await _speech.initialize(
      onStatus: (val) => debugPrint('🎤 상태: $val'),
      onError: (val) => debugPrint('🎤 오류: $val'),
    );

    if (_isSpeechAvailable) {
      await _speak('목적지를 말씀해주세요.');
      await _speech.listen(
        localeId: 'ko_KR',
        onResult: (val) {
          if (val.finalResult) {
            setState(() {
              recognizedText = val.recognizedWords;
            });
            _speak('$recognizedText이 맞으시다면 화면을 두 번 터치해주세요.');
          }
        },
      );
    } else {
      _speak('음성 인식을 사용할 수 없습니다. 설정을 확인해주세요.');
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
                  onDoubleTap: () {
                    _speak('$recognizedText로 경로를 안내합니다.');
                    setState(() {
                      showMap = true;
                    });
                  },
                  child: Text(
                    recognizedText.isEmpty
                        ? '말씀해주세요...'
                        : '입력된 목적지: $recognizedText',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
    );
  }
}
