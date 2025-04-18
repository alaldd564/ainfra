import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

void main() async {
  await _initialize();
  runApp(const NaverMapApp());
}

// 지도 초기화
Future<void> _initialize() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NaverMapSdk.instance.initialize(
      clientId: '4aktoebb8w',    // 클라이언트 ID
      onAuthFailed: (e) => log("네이버맵 인증오류 : $e", name: "onAuthFailed")
  );
}

class NaverMapApp extends StatelessWidget {
  const NaverMapApp({Key? key});

  @override
  Widget build(BuildContext context) {
    final Completer<NaverMapController> mapControllerCompleter = Completer();

    return MaterialApp(
      home: Scaffold(
        body: NaverMap(
          options: const NaverMapViewOptions(
            indoorEnable: true,             // 실내 맵 사용 가능
            locationButtonEnable: false,    // 위치 버튼 표시
            consumeSymbolTapEvents: false,  // 심볼 탭 이벤
          ),
          onMapReady: (controller) async {                // 지도 준비 완료 시 호출되는 콜백
            mapControllerCompleter.complete(controller);  // Completer에 지도 컨트롤러 완료 신호 전송
            log("onMapReady", name: "onMapReady");
          },
        ),
      ),
    );
  }
}
