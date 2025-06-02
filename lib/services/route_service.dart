import 'dart:convert';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;

// ✅ 직접 API 키 입력
const String tmapApiKey = 'Jpdc9otrzA2ZTXkYregN2akyQFKvDUYa6iJFWaGW';

/// ✅ 경로 옵션 Enum
enum RouteOptionType {
  walkingOnly,
  integrated,
  publicOnly,
  minimumTransfer,
  shortestTime,
}

const Map<RouteOptionType, String> routeOptionLabel = {
  RouteOptionType.walkingOnly: "도보 위주",
  RouteOptionType.integrated: "도보 + 대중교통",
  RouteOptionType.publicOnly: "대중교통 위주",
  RouteOptionType.minimumTransfer: "최소 환승",
  RouteOptionType.shortestTime: "최단 시간",
};

/// 🚶 도보 경로 탐색 함수
Future<List<String>> getWalkingRoute(NLatLng start, NLatLng end) async {
  const url = 'https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1&format=json';

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
          final desc = props['description'] as String;
          if (!desc.contains('lineString')) {
            guideTexts.add("🔹 $desc");
          }
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

/// 🧭 대중교통 URL 생성 함수
String buildTransitUrl(NLatLng start, NLatLng end, RouteOptionType option) {
  String searchType = '0';
  switch (option) {
    case RouteOptionType.minimumTransfer:
      searchType = '1';
      break;
    case RouteOptionType.shortestTime:
      searchType = '2';
      break;
    default:
      searchType = '0';
  }
  return 'https://apis.openapi.sk.com/transit/routes?version=1&format=json'
         '&startX=${start.longitude}&startY=${start.latitude}'
         '&endX=${end.longitude}&endY=${end.latitude}'
         '&searchType=$searchType';
}

/// 🚌 대중교통 경로 탐색 (옵션 기반)
Future<List<String>> getTransitRouteByType(
  NLatLng start,
  NLatLng end,
  RouteOptionType option,
) async {
  final url = buildTransitUrl(start, end, option);

  final headers = {
    'accept': 'application/json',
    'appKey': tmapApiKey,
  };

  final response = await http.get(Uri.parse(url), headers: headers);
  List<String> guideTexts = [];

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final itinerary = data['metaData']['plan']['itineraries'][0];
    final timeMin = (itinerary['totalTime'] / 60).round();
    guideTexts.add("🚌 예상 소요 시간: ${timeMin}분");

    for (final leg in itinerary['legs']) {
      final mode = leg['mode'];
      final sectionTime = leg['sectionTime'];

      if (mode == 'WALK') {
        final distance = leg['distance'];
        guideTexts.add("🚶 ${distance}m 도보 이동 (${sectionTime}분)");
      } else if (mode == 'BUS') {
        final busNo = leg['route'];
        final startName = leg['start']['name'];
        final endName = leg['end']['name'];
        final stationCount = leg['passStopList']['stations'].length;
        guideTexts.add("🚌 ${startName}에서 ${busNo}번 버스 탑승 후 ${stationCount}개 정류장 이동, ${endName}에서 하차");
      } else if (mode == 'SUBWAY') {
        final subwayNo = leg['route'];
        final startName = leg['start']['name'];
        final endName = leg['end']['name'];
        guideTexts.add("🚇 ${startName}에서 ${subwayNo} 지하철 탑승 후 ${endName}에서 하차");
      }
    }
  } else {
    guideTexts.add('🚫 대중교통 실패: ${response.statusCode}');
  }

  return guideTexts;
}

/// 🔀 통합 경로 탐색 함수
Future<List<String>> getRouteByOption(
  NLatLng start,
  NLatLng end,
  RouteOptionType option,
) async {
  switch (option) {
    case RouteOptionType.walkingOnly:
      return await getWalkingRoute(start, end);
    case RouteOptionType.publicOnly:
    case RouteOptionType.minimumTransfer:
    case RouteOptionType.shortestTime:
      return await getTransitRouteByType(start, end, option);
    case RouteOptionType.integrated:
      final walk = await getWalkingRoute(start, end);
      final transit = await getTransitRouteByType(start, end, RouteOptionType.shortestTime);
      return [...walk, ...transit];
  }
}
