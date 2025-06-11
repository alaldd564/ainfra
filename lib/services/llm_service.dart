import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';


Future<String> generateLLMNavigationGuide({
  required Map<String, double> currentLocation,
  required Map<String, dynamic> step,
}) async {
  final lat = currentLocation['lat']!;
  final lng = currentLocation['lng']!;
  final text = step['text'] ?? '';
  final stepLat = step['lat'];
  final stepLng = step['lng'];
  final stepDescription = '[$stepLat, $stepLng] → $text';

  final prompt = '''
너는 시각장애인을 위한 내비게이션 도우미야.

아래는 사용자의 현재 위치와 경로 안내 문장이야.
각 문장은 이미 간단한 지시문 형태로 되어 있어. (예: "20m 직진하세요", "왼쪽으로 꺾으세요")

사용자의 현재 위치는 위도 $lat, 경도 $lng 이고,
다음은 다음 경로 단계야:

$stepDescription

이 문장을 자연스럽고 친절하게 말해줘.
예를 들어 "20미터 직진하세요"가 있다면, "20미터 앞에 직선 도로가 있어요. 곧장 앞으로 이동해주세요."처럼 부드럽게 말해줘.
단, 너무 길게 말하지 말고 1~2문장으로만 응답해줘.
''';

  final response = await http.post(
    Uri.parse('https://api.openai.com/v1/chat/completions'),
    headers: {
      'Authorization': 'Bearer $openAIApiKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'model': 'gpt-4',
      'messages': [
        {
          'role': 'system',
          'content': '너는 시각장애인을 위한 내비게이션 도우미야. 사용자의 다음 행동을 친절하고 짧게 말해줘.'
        },
        {'role': 'user', 'content': prompt},
      ],
      'max_tokens': 200,
      'temperature': 0.4,
    }),
  );

  if (response.statusCode == 200) {
    final decoded = jsonDecode(response.body);
    final content = decoded['choices'][0]['message']['content'];
    return content.trim();
  } else {
    print('❌ LLM 요청 실패: ${response.statusCode}, ${response.body}');
    return '경로 안내를 생성할 수 없습니다.';
  }
}

Future<String> getNextGuideSentence({
  required String uid,
  required String routeId,
  required double lat,
  required double lng,
  required int currentStepIndex,
}) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('routes')
        .doc(uid)
        .collection('user_routes')
        .doc(routeId)
        .get();

    if (!doc.exists) return '❌ 경로 데이터를 찾을 수 없습니다';

    final data = doc.data();
    final steps = (data?['steps'] as List?)?.cast<Map<String, dynamic>>();
    if (steps == null || steps.isEmpty || currentStepIndex >= steps.length) {
      return '❌ 유효한 경로 단계가 없습니다';
    }

    // currentStepIndex 이후의 단계만 고려
    final remainingSteps = steps.sublist(currentStepIndex);

    // 남은 단계 중 가장 가까운 step 찾기
    int bestIndex = currentStepIndex;
    double minDist = double.infinity;

    for (int i = 0; i < remainingSteps.length; i++) {
      final step = remainingSteps[i];
      final dist = _distance(lat, lng, step['lat'], step['lng']);
      if (dist < minDist) {
        minDist = dist;
        bestIndex = currentStepIndex + i;
      }
    }

    final targetStep = steps[bestIndex];

    // 50m 이상 이탈 시 재안내
    if (minDist > 50) {
      return '경로에서 벗어났어요. 주변을 살펴보시고, 잠시 멈춰주세요.';
    }

    return await generateLLMNavigationGuide(
      currentLocation: {'lat': lat, 'lng': lng},
      step: targetStep,
    );
  } catch (e) {
    print('🔥 getNextGuideSentence 오류: $e');
    return '🚫 안내 문장을 생성하는 중 오류가 발생했습니다.';
  }
}

double _distance(double lat1, double lng1, double lat2, double lng2) {
  const R = 6371000;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
      sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}
