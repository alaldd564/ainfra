// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maptest/services/llm_service.dart';
import 'package:maptest/services/tts_service.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

class FirestoreStepsScreen extends StatefulWidget {
  final String uid;
  final String routeId;

  const FirestoreStepsScreen({super.key, required this.uid, required this.routeId});

  @override
  State<FirestoreStepsScreen> createState() => _FirestoreStepsScreenState();
}

class _FirestoreStepsScreenState extends State<FirestoreStepsScreen> {
  List<dynamic>? steps;
  String message = '로드 중...';
  String? llmResponse;
  double? lat, lng, _lastLat, _lastLng;
  Timer? _llmTimer;

  final TtsService _ttsService = TtsService();

  @override
  void initState() {
    super.initState();
    fetchSteps();
  }

  @override
  void dispose() {
    _llmTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchSteps() async {
    try {
      final locDoc = await FirebaseFirestore.instance.collection('locations').doc(widget.uid).get();
      final locData = locDoc.data();
      if (locData == null || locData['lat'] == null || locData['lng'] == null) {
        return setState(() => message = '❌ 위치 정보를 찾을 수 없습니다');
      }

      lat = locData['lat'];
      lng = locData['lng'];
      _lastLat = lat;
      _lastLng = lng;

      final speed = locData['speed'] ?? 1.0;
      final interval = speed < 0.5 ? 4 : (speed < 1.2 ? 7 : 10);
      _llmTimer?.cancel();
      _llmTimer = Timer.periodic(Duration(seconds: interval), (_) => _checkAndUpdateLLM());

      final snapshot = await FirebaseFirestore.instance
          .collection('routes')
          .doc(widget.uid)
          .collection('user_routes')
          .doc(widget.routeId)
          .get();

      final data = snapshot.data();
      if (snapshot.exists && data != null && data.containsKey('steps')) {
        final loadedSteps = data['steps'] as List<dynamic>;
        setState(() {
          steps = loadedSteps;
          message = '✅ steps ${loadedSteps.length}개 불러옴';
        });

        final index = _findClosestStepIndex(lat!, lng!);
        final response = await getNextGuideSentence(
          uid: widget.uid,
          routeId: widget.routeId,
          lat: lat!,
          lng: lng!,
          currentStepIndex: index,
        );

        setState(() => llmResponse = response);

        await _ttsService.speakFromLLM(
          uid: widget.uid,
          routeId: widget.routeId,
          lat: lat!,
          lng: lng!,
          currentStepIndex: index,
        );
      } else {
        setState(() => message = '⚠️ steps 필드가 없거나 문서가 존재하지 않습니다');
      }
    } catch (e) {
      setState(() => message = '🚫 오류 발생: $e');
    }
  }

  Future<void> _checkAndUpdateLLM() async {
    try {
      final locDoc = await FirebaseFirestore.instance.collection('locations').doc(widget.uid).get();
      final locData = locDoc.data();
      if (locData == null || locData['lat'] == null || locData['lng'] == null) return;

      final currentLat = locData['lat'];
      final currentLng = locData['lng'];

      if (_lastLat != null && _lastLng != null) {
        final moved = _distance(_lastLat!, _lastLng!, currentLat, currentLng);
        if (moved < 3) return;
      }

      _lastLat = currentLat;
      _lastLng = currentLng;

      final index = _findClosestStepIndex(currentLat, currentLng);
      final newSentence = await getNextGuideSentence(
        uid: widget.uid,
        routeId: widget.routeId,
        lat: currentLat,
        lng: currentLng,
        currentStepIndex: index,
      );

      setState(() => llmResponse = newSentence);

      await _ttsService.speakFromLLM(
        uid: widget.uid,
        routeId: widget.routeId,
        lat: currentLat,
        lng: currentLng,
        currentStepIndex: index,
      );
    } catch (e) {
      print('🔥 LLM 업데이트 실패: $e');
    }
  }

  int _findClosestStepIndex(double lat, double lng) {
    if (steps == null || steps!.isEmpty) return 0;

    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < steps!.length; i++) {
      final step = steps![i];
      final stepLat = step['lat'];
      final stepLng = step['lng'];
      if (stepLat == null || stepLng == null) continue;

      final dist = _distance(lat, lng, stepLat, stepLng);
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  double _distance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  void _goToMap() {
    if (steps != null && lat != null && lng != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RouteMapScreen(
            steps: steps!,
            initialLat: lat!,
            initialLng: lng!,
            uid: widget.uid,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Firestore + LLM 안내 테스트'),
          backgroundColor: Colors.deepPurple,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, true),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: steps != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text('📋 LLM 안내 문장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(llmResponse ?? '⏳ GPT 응답 대기 중...'),
                    const Divider(),
                    ElevatedButton(
                      onPressed: _goToMap,
                      child: const Text('🗺 경로 포인트 지도 보기'),
                    ),
                    const SizedBox(height: 10),
                    const Text('📌 전체 Steps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: ListView.builder(
                        itemCount: steps!.length,
                        itemBuilder: (context, index) {
                          final step = steps![index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(step.toString(), style: const TextStyle(fontSize: 14)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                )
              : Center(child: Text(message)),
        ),
      ),
    );
  }
}

class RouteMapScreen extends StatefulWidget {
  final List<dynamic> steps;
  final double initialLat;
  final double initialLng;
  final String uid;

  const RouteMapScreen({super.key, required this.steps, required this.initialLat, required this.initialLng, required this.uid});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  late NaverMapController _mapController;
  NMarker? _currentLocationMarker;
  Timer? _locationTimer;

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗺 실시간 경로 지도'),
        backgroundColor: Colors.deepPurple,
      ),
      body: NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(
            target: NLatLng(widget.initialLat, widget.initialLng),
            zoom: 16,
          ),
        ),
        onMapReady: (controller) async {
          _mapController = controller;
          _addStepMarkersAndLine();
          _startLiveLocationUpdates();
        },
      ),
    );
  }

  void _addStepMarkersAndLine() {
    for (int i = 0; i < widget.steps.length; i++) {
      final step = widget.steps[i];
      if (step['lat'] == null || step['lng'] == null) continue;
      final marker = NMarker(
        id: 'marker_$i',
        position: NLatLng(step['lat'], step['lng']),
        caption: NOverlayCaption(
          text: '[$i] ${step['text'] ?? ''}',
          textSize: 14,
          color: Colors.blue,
        ),
      );
      _mapController.addOverlay(marker);
    }

    final path = widget.steps
        .where((s) => s['lat'] != null && s['lng'] != null)
        .map((s) => NLatLng(s['lat'], s['lng']))
        .toList();

    if (path.length >= 2) {
      _mapController.addOverlay(
        NPathOverlay(
          id: 'route_path',
          coords: path,
          width: 4,
          color: Colors.blue,
        ),
      );
    }
  }

  void _startLiveLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final doc = await FirebaseFirestore.instance
          .collection('locations')
          .doc(widget.uid)
          .get();

      final data = doc.data();
      if (data == null || data['lat'] == null || data['lng'] == null) return;

      final lat = data['lat'];
      final lng = data['lng'];

      if (_currentLocationMarker != null) {
        _mapController.deleteOverlay(_currentLocationMarker!);
      }

      _currentLocationMarker = NMarker(
        id: 'current_location',
        position: NLatLng(lat, lng),
        caption: const NOverlayCaption(
          text: '📍 현재 위치',
          textSize: 14,
          color: Colors.red,
        ),
      );

      _mapController.addOverlay(_currentLocationMarker!);
    });
  }
}
