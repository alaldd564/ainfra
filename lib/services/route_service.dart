import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

const String tmapApiKey = 'pcYktIoix72G2CzONg9ZG7W6Ks5q6En75ooM09H8';

// 현재 시간 포맷 (API용)
String formatSearchTime(DateTime dt) {
  return "${dt.year.toString().padLeft(4, '0')}"
      "${dt.month.toString().padLeft(2, '0')}"
      "${dt.day.toString().padLeft(2, '0')}"
      "${dt.hour.toString().padLeft(2, '0')}"
      "${dt.minute.toString().padLeft(2, '0')}";
}

// 거리 계산 (Haversine 공식)
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

// 방향 계산
String calculateDirection(List prev, List curr) {
  final dx = curr[0] - prev[0];
  final dy = curr[1] - prev[1];
  final angle = atan2(dy, dx) * 180 / pi;
  if (angle >= -45 && angle < 45) return '동쪽 방향';
  if (angle >= 45 && angle < 135) return '북쪽 방향';
  if (angle >= -135 && angle < -45) return '남쪽 방향';
  return '서쪽 방향';
}

// 종합 경로 문서와 자형을 Firestore에 저장
Future<void> saveRouteStepsToFirestore(
    Map<String, double> start,
    Map<String, double> end,
    List<Map<String, dynamic>> stepData) async {
  final docId = "route_${DateTime.now().millisecondsSinceEpoch}";
  await FirebaseFirestore.instance.collection('routes').doc(docId).set({
    'createdAt': FieldValue.serverTimestamp(),
    'start': start,
    'end': end,
    'steps': stepData,
  });
}

// 보효 경로 API 호출
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
    print("\u{1F6AB} 보행 API 실패: ${response.statusCode}");
    return [];
  }
}

// 경로 안내원 + Firestore에 step정보 저장해주기
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
      final desc = properties['description']
          ?.replaceAll('<b>', '')
          .replaceAll('</b>', '')
          .trim();
      if (desc != null && desc.isNotEmpty) {
        final text = "📍 $desc";
        guide.add(text);
        stepsRecord.add({'text': text, 'type': 'Point'});
      }
    }
  }
  return guide;
}

// 하이브리드 경로 개선 (도보 + 대중군)
Future<List<List<String>>> generateAllHybridRoutes(
    Map<String, double> start, Map<String, double> end) async {
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
    print("\u{1F6AB} 대중교통 API 실패: ${response.statusCode}");
    return [
      ["❌ 경로 안내를 불러오지 못했습니다."]
    ];
  }

  final data = json.decode(response.body);
  final itineraries = data['metaData']['plan']['itineraries'] as List;

  List<List<String>> allRoutes = [];

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
        guide.add("🚇 ${leg['start']['name']}역에서 ${leg['route']} 탑승 → ${leg['end']['name']}역 하차");
      } else if (mode == 'BUS') {
        guide.add("🚌 ${leg['start']['name']}에서 ${leg['route']} 버스 탑승 → ${leg['end']['name']} 하차");
      }
    }

    guide.insert(2, "🚶 도보 시간: ${(totalWalkTime / 60).round()}분");
    guide.insert(3, "🧭 이용 수단: ${transportModes.join(', ')}");

    await saveRouteStepsToFirestore(start, end, stepRecords);
    allRoutes.add(guide);
  }

  return allRoutes;
}
