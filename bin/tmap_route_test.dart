import 'dart:convert';
import 'package:http/http.dart' as http;

const String tmapApiKey = 'gvtcaFKZy01ZmlWn54hMQazLlazJ0a051IsKZCYc';

String formatSearchTime(DateTime dt) {
  return "${dt.year.toString().padLeft(4, '0')}"
         "${dt.month.toString().padLeft(2, '0')}"
         "${dt.day.toString().padLeft(2, '0')}"
         "${dt.hour.toString().padLeft(2, '0')}"
         "${dt.minute.toString().padLeft(2, '0')}";
}

Future<List<List<String>>> getAllTransitRoutes(Map<String, double> start, Map<String, double> end) async {
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
    'searchDttm': formatSearchTime(DateTime.now()),
    'sort': '0',
  });

  final response = await http.post(Uri.parse(url), headers: headers, body: body);
  List<List<String>> allRoutes = [];

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final itineraries = data['metaData']?['plan']?['itineraries'];
    if (itineraries == null || itineraries.isEmpty) return [];

    for (final itinerary in itineraries) {
      List<String> guideTexts = [];
      final totalTime = (itinerary['totalTime'] / 60).round();
      final transfers = itinerary['transferCount'];
      final trafficTypes = itinerary['legs'].map((leg) => leg['mode']).toSet().join(', ');
      guideTexts.add("⏱️ 총 소요 시간: ${totalTime}분 | 🔁 환승 ${transfers}회 | 🚊 이용수단: ${trafficTypes}");

      final Set<String> seenLegs = {};

      for (final leg in itinerary['legs']) {
        final mode = leg['mode'];
        final legKey = "${mode}_${leg['start']['name']}_${leg['end']['name']}";

        if (seenLegs.contains(legKey)) continue;
        seenLegs.add(legKey);

        if (mode == 'WALK') {
          final time = leg['sectionTime'];
          if (time != null && time <= 180) {
            guideTexts.add("🚶 도보 이동 (${time}분)");
          }
        } else if (mode == 'BUS') {
          final busNo = leg['route'] ?? '알 수 없음';
          final startStop = leg['start']['name'];
          final endStop = leg['end']['name'];
          final stops = leg['passStopList']?['stations']?.length;
          //final stopText = stops != null ? "${stops}개 정류장" : "정류장 수 알 수 없음";
          guideTexts.add("🚌 ${startStop}에서 ${busNo}번 버스 탑승  → ${endStop} 하차");
        } else if (mode == 'SUBWAY') {
          final line = leg['route'] ?? '알 수 없음';
          final startStation = leg['start']['name'];
          final endStation = leg['end']['name'];
          guideTexts.add("🚇 ${startStation}역에서 ${line}호선 탑승 → ${endStation}역 하차");
        }
      }

      allRoutes.add(guideTexts);
    }
  } else {
    print("🚫 API 실패: ${response.statusCode}");
  }

  return allRoutes;
}

Future<void> main() async {
  final start = {'lat': 37.5665, 'lng': 126.9780}; // 서울시청
  final end = {'lat': 37.5010, 'lng': 127.0254};   // 강남역

  print('\n📍 출발지: ${start['lat']}, ${start['lng']}');
  print('📍 도착지: ${end['lat']}, ${end['lng']}\n');

  final routes = await getAllTransitRoutes(start, end);
  int index = 1;
  for (final route in routes) {
    print('\n🚀 [경로 $index]');
    route.forEach(print);
    index++;
  }
}
