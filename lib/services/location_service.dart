import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class LocationService {
  Timer? _timer;

  /// 위치 권한 요청 + 30초마다 위치 전송
  Future<void> startTrackingAndSend({
    required String userId,
    LocationAccuracy accuracy = LocationAccuracy.best,
    Duration interval = const Duration(seconds: 30),
    String serverUrl = "https://tmap-backend.onrender.com/update_location",
  }) async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      // ✅ 시작 시 최초 한 번 위치 전송
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

      // ✅ 이후 주기적으로 위치 전송
      _timer = Timer.periodic(interval, (Timer timer) async {
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
        } catch (e) {
          print("⚠️ 위치 가져오기 실패: $e");
        }
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

  /// 추적 중지
  void stopTracking() {
    _timer?.cancel();
    print('🛑 위치 추적 중지됨');
  }
}
