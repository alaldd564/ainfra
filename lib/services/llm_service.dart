import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

const String openAIApiKey = ''; // 실제 키

/// 각도를 시계방향 텍스트로 변환
String _getClockDirectionFromAngle(double angle) {
  final directions = [
    "12시 방향",
    "1시 방향",
    "2시 방향",
    "3시 방향",
    "4시 방향",
    "5시 방향",
    "6시 방향",
    "7시 방향",
    "8시 방향",
    "9시 방향",
    "10시 방향",
    "11시 방향",
  ];
  final index = ((angle + 15) % 360 ~/ 30) % 12;
  return directions[index];
}

/// 회전 각도 → 상대 방향 변환
String _getRelativeDirection(double angle) {
  if (angle >= 345 || angle < 15) return "직진입니다";
  if (angle >= 15 && angle < 75)
    return "약간 ${_getClockDirectionFromAngle(angle)}로 이동하세요";
  if (angle >= 75 && angle < 105) return "우회전입니다";
  if (angle >= 105 && angle < 165)
    return "약간 ${_getClockDirectionFromAngle(angle)}로 이동하세요";
  if (angle >= 165 && angle < 195) return "뒤로 돌아가세요";
  if (angle >= 195 && angle < 255)
    return "약간 ${_getClockDirectionFromAngle(angle)}로 이동하세요";
  if (angle >= 255 && angle < 285) return "좌회전입니다";
  if (angle >= 285 && angle < 345)
    return "약간 ${_getClockDirectionFromAngle(angle)}로 이동하세요";
  return "알 수 없는 방향입니다";
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
  final type = step['type'];

  final stepDescription = '[$stepLat, $stepLng] → $text';

  String directionSentence = '';
  if (currentAngle != null) {
    final relative = _getRelativeDirection(currentAngle);
    directionSentence = '사용자의 현재 방향을 기준으로 $relative\n';
  }

  String typeSentence = '';
  if (type != null && type is String && type.isNotEmpty) {
    typeSentence = '이 지점은 $type 형태의 갈림길입니다.\n'; // 🔧 추가됨
  }

  final prompt = '''
너는 시각장애인을 위한 내비게이션 도우미야.

$directionSentence$typeSentence

사용자의 현재 위치는 위도 $lat, 경도 $lng 이고,
다음 경로 단계는 다음과 같아:
$stepDescription

아래 규칙을 따라 문장을 한 문장 또는 두 문장으로 안내해줘.

1. "동쪽", "북서쪽" 같은 절대 방향은 절대 사용하지 마.
2. 사용자의 현재 방향을 기준으로 상대 방향만 사용해.
3. 가능하면 "직진입니다", "좌회전입니다", "우회전입니다", "뒤로 돌아가세요"처럼 간결하게 말해.
4. 만약 방향이 애매하다면 "1시 방향", "11시 방향"처럼 시계 방향 표현을 사용해.
5. 거리 숫자는 사용하지 마.
6. 만약 이 지점이 T자, Y자, 사거리, 골목 같은 특이한 지형이면 그 지형에 맞는 안내 문장을 만들어줘.
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
          'content':
              '너는 시각장애인을 위한 내비게이션 도우미야. 안내 문장은 간결하고 감정 없는 자동차 내비 스타일이어야 해.',
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
    final doc =
        await FirebaseFirestore.instance
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

    final locDoc =
        await FirebaseFirestore.instance.collection('locations').doc(uid).get();
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
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLng / 2) *
          sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}
