import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String tmapApiKey = 'vk8LtDITx13MiOEqJylYL9cVNhmWuLmi3I9rRG76'; // 🔑 TMAP API 키 입력

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

String getClockDirectionFromAngle(double angle) {
  final directions = [
    "12시 방향", "1시 방향", "2시 방향", "3시 방향", "4시 방향",
    "5시 방향", "6시 방향", "7시 방향", "8시 방향", "9시 방향",
    "10시 방향", "11시 방향"
  ];
  final index = ((angle + 15) % 360 ~/ 30) % 12;
  return directions[index];
}

String getRelativeDirection(double angle) {
  if (angle >= 345 || angle < 15) return "직진";
  if (angle >= 15 && angle < 75) return "약간 ${getClockDirectionFromAngle(angle)}";
  if (angle >= 75 && angle < 105) return "우회전";
  if (angle >= 105 && angle < 165) return "약간 ${getClockDirectionFromAngle(angle)}";
  if (angle >= 165 && angle < 195) return "뒤로 돌아가기";
  if (angle >= 195 && angle < 255) return "약간 ${getClockDirectionFromAngle(angle)}";
  if (angle >= 255 && angle < 285) return "좌회전";
  if (angle >= 285 && angle < 345) return "약간 ${getClockDirectionFromAngle(angle)}";
  return "알 수 없는 방향";
}

Future<void> saveRouteStepsToFirestore(
  String uid,
  String routeId,
  Map<String, double> start,
  Map<String, double> end,
  List<Map<String, dynamic>> stepData,
) async {
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
  Map<String, double> start,
  Map<String, double> end,
) async {
  final url =
      'https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1&format=json';
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

  final response =
      await http.post(Uri.parse(url), headers: headers, body: body);
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
  List<Map<String, dynamic>> stepsRecord,
) async {
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
        final dist =
            calculateDistance(prev[1], prev[0], curr[1], curr[0]);
        if (dist >= 5) {
          final angle = atan2(curr[1] - prev[1], curr[0] - prev[0]) * 180 / pi;
          final relativeDirection = getRelativeDirection((angle + 360) % 360);
          final text = "${relativeDirection}으로 ${dist.toStringAsFixed(0)}m 이동하세요";
          guide.add(text);

          stepsRecord.add({
            'text': text,
            'lat': curr[1],
            'lng': curr[0],
            'angle': angle,
            'distance': dist,
          });
        }
      }
    } else if (type == 'Point') {
      final coords = geometry['coordinates'];
      final desc = properties['description']
          ?.replaceAll('<b>', '')
          .replaceAll('</b>', '')
          .trim();

      final facilityType = properties['facilityType'];
      final turnType = properties['turnType'];

      final isCrosswalk = (facilityType == 15) ||
          (turnType != null && turnType >= 211 && turnType <= 217);

      if (isCrosswalk && coords is List && coords.length >= 2) {
        stepsRecord.add({
          'text': 'crosswalk',
          'lat': coords[1],
          'lng': coords[0],
          'type': 'crosswalk',
          'turnType': turnType,
          'facilityType': facilityType,
        });
      }

      if (desc != null &&
          desc.isNotEmpty &&
          coords is List &&
          coords.length >= 2) {
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
  Map<String, double> end,
) async {
  final url =
      'https://apis.openapi.sk.com/transit/routes?version=1&format=json';
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

  final response =
      await http.post(Uri.parse(url), headers: headers, body: body);
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
        final walkGuide =
            await generateStepByStepGuidanceAndSave(features, stepRecords);
        guide.addAll(walkGuide);
      } else if (mode == 'SUBWAY') {
        final text =
            "🚇 ${leg['start']['name']}역에서 ${leg['route']} 탑승 → ${leg['end']['name']}역 하차";
        guide.add(text);
        stepRecords.add({
          'text': text,
          'lat': (leg['start']['lat'] as num).toDouble(),
          'lng': (leg['start']['lon'] as num).toDouble(),
        });
      } else if (mode == 'BUS') {
        final text =
            "🚌 ${leg['start']['name']}에서 ${leg['route']} 버스 탑승 → ${leg['end']['name']} 하차";
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
