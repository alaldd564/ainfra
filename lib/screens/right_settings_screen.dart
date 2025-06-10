import 'package:flutter/material.dart';

class RightSettingsScreen extends StatefulWidget {
  const RightSettingsScreen({Key? key}) : super(key: key);

  @override
  State<RightSettingsScreen> createState() => _RightSettingsScreenState();
}

class _RightSettingsScreenState extends State<RightSettingsScreen> {
  bool _ttsEnabled = true;
  double _speechRate = 0.5;

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
                '음성 on/off',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              value: _ttsEnabled,
              activeColor: const Color(0xFFFFD400),
              onChanged: (value) {
                setState(() {
                  _ttsEnabled = value;
                });
              },
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
                  setState(() {
                    _speechRate = value;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
