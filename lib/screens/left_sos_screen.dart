// lib/screens/left_sos_screen.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeftSosScreen extends StatefulWidget {
  const LeftSosScreen({super.key});

  @override
  State<LeftSosScreen> createState() => _LeftSosScreenState();
}

class _LeftSosScreenState extends State<LeftSosScreen> {
  bool _isSending = false;

  // Firebase Cloud Messaging 서버 키
  static const String _serverKey = 'YOUR_FIREBASE_SERVER_KEY';

  // Firestore에서 보호자 토큰 가져와 FCM 전송
  Future<void> _sendFcmToGuardians() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('guardians').get();

    for (var doc in snapshot.docs) {
      final token = doc['fcm_token'];
      final body = {
        'to': token,
        'notification': {'title': '긴급신호 수신', 'body': '사용자가 SOS 버튼을 눌렀습니다.'},
        'data': {'click_action': 'FLUTTER_NOTIFICATION_CLICK'},
      };

      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode(body),
      );
    }
  }

  void _sendSosSignal() async {
    if (_isSending) return; // 중복 클릭 방지
    setState(() => _isSending = true);

    try {
      // Firebase Firestore에 긴급신호 업로드
      await FirebaseFirestore.instance.collection('sos_signals').add({
        'timestamp': FieldValue.serverTimestamp(),
        'user': 'user_id_123', // 실제 로그인 사용자 ID로 대체 필요
      });

      // 보호자에게 푸시 알림 전송
      await _sendFcmToGuardians();

      // 실제로는 FCM 토큰을 찾아서 메시지 전송함 (5단계에서 설명)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('긴급신호 전송 완료')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('전송 실패: $e')));
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'SOS 긴급 호출',
            style: TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40), // 텍스트와 버튼 간 간격

          GestureDetector(
            onTap: _sendSosSignal,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
                image: const DecorationImage(
                  image: AssetImage('assets/images/sos_button.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
