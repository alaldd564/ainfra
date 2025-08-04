import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

const String openAIApiKey = ''; // 🔐 실제 배포 시 주의!

bool hasArrived = false; // ✅ 목적지 도착 여부 상태 전역 변수

/// 시계방향 텍스트 변환
String _getClockDirectionFromAngle(double angle) {
  final directions = [
    "12시 방향", "1시 방향", "2시 방향", "3시 방향",
    "4시 방향", "5시 방향", "6시 방향", "7시 방향",
    "8시 방향", "9시 방향", "10시 방향", "11시 방향",
  ];
  final index = ((angle + 15) % 360 ~/ 30) % 12;
  return directions[index];
}

/// 회전 각도 → 상대 방향 변환
String _getRelativeDirection(double angle) {
  if (angle >= 345 || angle < 15) return "직진입니다";
  if (angle >= 15 && angle < 75) return "약간 ${_getClockDirectionFromAngle(angle)}로 이동하세요";
  if (angle >= 75 && angle < 105) return "우회전입니다";
  if (angle >= 105 && angle < 165) return "약간 ${_getClockDirectionFromAngle(angle)}로 이동하세요";
  if (angle >= 165 && angle < 195) return "뒤로 돌아가세요";
  if (angle >= 195 && angle < 255) return "약간 ${_getClockDirectionFromAngle(angle)}로 이동하세요";
  if (angle >= 255 && angle < 285) return "좌회전입니다";
  if (angle >= 285 && angle < 345) return "약간 ${_getClockDirectionFromAngle(angle)}로 이동하세요";
  return "알 수 없는 방향입니다";
}

/// LLM 내비게이션 문장 생성
Future<String> generateLLMNavigationGuide({
  required Map<String, double> currentLocation,
  required Map<String, dynamic> step,
  double? currentAngle,
  bool ReturningToRoute = false,
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
    typeSentence = '이 지점은 $type 형태의 갈림길입니다.\n';
  }

  String situationPrompt;
  if (ReturningToRoute) {
    situationPrompt = '''
사용자가 경로에서 약간 벗어났어.
"경로를 벗어났습니다"라는 말 대신,
자연스럽게 방향을 유도하는 문장을 만들어줘.
예: "11시 방향으로 약간 틀어서 이동하세요.", "뒤로 돌아 다음 안내 지점까지 이동하세요."
''';
  } else {
    situationPrompt = '''
1. 감정적/친절한 표현 없이, 자동차 내비게이션처럼 중립적이고 간결하게 안내해.
2. "직진입니다", "좌회전입니다", "우회전입니다" 같은 표현을 사용해.
3. 방향이 애매하면 "1시 방향"처럼 시계방향 표현을 써.
4. 거리 숫자는 포함하지 마.
''';
  }

  final prompt = '''
너는 시각장애인을 위한 내비게이션 도우미야.

$directionSentence$typeSentence

사용자의 현재 위치는 위도 $lat, 경도 $lng 이고,
다음 경로 단계는 다음과 같아:
$stepDescription

$situationPrompt
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
              '너는 시각장애인을 위한 내비게이션 도우미야. 안내 문장은 감정 없이 간결한 자동차 내비게이션 스타일이어야 해.',
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

/// 다음 안내 문장 생성
Future<String> getNextGuideSentence({
  required String uid,
  required String routeId,
  required double lat,
  required double lng,
  required int currentStepIndex,
}) async {
  if (hasArrived) return '✅ 이미 목적지에 도착하여 안내가 종료되었습니다.';

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

    final lastStep = steps.last;
    final lastStepDist = _distance(lat, lng, lastStep['lat'], lastStep['lng']);

    if (lastStepDist <= 10) {
      hasArrived = true;
      if (lastStepDist > 3) {
        return '곧 목적지에 도착합니다.';
      } else {
        return '목적지에 도착하였습니다. 안내를 종료합니다. [DONE]';
      }
    }

    final targetStep = steps[bestIndex];

    if (minDist > 50) {
      return '경로에서 벗어났습니다. 잠시 멈춰서 주변을 확인하세요.';
    }

    final bool isReturningToRoute = minDist > 15;

    return await generateLLMNavigationGuide(
      currentLocation: {'lat': lat, 'lng': lng},
      step: targetStep,
      currentAngle: angle,
      ReturningToRoute: isReturningToRoute,
    );
  } catch (e) {
    print('🔥 getNextGuideSentence 오류: $e');
    return '🚫 안내 문장을 생성하는 중 오류가 발생했습니다.';
  }
}

/// 거리 계산 함수 (Haversine)
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
