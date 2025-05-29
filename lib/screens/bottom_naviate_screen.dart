import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:geocoding/geocoding.dart';
import 'package:maptest/services/route_service.dart'; // 🔄 실제 경로로 수정해주세요
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
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _initializeTTS();
    _speech = stt.SpeechToText();
    _speakThen(() => _initializeSpeech(), '목적지를 말씀해주세요.');
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

  void _handleDoubleTap() async {
    if (_navigating || !_isReadyForDoubleTap || _isTtsSpeaking || recognizedText.isEmpty) return;
    _navigating = true;
    await _speak('$recognizedText로 경로를 안내합니다.');
    setState(() => showMap = true);

    try {
      final locations = await locationFromAddress(recognizedText);
      if (locations.isNotEmpty) {
        final dest = locations.first;
        final destination = NLatLng(dest.latitude, dest.longitude);

        if (_currentLocation != null) {
          final guides = await getWalkingRoute(_currentLocation!, destination);

          if (guides.isEmpty) {
            _showErrorDialog('경로를 불러오지 못했습니다.');
          } else {
            _showRouteGuidePopup(guides);
          }

          await getTransitRoute(_currentLocation!, destination);
        }
      } else {
        _speak("목적지 위치를 찾을 수 없습니다.");
      }
    } catch (e) {
      print("위치 변환 오류: $e");
      _speak("목적지 변환 중 오류가 발생했습니다.");
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

  void _showRouteGuidePopup(List<String> guides) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('도보 경로 안내'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: guides.map((text) => Text('• $text')).toList(),
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('경로 설정'),
        backgroundColor: Colors.deepPurple,
      ),
      body: showMap
          ? (_currentLocation == null
              ? const Center(child: CircularProgressIndicator())
              : NaverMap(
                  onMapReady: (controller) => _mapController.complete(controller),
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