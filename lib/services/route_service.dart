import 'dart:convert';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;

const String tmapApiKey = 'Jpdc9otrzA2ZTXkYregN2akyQFKvDUYa6iJFWaGW';

/// 🚶 도보 경로 탐색
Future<List<String>> getWalkingRoute(NLatLng start, NLatLng end) async {
  final url =
      'https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1&format=json';

  final headers = {'appKey': tmapApiKey, 'Content-Type': 'application/json'};

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

  final response = await http.post(
    Uri.parse(url),
    headers: headers,
    body: body,
  );
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
      '&startX=${start.longitude}&startY=${start.latitude}'
      '&endX=${end.longitude}&endY=${end.latitude}';

  // ✅ 헤더에 appKey 추가
  final headers = {'accept': 'application/json', 'appKey': tmapApiKey};

  final response = await http.get(Uri.parse(url), headers: headers);
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

/// ✅✅도보 경로 안내 + 경로 좌표 리스트 반환용 함수
Future<(List<String>, List<NLatLng>, List<NMarker>)> getWalkingRouteWithPath(
  NLatLng start,
  NLatLng end,
) async {
  final url =
      'https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1&format=json';

  final headers = {'appKey': tmapApiKey, 'Content-Type': 'application/json'};

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

  final response = await http.post(
    Uri.parse(url),
    headers: headers,
    body: body,
  );
  List<String> guideTexts = [];
  List<NLatLng> pathPoints = [];
  List<NMarker> markers = [];

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final features = data['features'];

    for (final feature in features) {
      final type = feature['geometry']['type'];
      final props = feature['properties'];
      final geometry = feature['geometry'];

      if (type == 'LineString') {
        final coords = geometry['coordinates'];
        for (final coord in coords) {
          final lng = coord[0];
          final lat = coord[1];
          pathPoints.add(NLatLng(lat, lng));
        }

        // ✅ 정보 출력용 텍스트만 추가
        final timeMin = (props['time'] / 60).round();
        guideTexts.add("🚶 도보 예상 시간: ${timeMin}분, 거리: ${props['distance']}m");
      } else if (type == 'Point' && props['description'] != null) {
        guideTexts.add("🔹 ${props['description']}");
      }
    }

    // ✅ 출발지 & 도착지 마커 추가
    markers.add(
      NMarker(
        id: 'start_marker',
        position: start,
        caption: NOverlayCaption(text: '출발지'),
      ),
    );
    markers.add(
      NMarker(
        id: 'end_marker',
        position: end,
        caption: NOverlayCaption(text: '도착지'),
      ),
    );
  } else {
    guideTexts.add('🚫 도보 경로 실패: \${response.statusCode}');
  }

  return (guideTexts, pathPoints, markers);
}
