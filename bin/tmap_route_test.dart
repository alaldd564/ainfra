import 'dart:convert';
import 'package:http/http.dart' as http;

const String tmapApiKey = 'Jpdc9otrzA2ZTXkYregN2akyQFKvDUYa6iJFWaGW';

/// 🥾 도보 경로 탐색
Future<List<String>> getWalkingRoute(Map<String, double> start, Map<String, double> end) async {
  final url = 'https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1&format=json';
  final headers = {
    'appKey': tmapApiKey,
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
        guideTexts.add("도보 예상 시간: ${(time / 60).round()}분, 거리: ${distance}m");
      }
      for (final feature in features) {
        final props = feature['properties'];
        final desc = props['description'];
        if (feature['geometry']['type'] == 'Point' && desc != null) {
          guideTexts.add(" - ${desc}");
        }
      }
    } else {
      guideTexts.add("도보 경로 없음");
    }
  } else {
    guideTexts.add("도보 경로 실패: ${response.statusCode}");
  }

  return guideTexts;
}

/// 🚌 대중교통 경로 탐색
Future<List<String>> getTransitRoute(Map<String, double> start, Map<String, double> end, String sort) async {
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
    'format': 'json',
    'searchDttm': DateTime.now().toIso8601String(),
    'sort': sort, // "0": 기본, "1": 최소 환승, "2": 최단 시간
  });

  final response = await http.post(Uri.parse(url), headers: headers, body: body);
  List<String> guideTexts = [];

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final plan = data['metaData']?['plan'];

    if (plan == null || plan['itineraries'] == null || plan['itineraries'].isEmpty) {
      guideTexts.add("❗ 대중교통 경로를 찾을 수 없습니다.");
      return guideTexts;
    }

    final itinerary = plan['itineraries'][0];
    guideTexts.add("총 소요 시간: ${(itinerary['totalTime'] / 60).round()}분");

    for (final leg in itinerary['legs']) {
      final mode = leg['mode'];
      final sectionTime = leg['sectionTime'];

      if (mode == 'WALK') {
        final dist = leg['distance'];
        guideTexts.add("🚶 도보 ${dist}m 이동 (${sectionTime}분)");
      } else if (mode == 'BUS') {
        final busNo = leg['route'] ?? '알 수 없음';
        final startStop = leg['start']['name'];
        final endStop = leg['end']['name'];
        final stops = leg['passStopList']?['stations']?.length ?? 0;
        guideTexts.add("🚌 ${startStop}에서 ${busNo}번 버스 탑승 → ${stops}개 정류장 → ${endStop} 하차");
      } else if (mode == 'SUBWAY') {
        final line = leg['route'] ?? '알 수 없음';
        final startStation = leg['start']['name'];
        final endStation = leg['end']['name'];
        guideTexts.add("🚇 ${startStation}역에서 ${line}호선 탑승 → ${endStation}역 하차");
      }
    }
  } else {
    guideTexts.add("🚫 대중교통 실패: ${response.statusCode}");
  }

  return guideTexts;
}

/// 🚀 메인
Future<void> main() async {
  final start = {'lat': 37.5665, 'lng': 126.9780}; // 서울시청
  final end = {'lat': 37.5010, 'lng': 127.0254};   // 강남역

  print('\n📍 출발지: ${start['lat']}, ${start['lng']}');
  print('📍 도착지: ${end['lat']}, ${end['lng']}\n');

  // 1. 도보 위주
  print('🚶 [1] 도보 위주 경로 안내:');
  final walking = await getWalkingRoute(start, end);
  walking.forEach(print);

  // 2. 도보 + 대중교통 통합 (기본 정렬)
  print('\n🚌 [2] 도보 + 대중교통 통합 안내 (기본):');
  final mixed = await getTransitRoute(start, end, "0");
  mixed.forEach(print);

  // 3. 대중교통 위주 안내
  print('\n🚌 [3] 대중교통 위주 경로 안내 (기본):');
  final transitOnly = await getTransitRoute(start, end, "0");
  transitOnly.forEach(print);

  // 4. 최소 환승 경로
  print('\n🔁 [4] 최소 환승 경로 안내:');
  final minTransfer = await getTransitRoute(start, end, "1");
  minTransfer.forEach(print);

  // 5. 최단 시간 경로
  print('\n⏱️ [5] 최단 시간 경로 안내:');
  final minTime = await getTransitRoute(start, end, "2");
  minTime.forEach(print);
}
