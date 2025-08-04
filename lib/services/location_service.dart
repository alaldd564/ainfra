import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';

class LocationService {
  bool _isTracking = false;
  double? _lastLat;
  double? _lastLng;
  DateTime? _lastTimestamp;

  /// 위치 추적 및 Firebase + 외부 서버 전송 시작
  Future<void> startTrackingAndSend({
    required String userId,
    LocationAccuracy accuracy = LocationAccuracy.best,
    Duration interval = const Duration(seconds: 5),
    String serverUrl = "https://tmap-backend.onrender.com/update_location",
  }) async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      _isTracking = true;

      // ✅ 초기 위치 한 번 전송
      try {
        final currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: accuracy,
        );
        print('🚀 초기 위치 전송: ${currentPosition.latitude}, ${currentPosition.longitude}');
        await postLocationToServer(
          userId: userId,
          latitude: currentPosition.latitude,
          longitude: currentPosition.longitude,
          serverUrl: serverUrl,
        );
        await updateFirestoreLocation(
          userId: userId,
          latitude: currentPosition.latitude,
          longitude: currentPosition.longitude,
        );
      } catch (e) {
        print("⚠️ 현재 위치 가져오기 실패: $e");
      }

      // ✅ 이후 루프 기반 주기적 위치 전송
      _startLoop(
        userId: userId,
        accuracy: accuracy,
        interval: interval,
        serverUrl: serverUrl,
      );
    } else {
      print("❌ 위치 권한 거부됨");
    }
  }

  /// 루프 기반 위치 전송
  Future<void> _startLoop({
    required String userId,
    required LocationAccuracy accuracy,
    required Duration interval,
    required String serverUrl,
  }) async {
    while (_isTracking) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: accuracy,
        );

        print('🕒 ${DateTime.now()} - 위치 전송: ${position.latitude}, ${position.longitude}');

        await postLocationToServer(
          userId: userId,
          latitude: position.latitude,
          longitude: position.longitude,
          serverUrl: serverUrl,
        );

        await updateFirestoreLocation(
          userId: userId,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } catch (e) {
        print("⚠️ 위치 가져오기 실패: $e");
      }

      await Future.delayed(interval);
    }
  }

  /// 서버로 위치 전송
  Future<void> postLocationToServer({
    required String userId,
    required double latitude,
    required double longitude,
    required String serverUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ 위치 서버 전송 성공');
      } else {
        print('❌ 서버 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('🚨 서버 전송 실패: $e');
    }
  }

  /// Firestore에 위치, angle, 속도 저장
  Future<void> updateFirestoreLocation({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      double? angle;
      double? speed;
      final now = DateTime.now();

      if (_lastLat != null && _lastLng != null && _lastTimestamp != null) {
        final dx = longitude - _lastLng!;
        final dy = latitude - _lastLat!;
        angle = atan2(dy, dx) * 180 / pi;
        if (angle < 0) angle += 360;

        // 거리 계산 (Haversine)
        final distance = _calculateDistance(_lastLat!, _lastLng!, latitude, longitude);
        final timeDiff = now.difference(_lastTimestamp!).inMilliseconds / 1000;
        if (timeDiff > 0) {
          speed = distance / timeDiff;
        }
      }

      // 상태 업데이트
      _lastLat = latitude;
      _lastLng = longitude;
      _lastTimestamp = now;

      await FirebaseFirestore.instance.collection('locations').doc(userId).set({
        'lat': latitude,
        'lng': longitude,
        'timestamp': Timestamp.now(),
        'location_shared': true,
        if (angle != null) 'angle': angle,
        if (speed != null) 'speed': speed,
      }, SetOptions(merge: true));

      print('✅ Firebase 저장 완료: ${angle?.toStringAsFixed(1)}°, 속도: ${speed?.toStringAsFixed(2)} m/s');
    } catch (e) {
      print('❌ Firebase 저장 실패: $e');
    }
  }

  /// 위치 추적 중단
  void stopTracking() {
    _isTracking = false;
    print('🛑 위치 추적 중지됨');
  }

  /// Haversine 거리 계산 함수 (meter)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }
}
