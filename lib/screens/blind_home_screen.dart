import 'package:flutter/material.dart';

class BlindHomeScreen extends StatelessWidget {
  const BlindHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('시각장애인 홈')),
      body: const Center(child: Text('시각장애인 전용 서비스')),
    );
  }
}
