import 'dart:convert';
import 'package:http/http.dart' as http;

class LLMNLGService {
  static const _apiUrl = "https://api.perplexity.ai/chat/completions";
  static const _apiKey = "YOUR_PERPLEXITY_API_KEY"; // TO-DO : 안전하게 관리하기

  static Future<String> generateGuidance({
    required String stepDesc,
    String? currentPos,
  }) async {
    final headers = {
      "Authorization": "Bearer $_apiKey",
      "Content-Type": "application/json",
    };

    final systemPrompt = '''
당신은 시각장애인을 위한 친절하고 안전한 내비게이션 음성 안내 전문가입니다.
1. 모든 거리는 '미터' 단위로 명확히 알려주세요.
2. 방향 전환 시 주변 랜드마크(예: 편의점, 신호등 등)를 언급하세요.
3. 장애물(계단, 턱, 공사 구간 등)을 사전에 경고하세요.
4. '천천히 걸으세요', '조심하세요'와 같은 배려 문구를 포함하세요.
5. 안내는 2~3문장 이내로 간결하게 해주세요.
6. 마지막에 '필요하면 다시 말씀해드릴 수 있습니다.'로 마무리하세요.
''';

    final userPrompt =
        "현재 위치: ${currentPos ?? '알 수 없음'}, 다음 경로: $stepDesc";

    final body = jsonEncode({
      "model": "sonar",
      "temperature": 0.7,
      "messages": [
        {"role": "system", "content": systemPrompt},
        {"role": "user", "content": userPrompt}
      ]
    });

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      return result['choices'][0]['message']['content'];
    } else {
      throw Exception('Perplexity 호출 실패: ${response.body}');
    }
  }
}
