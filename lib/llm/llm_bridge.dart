import 'dart:convert';
import 'package:http/http.dart' as http;

class LLMNLGService {
  static const _apiUrl = "http://<YOUR_SERVER_IP>:8000/generate-guidance";

  static Future<String> generateGuidance({
    required String stepDesc,
    String? currentPos,
  }) async {
    final body = jsonEncode({
      "step_desc": stepDesc,
      "current_pos": currentPos ?? "알 수 없음"
    });

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      return result["guidance"];
    } else {
      throw Exception("LLM API 호출 실패: ${response.body}");
    }
  }
}
