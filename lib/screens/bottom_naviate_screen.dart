import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
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

  @override
  void initState() {
    super.initState();
    _initTTS();
    _startFlow();
  }

  void _initTTS() {
    _tts.setLanguage("ko-KR");
    _tts.setSpeechRate(0.5);
    _tts.awaitSpeakCompletion(true);
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> _startFlow() async {
    await _speak('목적지를 말씀해주세요.');
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      recognizedText = '서울역';
    });
    await _speak('$recognizedText이 맞으시다면 화면을 두 번 터치해주세요.');
    await _getCurrentLocation();
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
        await _speak('위치 정보를 가져오지 못했습니다.');
      }
    } else {
      await _speak('위치 권한이 필요합니다. 설정에서 허용해주세요.');
    }
  }

  Future<void> _handleDoubleTap() async {
    await _speak('$recognizedText로 경로를 안내합니다.');

    if (_currentLocation == null) {
      await _speak('위치 정보를 불러오는 중입니다. 잠시만 기다려주세요.');
      while (_currentLocation == null) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    setState(() {
      showMap = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    await _speak('지도를 표시합니다. 현재 위치 기준입니다.');
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
                onDoubleTap: _handleDoubleTap,
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
