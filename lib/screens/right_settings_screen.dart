import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RightSettingsScreen extends StatefulWidget {
  const RightSettingsScreen({Key? key}) : super(key: key);

  @override
  State<RightSettingsScreen> createState() => _RightSettingsScreenState();
}

class _RightSettingsScreenState extends State<RightSettingsScreen> {
  bool _ttsEnabled = true;
  double _speechRate = 0.5;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('ttsEnabled') ?? true;
    final rate = prefs.getDouble('speechRate') ?? 0.5;

    setState(() {
      _ttsEnabled = enabled;
      _speechRate = rate;
    });

    await _flutterTts.setSpeechRate(_speechRate);

    if (_ttsEnabled) {
      await _flutterTts.speak('음성 안내가 켜졌습니다.');
    }
  }

  Future<void> _toggleTts(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ttsEnabled', enabled);

    setState(() {
      _ttsEnabled = enabled;
    });

    if (enabled) {
      await _flutterTts.speak('음성 안내가 켜졌습니다.');
    } else {
      await _flutterTts.stop();
    }
  }

  Future<void> _setSpeechRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('speechRate', rate);

    setState(() {
      _speechRate = rate;
    });

    await _flutterTts.setSpeechRate(rate);

    if (_ttsEnabled) {
      await _flutterTts.speak('음성 속도가 변경되었습니다.');
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          '설정',
          style: TextStyle(color: Color(0xFFFFD400)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFFFD400)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text(
                '음성 안내',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              value: _ttsEnabled,
              activeColor: const Color(0xFFFFD400),
              onChanged: _toggleTts,
            ),
            ListTile(
              title: const Text(
                '음성 속도',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              subtitle: Slider(
                value: _speechRate,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: _speechRate.toStringAsFixed(1),
                activeColor: const Color(0xFFFFD400),
                onChanged: (value) {
                  _setSpeechRate(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}