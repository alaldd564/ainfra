import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';

const String tmapViewType = 'com.example.ai_n_fra/tmapView';
const String tmapMethodChannel = 'com.example.ai_n_fra/tmapMethod';

class BottomNavigateScreen extends StatefulWidget {
  const BottomNavigateScreen({super.key});

  @override
  State<BottomNavigateScreen> createState() => _BottomNavigateScreenState();
}

class _BottomNavigateScreenState extends State<BottomNavigateScreen> {
  final FlutterTts _tts = FlutterTts();

  String recognizedText = ''; // 임시 목적지 텍스트
  bool showMap = false; // 지도 표시 상태
  Position? _currentPosition; // 현재 위치
  // 네이티브 T Map 뷰와 통신할 MethodChannel 인스턴스
  late MethodChannel _methodChannel;

  @override
  void initState() {
    super.initState();
    // 네이티브와 통신할 MethodChannel 초기화
    _methodChannel = const MethodChannel(tmapMethodChannel);

    _speak('목적지를 말씀해주세요.');
    _fakeRecognition(); // 실제 음성 인식 대신 임시 텍스트 사용
    _getCurrentLocation(); // 현재 위치 가져오기 시작
  }

  @override
  void dispose() {
    super.dispose();
  }


  Future<void> _speak(String text) async {
    await _tts.setLanguage("ko-KR");
    await _tts.setSpeechRate(0.5);
    await _tts.speak(text);
  }

  // 음성 인식 없이 임시 텍스트 처리
  void _fakeRecognition() {
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        recognizedText = '서울역'; // 원하는 임시 목적지 입력
      });
      _speak('$recognizedText이 맞으시다면 화면을 두 번 터치해주세요.');
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
          _currentPosition = position;
          print("Current Location: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}");
        });
      } catch (e) {
        _speak('위치 정보를 가져오지 못했습니다.');
        print("Error getting location: $e");
      }
    } else {
      _speak('위치 권한이 필요합니다. 설정에서 허용해주세요.');
      // 권한이 없는 경우 처리 (예: 설정 화면으로 이동 안내)
    }
  }

  // 네이티브 T Map 뷰에 현재 위치를 전달하는 함수
  void _sendLocationToNative(double latitude, double longitude) async {
    // Android PlatformView가 생성되고 MethodChannel이 준비된 후에만 호출
    if (Platform.isAndroid) {
      try {
        print("Sending current location to native: Lat $latitude, Lon $longitude");
        await _methodChannel.invokeMethod('setUserLocation', {
          'latitude': latitude,
          'longitude': longitude,
        });
        print("Current location sent successfully.");
      } on PlatformException catch (e) {
        print("Failed to send current location to native: '${e.message}'.");
      }
    } else {
      print("Platform is not Android, cannot send location via MethodChannel.");
    }
  }

  /// 네이티브 T Map 뷰에 목적지 정보를 전달하는 함수 (새로 추가)
  void _sendDestinationToNative(String destinationName) async {
    // Android PlatformView가 생성되고 MethodChannel이 준비된 후에만 호출
    if (Platform.isAndroid) {
      try {
        print("Sending destination to native: $destinationName");
        await _methodChannel.invokeMethod('setDestination', {
          'destinationName': destinationName,
        });
        print("Destination sent successfully.");
      } on PlatformException catch (e) {
        print("Failed to send destination to native: '${e.message}'.");
      }
    } else {
      print("Platform is not Android, cannot send destination via MethodChannel.");
    }
  }


  // AndroidView 생성 시 호출되는 콜백
  void _onPlatformViewCreated(int id) {
    print("AndroidView created with id: $id");
    // 위치 정보가 이미 있다면 네이티브로 전달
    if (_currentPosition != null) {
      _sendLocationToNative(_currentPosition!.latitude, _currentPosition!.longitude);
    }
    // 지도 뷰가 생성되면 목적지 정보도 전달 (이미 인식된 경우)
    if (recognizedText.isNotEmpty) {
      _sendDestinationToNative(recognizedText);
    }
  }


  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('길찾기')),
        body: const Center(
          child: Text('이 예제의 Tmap 기능은 Android에서만 작동함'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('경로 설정'),
        backgroundColor: Colors.deepPurple,
      ),
      body: showMap
          ? (_currentPosition == null // 위치 정보를 가져오는 동안 로딩 표시
          ? const Center(child: CircularProgressIndicator())
          : buildTMapAndroidView() // 위치 정보를 가져왔으면 T Map 뷰 표시
      )
          : Center( // 목적지 확인 UI
        child: GestureDetector(
          onDoubleTap: () {
            if (recognizedText.isEmpty) {
              _speak('목적지가 입력되지 않았습니다.');
              return; // 목적지 없으면 처리 중단
            }
            _speak('$recognizedText로 경로를 안내합니다.');
            // 목적지 확인 후 지도 표시 상태로 변경
            setState(() {
              showMap = true;
            });
            _sendDestinationToNative(recognizedText);

          },
          child: Text(
            recognizedText.isEmpty
                ? '말씀해주세요...'
                : '입력된 목적지: $recognizedText\n\n맞으면 두 번 탭하세요.',
            style: const TextStyle(color: Colors.white, fontSize: 20),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // T Map 네이티브 AndroidView 위젯을 빌드합니다. // gpt왈 좀 더 이해가 필요한 부분분
  Widget buildTMapAndroidView() {
    return AndroidView(
      viewType: tmapViewType, // 네이티브 PlatformViewFactory에 등록한 식별자
      onPlatformViewCreated: _onPlatformViewCreated, // 네이티브 뷰 생성 완료 콜백
      creationParams: <String, dynamic>{
        // Optional: Initial location might be sent here too,
        // but sending after _getCurrentLocation is more accurate.
        // 'latitude': _currentPosition?.latitude ?? 37.5665,
        // 'longitude': _currentPosition?.longitude ?? 126.9780,
        // 'apiKey': 'NsxOESGJ823yk2Nyvwcf15sSqaYMBXlw1L4UBmoa',
      },
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}