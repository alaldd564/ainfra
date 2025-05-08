import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ainfra/screens/brightness_settings.dart';

class RightSettingsScreen extends StatelessWidget {
  const RightSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<BrightnessSettings>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('전체 화면 설정')),
      body: Row(
        children: [
          _buildSlider('밝기', settings.brightness, Colors.yellow, settings.updateBrightness),
          _buildSlider('채도', settings.saturation, Colors.pink, settings.updateSaturation),
          _buildSlider('명도', settings.lightness, Colors.cyan, settings.updateLightness),
          Expanded(
            child: Center(
              child: Text(
                '전체 화면 색조정',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, Color color, void Function(double) onChanged) {
    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          Expanded(
            child: RotatedBox(
              quarterTurns: -1,
              child: Slider(
                value: value,
                min: 0,
                max: 1,
                activeColor: color,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}