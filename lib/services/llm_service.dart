import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';



/// 협수의 각도(angle)를 복석/동/서/남 방향으로 변환
String _getDirectionFromAngle(double angle) {
  if (angle >= 337.5 || angle < 22.5) return "북쪽";
  if (angle < 67.5) return "북동쪽";
  if (angle < 112.5) return "동쪽";
  if (angle < 157.5) return "남동쪽";
  if (angle < 202.5) return "남쪽";
  if (angle < 247.5) return "남서쪽";
  if (angle < 292.5) return "서쪽";
  return "북서쪽";
}

Future<String> generateLLMNavigationGuide({
  required Map<String, double> currentLocation,
  required Map<String, dynamic> step,
  double? currentAngle,
}) async {
  final lat = currentLocation['lat']!;
  final lng = currentLocation['lng']!;
  final text = step['text'] ?? '';
  final stepLat = step['lat'];
  final stepLng = step['lng'];

  final stepDescription = '[$stepLat, $stepLng] → $text';

  String directionSentence = '';
  if (currentAngle != null) {
    final direction = _getDirectionFromAngle(currentAngle);
    directionSentence = '사용자의 현재 방향은 $direction입니다.\n';
  }

  final prompt = '''
너는 시각장애인을 위한 내비게이션 도우미야.

$directionSentence

사용자의 현재 위치는 위도 $lat, 경도 $lng 이고,
다음 경로 단계는 다음과 같아:
$stepDescription

아래 규칙을 따라 문장을 한 문장 또는 두 문장으로 안내해줘.

1. 감정적/친절한 표현(예: "조심히 가세요", "살펴보세요")은 사용하지 말고 자동차 내비처럼 중립적이고 간결하게 안내해.
2. "동쪽 방향" 같은 절대 방향만 주지 말고, 사용자의 현재 방향도 같이 알려줘.
3. "50m 이동하세요" 같은 거리 기반 표현은 생략해.
4. 예: "다음 안내 시까지 직진입니다", "다음 안내에서 좌회전입니다"처럼 간결한 문장으로 말해줘.
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
          'content': '너는 시각장애인을 위한 내비게이션 도우미야. 안내 문장은 간결하고 감정 없는 자동차 내비 스타일이어야 해.'
        },
        {'role': 'user', 'content': prompt},
      ],
      'max_tokens': 150,
      'temperature': 0.2,
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

    final locDoc = await FirebaseFirestore.instance.collection('locations').doc(uid).get();
    final locData = locDoc.data();
    final double? angle = locData?['angle']?.toDouble();

    final remainingSteps = steps.sublist(currentStepIndex);

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

    if (minDist > 50) {
      return '경로에서 벗어났습니다. 잠시 멈춰서 주변을 확인하세요.';
    }

    return await generateLLMNavigationGuide(
      currentLocation: {'lat': lat, 'lng': lng},
      step: targetStep,
      currentAngle: angle,
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