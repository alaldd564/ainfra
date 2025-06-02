import 'dart:convert';
import 'package:http/http.dart' as http;

/// ✅ API 키 직접 입력
const String tmapApiKey = 'Jpdc9otrzA2ZTXkYregN2akyQFKvDUYa6iJFWaGW';

/// ✅ 도보 경로 함수
Future<List<String>> getWalkingRoute(Map<String, double> start, Map<String, double> end, String apiKey) async {
  final url = 'https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1&format=json';
  final headers = {
    'appKey': apiKey,
    'Content-Type': 'application/json',
  };
  final body = jsonEncode({
    'startX': start['lng'].toString(),
    'startY': start['lat'].toString(),
    'endX': end['lng'].toString(),
    'endY': end['lat'].toString(),
    'reqCoordType': 'WGS84GEO',
    'resCoordType': 'WGS84GEO',
    'startName': '출발지',
    'endName': '도착지',
  });

  final response = await http.post(Uri.parse(url), headers: headers, body: body);
  List<String> guideTexts = [];

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final features = data['features'];
    if (features != null && features.isNotEmpty) {
      final firstLine = features.firstWhere(
        (f) => f['geometry']['type'] == 'LineString',
        orElse: () => null,
      );
      if (firstLine != null) {
        final distance = firstLine['properties']['distance'];
        final time = firstLine['properties']['time'];
        final timeMin = (time / 60).round();
        guideTexts.add("도보 예상 시간: ${timeMin}분, 거리: ${distance}m");
      }
      for (final feature in features) {
        final type = feature['geometry']['type'];
        final props = feature['properties'];
        if (type == 'Point' && props['description'] != null) {
          guideTexts.add(" - ${props['description']}");
        }
      }
    } else {
      guideTexts.add("도보 경로 없음");
    }
  } else {
    guideTexts.add('도보 경로 실패: ${response.statusCode}');
  }

  return guideTexts;
}

/// ✅ 대중교통 경로 함수
Future<List<String>> getTransitRoute(Map<String, double> start, Map<String, double> end, String apiKey) async {
  final url = 'https://apis.openapi.sk.com/transit/routes?version=1&format=json';

  final headers = {
    'accept': 'application/json',
    'Content-Type': 'application/json',
    'appKey': apiKey.trim(),
  };

  final body = jsonEncode({
    'startX': start['lng'].toString(),
    'startY': start['lat'].toString(),
    'endX': end['lng'].toString(),
    'endY': end['lat'].toString(),
    'lang': 0,
    'format': 'json',
  });

  final response = await http.post(Uri.parse(url), headers: headers, body: body);

  print("📡 응답 코드: ${response.statusCode}");
  print("📦 응답 본문:\n${response.body}");

  List<String> guideTexts = [];

  if (response.statusCode == 200) {
    final data = json.decode(response.body);

    final plan = data['metaData']?['plan'];
    if (plan == null || plan['itineraries'] == null || plan['itineraries'].isEmpty) {
      guideTexts.add("❗ 대중교통 경로를 찾을 수 없습니다.");
      return guideTexts;
    }

    final itinerary = plan['itineraries'][0];
    final timeMin = (itinerary['totalTime'] / 60).round();

    guideTexts.add("🚌 대중교통 예상 시간은 약 ${timeMin}분입니다.");

    for (final leg in itinerary['legs']) {
      final sectionType = leg['mode'];
      final sectionInfo = leg['route'] ?? leg['start']?['name'] ?? '';
      final sectionTime = leg['sectionTime'];
      guideTexts.add(" - ${sectionType}을 이용해 ${sectionInfo}까지 ${sectionTime}분 이동");
    }
  } else {
    guideTexts.add('🚫 대중교통 탐색 실패: ${response.statusCode}');
  }

  return guideTexts;
}



/// ✅ main 함수는 마지막에!
Future<void> main() async {
  final start = {'lat': 37.5665, 'lng': 126.9780}; // 서울 시청
  final end = {'lat': 37.5547, 'lng': 126.9706};   // 서울역

  print('📍 출발지: ${start['lat']}, ${start['lng']}');
  print('📍 도착지: ${end['lat']}, ${end['lng']}');

  final walking = await getWalkingRoute(start, end, tmapApiKey);
  print('\n🚶 도보 경로 결과:');
  walking.forEach(print);

  final transit = await getTransitRoute(start, end, tmapApiKey);
  print('\n🚌 대중교통 경로 결과:');
  transit.forEach(print);
}
