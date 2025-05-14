import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  static final FlutterTts _flutterTts = FlutterTts();

  static Future<void> initTts() async {
    await _flutterTts.setLanguage("ko-KR");        // 한국어 설정
    await _flutterTts.setSpeechRate(0.5);           // 말 속도
    await _flutterTts.setPitch(1.0);                // 음높이
  }

  static Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  static Future<void> stop() async {
    await _flutterTts.stop();
  }
}
