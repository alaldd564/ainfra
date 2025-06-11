import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maptest/services/llm_service.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();

  TtsService() {
    _initTts();
  }

  /// TTS 초기 설정 (언어, 속도)
  Future<void> _initTts() async {
    final rate = await _getSpeechRate();
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(rate);
  }

  /// SharedPreferences에서 저장된 속도 불러오기
  Future<double> _getSpeechRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('speechRate') ?? 0.5;
  }

  /// TTS 사용 설정 여부 확인
  Future<bool> _isTtsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('ttsEnabled') ?? true;
  }

  /// LLM에서 문장을 받아와 TTS로 읽어주는 메서드
  Future<void> speakFromLLM({
    required String uid,
    required String routeId,
    required double lat,
    required double lng,
    required int currentStepIndex,
  }) async {
    final isEnabled = await _isTtsEnabled();
    if (!isEnabled) return;

    try {
      final sentence = await getNextGuideSentence(
        uid: uid,
        routeId: routeId,
        lat: lat,
        lng: lng,
        currentStepIndex: currentStepIndex,
      );

      await _tts.speak(sentence);
    } catch (e) {
      print('🧨 TTS 오류: $e');
    }
  }
}
