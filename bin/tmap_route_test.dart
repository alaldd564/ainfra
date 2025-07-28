import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:async';

const String tmapApiKey = '';

// 시간 포맷
String formatSearchTime(DateTime dt) {
  return "${dt.year.toString().padLeft(4, '0')}"
         "${dt.month.toString().padLeft(2, '0')}"
         "${dt.day.toString().padLeft(2, '0')}"
         "${dt.hour.toString().padLeft(2, '0')}"
         "${dt.minute.toString().padLeft(2, '0')}";
}

// 보행 경로 API 호출
Future<List<Map<String, dynamic>>> getPedestrianRoute(
    Map<String, double> start, Map<String, double> end) async {
  await Future.delayed(Duration(milliseconds: 300));

  final url = 'https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1&format=json';
  final headers = {
    'accept': 'application/json',
    'Content-Type': 'application/json',
    'appKey': tmapApiKey,
  };

  final body = jsonEncode({
    'startX': start['lng'],
    'startY': start['lat'],
    'endX': end['lng'],
    'endY': end['lat'],
    'startName': '출발지',
    'endName': '도착지',
  });

  final response = await http.post(Uri.parse(url), headers: headers, body: body);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final features = data['features'] as List<dynamic>;
    return features.map((e) => e as Map<String, dynamic>).toList();
  } else {
    print("🚫 보행 API 실패: ${response.statusCode}");
    return [];
  }
}

// 안내문 정제 로직
List<String> parsePedestrianGuidance(List<Map<String, dynamic>> features) {
  List<String> result = [];
  Set<String> seenPhrases = {};

  for (final f in features) {
    final props = f['properties'];
    final rawDesc = props['description']?.toString();

    if (rawDesc == null || rawDesc.trim().isEmpty) continue;

    String refined = rawDesc
        .replaceAll('<b>', '')
        .replaceAll('</b>', '')
        .replaceAll('이동', '직진')
        .replaceAll('따라', '')
        .replaceAll('좌회전', '좌회전 후')
        .replaceAll('우회전', '우회전 후')
        .replaceAll('후 후', '후')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' 을 ', ' ')
        .replaceAll('을 ', '')
        .trim();

    final keywordMatch = RegExp(r'(보행자도로|.+대로|.+로|.+길|.+앞)').firstMatch(refined);
    final keyword = keywordMatch?.group(0) ?? refined;

    if (seenPhrases.contains(keyword)) continue;
    seenPhrases.add(keyword);

    result.add("🚶 $refined");
  }

  return result;
}



// 하이브리드 경로 생성 함수
Future<List<String>> generateHybridRoute(Map<String, double> start, Map<String, double> end) async {
  final url = 'https://apis.openapi.sk.com/transit/routes?version=1&format=json';
  final headers = {
    'accept': 'application/json',
    'Content-Type': 'application/json',
    'appKey': tmapApiKey,
  };

  final body = jsonEncode({
    'startX': start['lng'],
    'startY': start['lat'],
    'endX': end['lng'],
    'endY': end['lat'],
    'lang': 0,
    'searchDttm': formatSearchTime(DateTime.now()),
  });

  final response = await http.post(Uri.parse(url), headers: headers, body: body);
  if (response.statusCode != 200) {
    print("🚫 API 실패: ${response.statusCode}");
    return ["❌ 경로 안내를 불러오지 못했습니다."];
  }

  final data = json.decode(response.body);
  final itinerary = data['metaData']['plan']['itineraries'][0];
  final List<String> guide = [];

  final totalTimeMin = (itinerary['totalTime'] / 60).round();
  final transferCount = itinerary['transferCount'] ?? 0;
  int totalWalkTime = 0;
  Set<String> transportModes = {};

  guide.add("⏱️ 총 소요 시간: ${totalTimeMin}분");
  guide.add("🔁 환승 횟수: ${transferCount}회");

  final legs = itinerary['legs'];
  for (final leg in legs) {
    final mode = leg['mode'];
    transportModes.add(mode);

    if (mode == 'WALK') {
      totalWalkTime += (leg['sectionTime'] as num).toInt();

      final walkStart = {
        'lat': (leg['start']['lat'] as num).toDouble(),
        'lng': (leg['start']['lon'] as num).toDouble()
      };
      final walkEnd = {
        'lat': (leg['end']['lat'] as num).toDouble(),
        'lng': (leg['end']['lon'] as num).toDouble()
      };

      final features = await getPedestrianRoute(walkStart, walkEnd);
      final walkGuide = parsePedestrianGuidance(features);
      guide.addAll(walkGuide);
    } else if (mode == 'SUBWAY') {
      guide.add("🚇 ${leg['start']['name']}역에서 ${leg['route']} 탑승 → ${leg['end']['name']}역 하차");
    } else if (mode == 'BUS') {
      guide.add("🚌 ${leg['start']['name']}에서 ${leg['route']} 버스 탑승 → ${leg['end']['name']} 하차");
    }
  }

  guide.insert(2, "🚶 도보 시간: ${(totalWalkTime / 60).round()}분");
  guide.insert(3, "🧭 이용 수단: ${transportModes.join(', ')}");
  
  return guide;
}

// 메인 실행
Future<void> main() async {
  final start = {'lat': 37.5665, 'lng': 126.9780}; // 서울시청
  final end = {'lat': 37.5010, 'lng': 127.0254};   // 강남역

  final guidance = await generateHybridRoute(start, end);
  print("\n🚀 통합 경로 안내:");
  for (final line in guidance) {
    print(line);
  }
}
