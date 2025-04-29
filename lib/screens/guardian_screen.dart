import 'package:flutter/material.dart';

class GuardianHomeScreen extends StatelessWidget {
  const GuardianHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('보호자 홈')),
      body: const Center(child: Text('보호자 전용 서비스')),
    );
  }
}
