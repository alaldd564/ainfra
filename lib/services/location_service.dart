// lib/services/location_service.dart

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationService {
  Stream<Position>? _positionStream;

  /// 위치 권한 요청 + 초기 위치 전송 + 스트림 시작
  Future<void> startTrackingAndSend({
    required String userId,
    LocationAccuracy accuracy = LocationAccuracy.best,
    int distanceFilter = 10,
    String serverUrl = "https://tmap-backend.onrender.com/update_location",
  }) async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      // ✅ 실행하자마자 현재 위치 한 번 전송
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
      } catch (e) {
        print("⚠️ 현재 위치 가져오기 실패: $e");
      }

      // ✅ 이후 실시간 스트리밍
      _positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
        ),
      );

      _positionStream!.listen((Position position) async {
        print('📡 실시간 위치: ${position.latitude}, ${position.longitude}');
        await postLocationToServer(
          userId: userId,
          latitude: position.latitude,
          longitude: position.longitude,
          serverUrl: serverUrl,
        );
      });
    } else {
      print("❌ 위치 권한 거부됨");
    }
  }

  /// 서버로 위치 POST 요청 보내기
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
}
