import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsManager {
  static Future<bool> isTtsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('ttsEnabled') ?? true;
  }

  static Future<double> getTtsSpeechRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('speechRate') ?? 0.5;
  }

  static Future<void> speakIfEnabled(FlutterTts tts, String text) async {
    if (await isTtsEnabled()) {
      final rate = await getTtsSpeechRate();
      await tts.setLanguage('ko-KR');
      await tts.setSpeechRate(rate);
      await tts.speak(text);
    }
  }
}