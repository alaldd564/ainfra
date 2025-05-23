import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;

class TmapLaunchScreen extends StatelessWidget {
  const TmapLaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tmap 지도 테스트')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            const platform = MethodChannel('tmap_channel');
            try {
              await platform.invokeMethod('launchMapActivity');
            } on PlatformException catch (e) {
              developer.log('Tmap launch failed', error: e);
            }
          },
          child: const Text('지도 띄우기'),
        ),
      ),
    );
  }
}
