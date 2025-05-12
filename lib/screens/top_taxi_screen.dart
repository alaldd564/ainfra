import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // ✅ 도로명 주소 변환용 패키지 추가

class TopTaxiScreen extends StatefulWidget {
  const TopTaxiScreen({super.key});

  @override
  TopTaxiScreenState createState() => TopTaxiScreenState();
}

class TopTaxiScreenState extends State<TopTaxiScreen> {
  final FlutterTts _flutterTts = FlutterTts();

  final String disabilityTaxiPhone = 'tel:12341234'; // 장애인 택시 전화번호
  final String kakaoTaxiAppScheme = 'kakaotaxi://'; // 카카오택시 앱 호출 URI

  bool _firstDoubleTapConfirmed = false;

  Future<void> _callTaxi(String phoneNumber) async {
    if (await canLaunchUrl(Uri.parse(phoneNumber))) {
      await launchUrl(Uri.parse(phoneNumber));
    } else {
      debugPrint('전화 연결 실패');
    }
  }

  Future<void> _launchKakaoTaxiApp() async {
    if (await canLaunchUrl(Uri.parse(kakaoTaxiAppScheme))) {
      await launchUrl(Uri.parse(kakaoTaxiAppScheme));
    } else {
      debugPrint('카카오택시 앱이 설치되지 않았습니다. 앱 스토어로 이동합니다.');
      await launchUrl(
        Uri.parse(
          'https://play.google.com/store/apps/details?id=com.kakao.taxi',
        ),
      );
    }
  }

  Future<void> _speakText(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
    debugPrint('🗣️ TTS 실행됨: $text');
  }

  Future<void> _onDoubleTap() async {
    if (!_firstDoubleTapConfirmed) {
      debugPrint('👆 첫 번째 두 번 탭 감지');
      await _speakText('카카오택시를 부르시겠습니까? 맞으시면 화면을 두 번 터치해주세요.');
      setState(() {
        _firstDoubleTapConfirmed = true;
      });
    } else {
      debugPrint('✅ 두 번째 두 번 탭: 카카오택시 실행');
      await _launchKakaoTaxiApp();
      setState(() {
        _firstDoubleTapConfirmed = false;
      });
    }
  }

  // ✅ 도로명 주소 안내를 포함한 현재 위치 안내 함수
  Future<void> _speakCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _speakText('위치 서비스가 꺼져 있습니다. 설정에서 활성화해주세요.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        await _speakText('위치 권한이 거부되었습니다.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await _speakText('위치 권한이 영구적으로 거부되어 있습니다. 설정에서 허용해주세요.');
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    debugPrint('📍 위도: ${position.latitude}, 경도: ${position.longitude}');

    try {
      // ✅ 좌표를 도로명 주소로 변환
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        localeIdentifier: 'ko', // 한국어 주소
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        final String address =
            '${place.street}, ${place.locality}, ${place.administrativeArea}';
        debugPrint('📍 주소: $address');
        await _speakText('현재 위치는 $address입니다.');
      } else {
        await _speakText('주소를 찾을 수 없습니다.');
      }
    } catch (e) {
      debugPrint('주소 변환 오류: $e');
      await _speakText('주소 정보를 가져오는 데 실패했습니다.');
    }
  }

  void _handleSwipeDown() async {
    debugPrint('📞 아래로 스와이프 감지: 장애인 택시 호출');
    await _speakCurrentLocation(); // ✅ 도로명 주소로 위치 안내
    await Future.delayed(const Duration(seconds: 2));
    await _callTaxi(disabilityTaxiPhone);
  }

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage('ko-KR');
    _flutterTts.setSpeechRate(0.5);
    _speakText('장애인 택시와 카카오택시를 호출할 수 있습니다. 아래로 스와이프하거나 두 번 탭하세요.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('택시 호출'), backgroundColor: Colors.green),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque, // ✅ 터치 이벤트 확실히 감지
        onDoubleTap: _onDoubleTap,
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta != null && details.primaryDelta! > 20) {
            _handleSwipeDown(); // ✅ 장애인 택시 호출
          }
        },
        onTap: () {
          _speakText('장애인택시와 카카오택시를 호출할 수 있습니다. 아래로 스와이프하거나 두 번 탭하세요.');
        },
        child: const Center(
          child: Text(
            '장애인택시와 카카오택시를 \n호출할 수 있습니다.\n\n아래로 스와이프하거나 두 번 탭하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      ),
    );
  }
}
