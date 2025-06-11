import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String tmapApiKey = '9OYhsHdVeE15l8mol1UWr7BoQyv5BWvr38k1sXvs';

String formatSearchTime(DateTime dt) {
  return "${dt.year.toString().padLeft(4, '0')}"
      "${dt.month.toString().padLeft(2, '0')}"
      "${dt.day.toString().padLeft(2, '0')}"
      "${dt.hour.toString().padLeft(2, '0')}"
      "${dt.minute.toString().padLeft(2, '0')}";
}

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
      sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

String calculateDirection(List prev, List curr) {
  final dx = curr[0] - prev[0];
  final dy = curr[1] - prev[1];
  final angle = atan2(dy, dx) * 180 / pi;
  if (angle >= -45 && angle < 45) return '동쪽 방향';
  if (angle >= 45 && angle < 135) return '북쪽 방향';
  if (angle >= -135 && angle < -45) return '남쪽 방향';
  return '서쪽 방향';
}

Future<void> saveRouteStepsToFirestore(
    String uid,
    String routeId,
    Map<String, double> start,
    Map<String, double> end,
    List<Map<String, dynamic>> stepData) async {
  await FirebaseFirestore.instance
      .collection('routes')
      .doc(uid)
      .collection('user_routes')
      .doc(routeId)
      .set({
    'createdAt': FieldValue.serverTimestamp(),
    'start': start,
    'end': end,
    'steps': stepData,
  });
}

Future<List<Map<String, dynamic>>> getPedestrianRoute(
    Map<String, double> start, Map<String, double> end) async {
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

Future<List<String>> generateStepByStepGuidanceAndSave(
    List<Map<String, dynamic>> features,
    List<Map<String, dynamic>> stepsRecord) async {
  List<String> guide = [];

  for (final feature in features) {
    final geometry = feature['geometry'];
    final properties = feature['properties'];
    final type = geometry['type'];

    if (type == 'LineString') {
      final coords = geometry['coordinates'] as List;
      for (int i = 1; i < coords.length; i++) {
        final prev = coords[i - 1];
        final curr = coords[i];
        final dist = calculateDistance(prev[1], prev[0], curr[1], curr[0]);
        if (dist >= 5) {
          final direction = calculateDirection(prev, curr);
          final text = "🚶 ${dist.toStringAsFixed(0)}m $direction";
          guide.add(text);

          stepsRecord.add({
            'text': text,
            'lat': curr[1],
            'lng': curr[0],
            'angle': atan2(curr[1] - prev[1], curr[0] - prev[0]) * 180 / pi,
            'distance': dist
          });
        }
      }
    } else if (type == 'Point') {
      final coords = geometry['coordinates'];
      final desc = properties['description']
          ?.replaceAll('<b>', '')
          .replaceAll('</b>', '')
          .trim();
      if (desc != null && desc.isNotEmpty && coords is List && coords.length >= 2) {
        final text = "📍 $desc";
        guide.add(text);
        stepsRecord.add({
          'text': text,
          'lat': coords[1],
          'lng': coords[0],
          'type': 'Point',
        });
      }
    }
  }

  return guide;
}

Future<List<Map<String, dynamic>>> generateAllHybridRoutes(
    Map<String, double> start,
    Map<String, double> end) async {
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
    print("🚫 대중교통 API 실패: ${response.statusCode}");
    return [
      {
        'route_id': 'error',
        'lines': ["❌ 경로 안내를 불러오지 못했습니다."]
      }
    ];
  }

  final data = json.decode(response.body);
  final itineraries = data['metaData']['plan']['itineraries'] as List;

  final uid = FirebaseAuth.instance.currentUser?.uid ?? "unknown_user";

  List<Map<String, dynamic>> allRoutes = [];

  for (final itinerary in itineraries) {
    final List<String> guide = [];
    final List<Map<String, dynamic>> stepRecords = [];
    final totalTimeMin = (itinerary['totalTime'] / 60).round();
    final transferCount = itinerary['transferCount'] ?? 0;
    int totalWalkTime = 0;
    Set<String> transportModes = {};

    guide.add("⏱️ 총 소요 시간: ${totalTimeMin}분");
    guide.add("🔁 환승 횟수: ${transferCount}회");

    final legs = itinerary['legs'] as List;
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
        final walkGuide = await generateStepByStepGuidanceAndSave(features, stepRecords);
        guide.addAll(walkGuide);
      } else if (mode == 'SUBWAY') {
        final text = "🚇 ${leg['start']['name']}역에서 ${leg['route']} 탑승 → ${leg['end']['name']}역 하차";
        guide.add(text);
        stepRecords.add({
          'text': text,
          'lat': (leg['start']['lat'] as num).toDouble(),
          'lng': (leg['start']['lon'] as num).toDouble(),
        });
      } else if (mode == 'BUS') {
        final text = "🚌 ${leg['start']['name']}에서 ${leg['route']} 버스 탑승 → ${leg['end']['name']} 하차";
        guide.add(text);
        stepRecords.add({
          'text': text,
          'lat': (leg['start']['lat'] as num).toDouble(),
          'lng': (leg['start']['lon'] as num).toDouble(),
        });
      }
    }

    guide.insert(2, "🚶 도보 시간: ${(totalWalkTime / 60).round()}분");
    guide.insert(3, "🧭 이용 수단: ${transportModes.join(', ')}");

    final routeId = "route_${DateTime.now().millisecondsSinceEpoch}";
    await saveRouteStepsToFirestore(uid, routeId, start, end, stepRecords);

    allRoutes.add({
      'route_id': routeId,
      'lines': guide,
    });
  }

  return allRoutes;
}
