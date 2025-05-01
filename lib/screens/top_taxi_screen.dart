// top_taxi_screen.dart
import 'package:flutter/material.dart';

class TopTaxiScreen extends StatelessWidget {
  const TopTaxiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('택시 호출'),
        backgroundColor: Colors.green,
      ),
      body: const Center(
        child: Text(
          '택시 기사 호출 화면입니다.',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    );
  }
}
