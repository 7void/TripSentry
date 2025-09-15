import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // Each message map: { sender: user|bot, type: text|places, text: String, places: List<Map<String,dynamic>>? }
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  static final String _geminiKey = dotenv.env['GEMINI_API'] ?? '';
  static final String _googleKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
  // OpenWeatherMap API key (must be set in .env as WEATHER_API_KEY)
  static final String _weatherKey = dotenv.env['OPENWEATHER_API_KEY'] ?? '';

  // 🔹 Get user’s current location
  Future<Position> _getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  // 🔹 Google Places API returning structured results
  Future<Map<String, dynamic>> _getNearbyPlaces(String keyword) async {
    if (_googleKey.isEmpty) {
      return {
        'error': 'Google Places API key missing (GOOGLE_API_KEY in .env).'
      };
    }
    try {
      final pos = await _getCurrentLocation();
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${pos.latitude},${pos.longitude}'
        '&radius=3000&keyword=${Uri.encodeComponent(keyword)}&key=$_googleKey',
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] != 'OK') {
          return {'error': 'Places API: ${data['status']}'};
        }
        final List results = data['results'];
        final top = results.take(5).map((r) {
          final loc = r['geometry']?['location'] ?? {};
          return {
            'name': r['name'] ?? 'Unknown',
            'vicinity': r['vicinity'] ?? '',
            'place_id': r['place_id'],
            'lat': loc['lat'],
            'lng': loc['lng'],
            'rating': r['rating'],
            'types': r['types'],
          };
        }).toList();
        return {
          'places': top,
          'userLat': pos.latitude,
          'userLng': pos.longitude,
          'keyword': keyword,
        };
      }
      return {'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'error': 'Places error: $e'};
    }
  }

  // 🔹 Weather via OpenWeatherMap (requires WEATHER_API_KEY). Provides temp, description, humidity & wind.
  Future<String> _getWeather() async {
    if (_weatherKey.isEmpty) {
      return 'Weather API key missing. Add WEATHER_API_KEY to .env and restart the app.';
    }

    Position pos;
    try {
      pos = await _getCurrentLocation();
    } on PermissionDeniedException {
      return 'Location permission denied. Enable location to get weather.';
    } catch (e) {
      return 'Could not get location: $e';
    }

    final uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=${pos.latitude}&lon=${pos.longitude}&appid=$_weatherKey&units=metric');
    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        // Try to parse error body for more details
        try {
          final err = jsonDecode(response.body);
          final msg = err['message'];
          if (msg is String && msg.isNotEmpty) {
            return 'Weather error (${response.statusCode}): $msg';
          }
        } catch (_) {}
        return 'Weather fetch failed (HTTP ${response.statusCode}).';
      }

      final data = jsonDecode(response.body);
      final main = data['main'] ?? {};
      final weatherList = data['weather'];
      final wind = data['wind'] ?? {};
      final temp = main['temp'];
      final humidity = main['humidity'];
      String desc = '';
      if (weatherList is List && weatherList.isNotEmpty) {
        desc = weatherList[0]['description'] ?? '';
      }
      final windSpeed = wind['speed'];
      if (temp == null) return 'Weather data unavailable.';
      return 'Weather: ${temp.toString()}°C, ${desc.isEmpty ? 'conditions unknown' : desc} | Humidity: ${humidity ?? '-'}% | Wind: ${windSpeed ?? '-'} m/s';
    } catch (e) {
      return 'Weather parse/network error: $e';
    }
  }

  // 🔹 Gemini API fallback
  Future<String> _sendToGemini(String userMessage) async {
    if (_geminiKey.isEmpty) {
      return 'API key missing. Add GEMINI_API to .env.';
    }

    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiKey');

    try {
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': userMessage}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        return text ?? 'Empty response.';
      }

      try {
        final err = jsonDecode(response.body);
        final msg = err['error']?['message'];
        if (msg is String && msg.isNotEmpty) {
          return 'Error ${response.statusCode}: $msg';
        }
      } catch (_) {}
      return 'Error ${response.statusCode}: ${response.reasonPhrase}';
    } catch (e) {
      return 'Network error: $e';
    }
  }

  // 🔹 Decide whether to call Places, Weather, or Gemini
  bool _isPlacesIntent(String lower) {
    const placeWords = [
      'nearby',
      'restaurant',
      'restaurants',
      'hotel',
      'hotels',
      'atm',
      'police',
      'police station',
      'hospital',
      'hospitals',
      'pharmacy',
      'pharmacies',
      'nearest',
      'close by',
      'around me'
    ];
    return placeWords.any((w) => lower.contains(w));
  }

  String _extractKeyword(String lower) {
    // Basic heuristic: remove helper words.
    var cleaned = lower;
    for (final filler in ['nearby', 'nearest', 'close by', 'around me']) {
      cleaned = cleaned.replaceAll(filler, '');
    }
    cleaned = cleaned.trim();
    if (cleaned.isEmpty) return 'police station'; // default to safety-relevant
    return cleaned;
  }

  Future<void> _handleUserQuery(String original) async {
    final lower = original.toLowerCase();
    if (lower.contains('weather')) {
      final w = await _getWeather();
      _appendBotText(w);
    } else if (_isPlacesIntent(lower)) {
      final keyword = _extractKeyword(lower);
      final result = await _getNearbyPlaces(keyword);
      if (result['error'] != null) {
        _appendBotText(result['error']);
      } else {
        _appendBotPlaces(
          intro: 'Here are nearby ${result['keyword']} (tap to open in Maps):',
          places: (result['places'] as List).cast<Map<String, dynamic>>(),
          userLat: result['userLat'],
          userLng: result['userLng'],
        );
      }
    } else {
      final t = await _sendToGemini(original);
      _appendBotText(t);
    }
  }

  void _appendBotText(String text) {
    setState(() {
      _messages.add({'sender': 'bot', 'type': 'text', 'text': text});
      _isLoading = false;
    });
    _scrollToBottomDeferred();
  }

  void _appendBotPlaces(
      {required String intro,
      required List<Map<String, dynamic>> places,
      double? userLat,
      double? userLng}) {
    setState(() {
      _messages.add({
        'sender': 'bot',
        'type': 'places',
        'text': intro,
        'places': places,
        'userLat': userLat,
        'userLng': userLng,
      });
      _isLoading = false;
    });
    _scrollToBottomDeferred();
  }

  void _sendMessage() async {
    if (_isLoading) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottomDeferred();

    await _handleUserQuery(text);
  }

  void _scrollToBottomDeferred() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chatbot"),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                final type = msg['type'] ?? 'text';
                Widget bubbleChild;
                if (type == 'places') {
                  bubbleChild = _buildPlacesBubble(msg);
                } else {
                  bubbleChild = SelectableText(
                    msg['text'] ?? '',
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black,
                    ),
                  );
                }
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            isUser ? Colors.blueAccent : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: bubbleChild,
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Ask me anything...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : _sendMessage,
                  color: _isLoading ? Colors.grey : null,
                  tooltip: _isLoading ? 'Waiting for response...' : 'Send',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesBubble(Map<String, dynamic> msg) {
    final List places = msg['places'] ?? [];
    final intro = msg['text'] ?? 'Nearby places:';
    if (places.isEmpty) {
      return Text('$intro\n(No results)');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(intro, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...places.map((p) {
          final name = p['name'] ?? 'Unknown';
          final vicinity = p['vicinity'] ?? '';
          final lat = p['lat'];
          final lng = p['lng'];
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              title: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle:
                  Text(vicinity, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.map, color: Colors.blueAccent),
                tooltip: 'Open in Google Maps',
                onPressed: (lat == null || lng == null)
                    ? null
                    : () => _openInMaps(lat, lng, p['place_id']),
              ),
              onTap: (lat == null || lng == null)
                  ? null
                  : () => _openInMaps(lat, lng, p['place_id']),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _openInMaps(double lat, double lng, String? placeId) async {
    final url = placeId != null
        ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$placeId'
        : 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }
}
