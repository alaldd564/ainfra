import 'dart:convert';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;

const String tmapApiKey = 'uPP5we14LR6Zppxwb5qNB9PKsvptFWwf88T9mYXa';

/// 🚶 도보 경로 탐색
Future<List<String>> getWalkingRoute(NLatLng start, NLatLng end) async {
  final url = 'https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1&format=json';

  final headers = {
    'appKey': tmapApiKey,
    'Content-Type': 'application/json',
  };

  final body = jsonEncode({
    'startX': start.longitude.toString(),
    'startY': start.latitude.toString(),
    'endX': end.longitude.toString(),
    'endY': end.latitude.toString(),
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
        guideTexts.add("🚶 도보 예상 시간: ${timeMin}분, 거리: ${distance}m");
      }

      for (final feature in features) {
        final type = feature['geometry']['type'];
        final props = feature['properties'];
        if (type == 'Point' && props['description'] != null) {
          guideTexts.add("🔹 ${props['description']}");
        }
      }
    } else {
      guideTexts.add("❗ 도보 경로 없음");
    }
  } else {
    guideTexts.add('🚫 도보 경로 실패: ${response.statusCode}');
  }

  return guideTexts;
}

/// 🚌 대중교통 경로 탐색
Future<List<String>> getTransitRoute(NLatLng start, NLatLng end) async {
  final url =
      'https://apis.openapi.sk.com/transit/routes?version=1&format=json'
      '&appKey=$tmapApiKey'
      '&startX=${start.longitude}&startY=${start.latitude}'
      '&endX=${end.longitude}&endY=${end.latitude}';

  final response = await http.get(Uri.parse(url));
  List<String> guideTexts = [];

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final itinerary = data['metaData']['plan']['itineraries'][0];
    final timeMin = (itinerary['totalTime'] / 60).round();
    final fare = itinerary['totalFare']['regular']['totalFare'];

    guideTexts.add("🚌 대중교통 예상 시간: ${timeMin}분 / 요금: ${fare}원");

    for (final leg in itinerary['legs']) {
      final sectionType = leg['mode'];
      final sectionInfo = leg['route'] ?? leg['start']['name'];
      final sectionTime = leg['sectionTime'];
      guideTexts.add(" - [$sectionType] $sectionInfo (${sectionTime}분)");
    }
  } else {
    guideTexts.add('🚫 대중교통 실패: ${response.statusCode}');
  }

  return guideTexts;
}
