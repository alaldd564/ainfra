import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart'; // ✅ 위치 정보 가져오기 위해 추가

class LocationShareScreen extends StatefulWidget {
  const LocationShareScreen({super.key});

  @override
  State<LocationShareScreen> createState() => _LocationShareScreenState();
}

class _LocationShareScreenState extends State<LocationShareScreen> {
  bool _locationShared = false;
  bool _loading = true;
  final _tts = FlutterTts();
  String? _generatedId;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // blind_users 문서에서 generatedId 찾기
    final snapshot = await FirebaseFirestore.instance
        .collection('blind_users')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return;

    final docId = snapshot.docs.first.id;
    _generatedId = docId;

    final locDoc = await FirebaseFirestore.instance
        .collection('locations')
        .doc(docId)
        .get();

    setState(() {
      _locationShared = locDoc.data()?['location_shared'] ?? false;
      _loading = false;
    });
  }

  Future<void> _toggleLocationSharing() async {
    if (_generatedId == null) return;

    final newValue = !_locationShared;

    Map<String, dynamic> updateData = {
      'location_shared': newValue,
      'last_updated': FieldValue.serverTimestamp(),
    };

    // ✅ 위치 공유를 켜는 경우 현재 위치도 저장
    if (newValue) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        updateData['lat'] = position.latitude;
        updateData['lng'] = position.longitude;
      } catch (e) {
        print('❌ 위치 정보 가져오기 실패: $e');
      }
    }

    await FirebaseFirestore.instance
        .collection('locations')
        .doc(_generatedId!)
        .set(updateData, SetOptions(merge: true));

    setState(() => _locationShared = newValue);

    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.5);
    await _tts.speak(newValue ? '위치 공유가 활성화되었습니다.' : '위치 공유가 비활성화되었습니다.');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('위치 공유 설정', style: TextStyle(color: Colors.yellow)),
        iconTheme: const IconThemeData(color: Colors.yellow),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _locationShared ? Icons.location_on : Icons.location_off,
              color: _locationShared ? Colors.green : Colors.red,
              size: 100,
            ),
            const SizedBox(height: 20),
            Text(
              _locationShared ? '현재 위치 공유가 켜져 있습니다.' : '현재 위치 공유가 꺼져 있습니다.',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _toggleLocationSharing,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: Text(
                _locationShared ? '위치 공유 끄기' : '위치 공유 켜기',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
