// left_sos_screen.dart
import 'package:flutter/material.dart';

class LeftSosScreen extends StatelessWidget {
  const LeftSosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('SOS 호출'),
        backgroundColor: Colors.red,
      ),
      body: const Center(
        child: Text(
          '여기는 SOS 호출 화면입니다.',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    );
  }
}