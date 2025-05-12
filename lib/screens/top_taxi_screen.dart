import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class TopTaxiScreen extends StatefulWidget {
  const TopTaxiScreen({super.key});

  @override
  TopTaxiScreenState createState() => TopTaxiScreenState();
}

class TopTaxiScreenState extends State<TopTaxiScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  final String kakaoTaxiAppScheme = 'kakaotaxi://';

  bool _firstDoubleTapConfirmed = false;

  final Map<String, String> taxiPhoneNumbers = {
    '서울특별시': 'tel:1588-4388',
    '부산광역시': 'tel:051-1588-8808',
    '대구광역시': 'tel:053-628-4000',
    '인천광역시': 'tel:032-430-7982',
    '광주광역시': 'tel:062-600-9444',
    '대전광역시': 'tel:042-825-7777',
    '울산광역시': 'tel:1899-0006',
    '경기도': 'tel:1544-1230',
    '강원특별자치도': 'tel:033-241-0001',
    '충청북도': 'tel:043-215-7982',
    '충청남도': 'tel:041-1577-8255',
    '전라북도': 'tel:063-212-0001',
    '전라남도': 'tel:061-276-2255',
    '경상북도': 'tel:054-842-8255',
    '경상남도': 'tel:055-237-8000',
    '제주특별자치도': 'tel:064-759-0000',
  };

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

  Future<void> _getLocationAndCallTaxi() async {
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

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        localeIdentifier: 'ko',
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        final String address =
            '${place.street}, ${place.locality}, ${place.administrativeArea}';
        debugPrint('📍 주소: $address');

        // 현재 위치 음성 안내
        await _speakText('현재 위치는 $address입니다.');

        // 해당 지역의 장애인 택시 전화 연결
        final String region = place.administrativeArea ?? '';
        final String? phoneNumber = taxiPhoneNumbers[region];

        if (phoneNumber != null) {
          await _speakText('$region 장애인 콜택시로 연결합니다.');
          await Future.delayed(const Duration(seconds: 1));
          await _callTaxi(phoneNumber);
        } else {
          await _speakText('$region 지역의 콜택시 번호를 찾을 수 없습니다.');
        }
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
    await _getLocationAndCallTaxi();
  }

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage('ko-KR');
    _flutterTts.setSpeechRate(0.5);
    _speakText(
      '장애인 택시와 카카오택시를 호출할 수 있습니다. 장애인 콜택시를 부르시려면 아래로 스와이프를, 카카오택시를 부르시려면 두 번 탭해주세요.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('택시 호출'), backgroundColor: Colors.green),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: _onDoubleTap,
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta != null && details.primaryDelta! > 20) {
            _handleSwipeDown();
          }
        },
        child: const Center(
          child: Text(
            '장애인택시와 카카오택시를 \n호출할 수 있습니다.\n\n장애인 콜택시를 부르시려면\n아래로 스와이프\n카카오택시를 부르시려면\n두 번 탭해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      ),
    );
  }
}
