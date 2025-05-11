import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TopTaxiScreen extends StatelessWidget {
  const TopTaxiScreen({super.key});

  // 장애인 택시 전화번호 (예시)
  final String taxiPhone = 'tel:12341234';

  // 전화 걸기 함수
  Future<void> _callTaxi() async {
    if (await canLaunchUrl(Uri.parse(taxiPhone))) {
      await launchUrl(Uri.parse(taxiPhone));
    } else {
      debugPrint('전화 연결 실패');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('택시 호출'), backgroundColor: Colors.green),
      body: GestureDetector(
        onDoubleTap: () {
          debugPrint('📞 더블탭 감지');
          _callTaxi();
        },
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta != null && details.primaryDelta! > 20) {
            debugPrint('📞 아래로 스와이프 감지');
            _callTaxi();
          }
        },
        child: const Center(
          child: Text(
            '택시 기사 호출 화면입니다.\n\n두 번 탭하거나 아래로 스와이프하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      ),
    );
  }
}
