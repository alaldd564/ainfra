import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;

class TmapLaunchScreen extends StatefulWidget {
  const TmapLaunchScreen({super.key});

  @override
  State<TmapLaunchScreen> createState() => _TmapLaunchScreenState();
}

class _TmapLaunchScreenState extends State<TmapLaunchScreen> {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  static const platform = MethodChannel('tmap_channel');

  Future<void> _launchMapActivityWithPublicTransitRoute() async {
    try {
      await platform.invokeMethod(
        'launchMapActivityWithPublicTransitRoute',
        {
          'origin': _originController.text,
          'destination': _destinationController.text,
        },
      );
    } on PlatformException catch (e) {
      developer.log('Tmap 대중교통 길찾기 실패', error: e);
    }
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tmap 지도 테스트')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _originController,
              decoration: const InputDecoration(
                labelText: '출발지',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: '도착지',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: _launchMapActivityWithPublicTransitRoute,
              child: const Text('대중교통 길찾기'),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () async {
                try {
                  await platform.invokeMethod('launchMapActivity');
                } on PlatformException catch (e) {
                  developer.log('기본 지도 띄우기 실패', error: e);
                }
              },
              child: const Text('기본 지도 띄우기'),
            ),
          ],
        ),
      ),
    );
  }
}