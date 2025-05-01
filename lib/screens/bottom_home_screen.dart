// bottom_home_screen.dart
import 'package:flutter/material.dart';

class BottomHomeScreen extends StatelessWidget {
  const BottomHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('홈 하단'),
        backgroundColor: Colors.orange,
      ),
      body: const Center(
        child: Text(
          '이곳은 추가 기능 혹은 홈 정보입니다.',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    );
  }
}
