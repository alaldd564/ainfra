import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../screens/tts_manager.dart';

class TopTaxiScreen extends StatefulWidget {
  const TopTaxiScreen({super.key});

  @override
  TopTaxiScreenState createState() => TopTaxiScreenState();
}

class TopTaxiScreenState extends State<TopTaxiScreen> {
  final FlutterTts _flutterTts = FlutterTts();

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

  Future<void> _speakText(String text) async {
    await TtsManager.speakIfEnabled(_flutterTts, text);
    debugPrint('🗣️ TTS 실행됨: $text');
  }

  Future<void> _callTaxi(String phoneNumber) async {
    if (await canLaunchUrl(Uri.parse(phoneNumber))) {
      await launchUrl(Uri.parse(phoneNumber));
    } else {
      debugPrint('전화 연결 실패');
      await _speakText('전화 연결에 실패했습니다.');
    }
  }

  Future<void> _launchKakaoTLink() async {
    final Uri url = Uri.parse('https://service.kakaomobility.com/launch/kakaot/');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('카카오T 링크 실행 중 오류: $e');
      await _speakText('카카오택시를 실행하지 못했습니다. 앱이 설치되어 있는지 확인해주세요.');
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

        await _speakText('현재 위치는 $address입니다.');

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

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage('ko-KR');
    _flutterTts.setSpeechRate(0.5);
    _speakText(
      '장애인 콜택시를 부르시려면 첫 번째 버튼을, 카카오택시를 부르시려면 두 번째 버튼을 누르세요.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('택시 호출'), backgroundColor: Colors.green),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '장애인택시와 카카오택시를\n호출할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _getLocationAndCallTaxi,
              icon: const Icon(Icons.phone, color: Colors.white),
              label: const Text(
                '장애인 콜택시 호출',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await _speakText('브라우저가 열립니다. 열기 버튼을 눌러 카카오택시를 실행하세요.');
                await Future.delayed(const Duration(seconds: 1));
                await _launchKakaoTLink();
              },
              icon: const Icon(Icons.local_taxi, color: Colors.white),
              label: const Text(
                '카카오택시 호출',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
