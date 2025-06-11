import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../screens/tts_manager.dart';

class LeftSosScreen extends StatefulWidget {
  const LeftSosScreen({super.key});

  @override
  State<LeftSosScreen> createState() => _LeftSosScreenState();
}

class _LeftSosScreenState extends State<LeftSosScreen> {
  bool _isSending = false;
  final FlutterTts _flutterTts = FlutterTts();

  Future<void> _speak(String message) async {
    await TtsManager.speakIfEnabled(_flutterTts, message);
  }

  static const String _serverKey = 'YOUR_FIREBASE_SERVER_KEY';

  Future<void> _sendFcmToLinkedGuardians(String blindUid) async {
    final snapshot =
    await FirebaseFirestore.instance
        .collection('guardians')
        .where('linked_user_uid', isEqualTo: blindUid)
        .get();

    for (var doc in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final token = data['fcm_token'];

      if (token is! String || token.isEmpty) continue;

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

  Future<void> _sendSosSignal() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      final blindUid = FirebaseAuth.instance.currentUser?.uid;
      if (blindUid == null) throw '로그인된 사용자 없음';

      await FirebaseFirestore.instance.collection('sos_signals').add({
        'timestamp': FieldValue.serverTimestamp(),
        'user': blindUid,
      });

      await _sendFcmToLinkedGuardians(blindUid);
      await _speak('SOS 신고가 접수되었습니다.');

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('긴급신호 전송 완료')));
    } catch (e) {
      await _speak('전송에 실패했습니다.');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('전송 실패: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
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
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _sendSosSignal,
              child: Container(
                width: 180,
                height: 180,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
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
