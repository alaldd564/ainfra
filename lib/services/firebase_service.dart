import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'llm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(MyTestApp());
}

class MyTestApp extends StatelessWidget {
  const MyTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LLM Test',
      home: Scaffold(
        appBar: AppBar(title: Text('LLM 경로 안내 테스트')),
        body: LLMGuideWidget(),
      ),
    );
  }
}

class LLMGuideWidget extends StatefulWidget {
  @override
  _LLMGuideWidgetState createState() => _LLMGuideWidgetState();
}

class _LLMGuideWidgetState extends State<LLMGuideWidget> {
  String result = '로딩 중...';

  @override
  void initState() {
    super.initState();
    runTest();
  }

  Future<void> runTest() async {
    // 테스트용 유저 ID와 경로 ID, 위치 지정
    const uid = '테스트용-uid';
    const routeId = '테스트용-routeId';
    const lat = 37.5665;
    const lng = 126.9780;
    const stepIndex = 0;

    final guide = await getNextGuideSentence(
      uid: uid,
      routeId: routeId,
      lat: lat,
      lng: lng,
      currentStepIndex: stepIndex,
    );

    setState(() {
      result = guide;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(result, style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
