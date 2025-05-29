import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dotenv/dotenv.dart';

final DotEnv dotenv = DotEnv()..load(); // .env 로드

Future<void> main() async {
  final tmapApiKey = dotenv['TMAP_API_KEY'] ?? '';

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

Future<List<String>> getTransitRoute(Map<String, double> start, Map<String, double> end, String apiKey) async {
  final url =
      'https://apis.openapi.sk.com/transit/routes?version=1&format=json'
      '&startX=${start['lng']}&startY=${start['lat']}'
      '&endX=${end['lng']}&endY=${end['lat']}';

  final headers = {
    'accept': 'application/json',
    'appKey': apiKey, // appKey를 헤더로 사용
  };

  final response = await http.get(Uri.parse(url), headers: headers);

  // 📡 응답 출력
  print("📡 대중교통 응답 코드: ${response.statusCode}");
  print("📦 대중교통 응답 본문:\n${response.body}");

  List<String> guideTexts = [];

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final itinerary = data['metaData']['plan']['itineraries'][0];
    final timeMin = (itinerary['totalTime'] / 60).round();
    final fare = itinerary['totalFare']['regular']['totalFare'];

    guideTexts.add("대중교통 예상 시간: ${timeMin}분 / 요금: ${fare}원");

    for (final leg in itinerary['legs']) {
      final sectionType = leg['mode'];
      final sectionInfo = leg['route'] ?? leg['start']['name'];
      final sectionTime = leg['sectionTime'];
      guideTexts.add(" - [$sectionType] $sectionInfo (${sectionTime}분)");
    }
  } else {
    guideTexts.add('대중교통 실패: ${response.statusCode}');
  }

  return guideTexts;
}
