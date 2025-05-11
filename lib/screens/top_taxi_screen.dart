import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TopTaxiScreen extends StatefulWidget {
  const TopTaxiScreen({super.key});

  @override
  TopTaxiScreenState createState() => TopTaxiScreenState();
}

class TopTaxiScreenState extends State<TopTaxiScreen> {
  final FlutterTts _flutterTts = FlutterTts();

  final String disabilityTaxiPhone = 'tel:12341234'; // 장애인 택시 전화번호
  final String kakaoTaxiAppScheme = 'kakaotaxi://'; // 카카오택시 앱 호출 URI

  // 두 번째 두 번 탭을 위한 상태 변수
  bool _firstDoubleTapConfirmed = false;

  // 전화 걸기 함수
  Future<void> _callTaxi(String phoneNumber) async {
    if (await canLaunchUrl(Uri.parse(phoneNumber))) {
      await launchUrl(Uri.parse(phoneNumber));
    } else {
      debugPrint('전화 연결 실패');
    }
  }

  // 카카오택시 앱 실행
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

  // TTS 실행
  Future<void> _speakText(String text) async {
    await _flutterTts.speak(text);
    debugPrint('🗣️ TTS 실행됨: $text');
  }

  // 두 번 탭 감지 함수
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

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage('ko-KR');
    _flutterTts.setSpeechRate(0.5);

    // ✅ 화면 진입 시 TTS 안내
    _speakText('장애인 택시와 카카오택시를 호출할 수 있습니다. 두 번 탭하거나 아래로 스와이프하세요.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('택시 호출'), backgroundColor: Colors.green),
      body: GestureDetector(
        onDoubleTap: _onDoubleTap, // 더블탭 이벤트 연결
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta != null && details.primaryDelta! > 20) {
            debugPrint('📞 아래로 스와이프 감지: 장애인 택시 호출');
            _callTaxi(disabilityTaxiPhone);
          }
        },
        onTap: () {
          _speakText('장애인택시와 카카오택시를 호출할 수 있습니다. 두 번 탭하거나 아래로 스와이프하세요.');
        },
        child: const Center(
          child: Text(
            '장애인택시와 카카오택시를 호출할 수있습니다.\n\n두 번 탭하거나 아래로 스와이프하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      ),
    );
  }
}
