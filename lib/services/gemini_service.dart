import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  final String apiKey = "AIzaSyAz1TPtNWV3A1xfi7PS6-51ejoMZa1AmHs"; // 🔑 Replace with your Gemini API key
  final String baseUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent";

  Future<String> sendMessage(String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl?key=$apiKey"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {"text": userMessage}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["candidates"][0]["content"]["parts"][0]["text"];
      } else {
        return "❌ Error: ${response.body}";
      }
    } catch (e) {
      return "⚠️ Failed to connect: $e";
    }
  }
}
