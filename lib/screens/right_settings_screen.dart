// right_settings_screen.dart
import 'package:flutter/material.dart';

class RightSettingsScreen extends StatelessWidget {
  const RightSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('화면 설정'),
        backgroundColor: Colors.blueGrey,
      ),
      body: const Center(
        child: Text(
          '화면 채도/명도/밝기 조절 화면입니다.',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    );
  }
}