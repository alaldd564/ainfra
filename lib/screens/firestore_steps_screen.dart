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
  double? lat;
  double? lng;
  double? _lastLat;
  double? _lastLng;
  Timer? _llmTimer;

  final TtsService _ttsService = TtsService();

  @override
  void initState() {
    super.initState();
    fetchSteps();
    _llmTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkAndUpdateLLM());
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
        setState(() {
          message = '❌ 위치 정보를 찾을 수 없습니다';
        });
        return;
      }

      lat = locData['lat'];
      lng = locData['lng'];
      _lastLat = lat;
      _lastLng = lng;

      final snapshot = await FirebaseFirestore.instance
          .collection('routes')
          .doc(widget.uid)
          .collection('user_routes')
          .doc(widget.routeId)
          .get();

      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data.containsKey('steps')) {
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

          setState(() {
            llmResponse = response;
          });

          await _ttsService.speakFromLLM(
            uid: widget.uid,
            routeId: widget.routeId,
            lat: lat!,
            lng: lng!,
            currentStepIndex: index,
          );
        } else {
          setState(() {
            message = '⚠️ steps 필드가 없습니다';
          });
        }
      } else {
        setState(() {
          message = '❌ 해당 문서를 찾을 수 없습니다';
        });
      }
    } catch (e) {
      setState(() {
        message = '🚫 오류 발생: $e';
      });
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
        if (moved < 3) return; // 3m 이내면 생략
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

      setState(() {
        llmResponse = newSentence;
      });

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
          builder: (_) => RouteMapScreen(steps: steps!, initialLat: lat!, initialLng: lng!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore + LLM 안내 테스트'),
        backgroundColor: Colors.deepPurple,
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
                            child: Text(
                              step.toString(),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              )
            : Center(child: Text(message)),
      ),
    );
  }
}

class RouteMapScreen extends StatelessWidget {
  final List<dynamic> steps;
  final double initialLat;
  final double initialLng;

  const RouteMapScreen({
    super.key,
    required this.steps,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗺 경로 포인트 지도'),
        backgroundColor: Colors.deepPurple,
      ),
      body: NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(
            target: NLatLng(initialLat, initialLng),
            zoom: 16,
          ),
          locationButtonEnable: true,
          scaleBarEnable: true,
        ),
        onMapReady: (controller) async {
          for (int i = 0; i < steps.length; i++) {
            final step = steps[i];
            final lat = step['lat'];
            final lng = step['lng'];
            final text = step['text'] ?? '';

            if (lat != null && lng != null) {
              final marker = NMarker(
                id: 'marker_$i',
                position: NLatLng(lat, lng),
                caption: NOverlayCaption(
                  text: '[$i] $text',
                  textSize: 14,
                  color: Colors.blue,
                ),
              );
              controller.addOverlay(marker);
            }
          }

          controller.addOverlay(
            NMarker(
              id: 'current_location',
              position: NLatLng(initialLat, initialLng),
              caption: const NOverlayCaption(
                text: '📍 현재 위치',
                textSize: 14,
                color: Colors.red,
              ),
            ),
          );
        },
      ),
    );
  }
}
