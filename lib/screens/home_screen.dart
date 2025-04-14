// lib/screens/home_screen.dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('길안내 시작')),
      body: Center(child: Text('여기에 목적지 입력창과 시작 버튼이 생길 거예요')),
    );
  }
}
