import 'dart:convert';
import 'package:http/http.dart' as http;

class TMapApi {
  final String apiKey = 'YOUR_TMAP_API_KEY'; // T-Map API Key

  Future<Map<String, dynamic>> getPedestrianRoute(double startX, double startY, double endX, double endY) async {
    final String url = 'https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1&format=json&startX=$startX&startY=$startY&endX=$endX&endY=$endY&appKey=$apiKey';
    
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load route data');
    }
  }
}
