import 'package:flutter/material.dart';
import 'screens/tmap_launch_screen.dart'; // <- 이 줄 추가

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TmapLaunchScreen(), // <- 이 화면을 초기화면으로 지정
    );
  }
}
