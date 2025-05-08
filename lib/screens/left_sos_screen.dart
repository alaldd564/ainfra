// lib/screens/left_sos_screen.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeftSosScreen extends StatefulWidget {
  const LeftSosScreen({super.key});

  @override
  State<LeftSosScreen> createState() => _LeftSosScreenState();
}

class _LeftSosScreenState extends State<LeftSosScreen> {
  bool _isSending = false;

  // Firebase Cloud Messaging 서버 키
  static const String _serverKey = 'YOUR_FIREBASE_SERVER_KEY';

  // 연동된 보호자만 필터해서 FCM 전송
  Future<void> _sendFcmToLinkedGuardians(String blindUid) async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('guardians')
            .where('linked_user_uid', isEqualTo: blindUid)
            .get();

    for (var doc in snapshot.docs) {
      final token = doc['fcm_token'];
      if (token == null) continue;

      final body = {
        'to': token,
        'notification': {
          'title': '긴급신호 수신',
          'body': '연결된 시각장애인이 SOS 버튼을 눌렀습니다.',
        },
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

  // 로그인 사용자 기준 Firestore 저장 + 연동 보호자에게만 알림
  void _sendSosSignal() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      final blindUid = FirebaseAuth.instance.currentUser?.uid;
      if (blindUid == null) throw '로그인된 사용자 없음';

      // Firestore에 SOS 기록 저장
      await FirebaseFirestore.instance.collection('sos_signals').add({
        'timestamp': FieldValue.serverTimestamp(),
        'user': blindUid, // 실제 사용자 UID
      });

      // 연동된 보호자에게만 FCM 전송
      await _sendFcmToLinkedGuardians(blindUid);

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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'SOS 긴급 호출',
              style: TextStyle(
                fontSize: 24,
                color: Colors.yellow,
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
      ),
    );
  }
}
