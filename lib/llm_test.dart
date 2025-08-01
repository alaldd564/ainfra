import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await runLLMTest();
}

Future<void> runLLMTest() async {
  const uid = '26Y2rraob8ay8ijB35fMYDuMfgM2';
  const routeId = 'route_1752460691602';

  try {
    final doc = await FirebaseFirestore.instance
        .collection('routes')
        .doc(uid)
        .collection('user_routes')
        .doc(routeId)
        .get();

    final data = doc.data();
    if (data == null) {
      print('[❌] 경로 데이터를 찾을 수 없습니다.');
      return;
    }

    final steps = data['steps'] as List<dynamic>?;

    if (steps == null || steps.isEmpty) {
      print('[⚠️] steps 데이터가 없습니다.');
      return;
    }

    print('[📍 경로 안내 시작]');
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final text = step['text'] ?? '[text 없음]';
      print('Step ${i + 1}: $text');
    }
  } catch (e) {
    print('[🔥 오류 발생] $e');
  }
}
