import 'dart:convert';
import 'package:http/http.dart' as http;

class DirectionsService {
  final String apiKey;

  DirectionsService(this.apiKey);

  Future<Map<String, dynamic>?> getDirections(String origin, String destination) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$apiKey'
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return null;
    }
  }
}
