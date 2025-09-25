import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/voice_assistant_service.dart';
import '../services/tts_service.dart';
import '../services/chat_session_service.dart';

class ChatScreen extends StatefulWidget {
  final String? initialMessage; // Optional: process a message on open
  const ChatScreen({super.key, this.initialMessage});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // Each message map: { sender: user|bot, type: text|places|route, text: String, places: List<Map<String,dynamic>>?, route: Map? }
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _initialProcessed =
      false; // kept for backward compatibility if initialMessage is provided once
  final TtsService _tts = TtsService();
  bool _ttsEnabled = true;
  StreamSubscription<String>? _sessionSub;
  final VoiceAssistantService _vas = VoiceAssistantService();
  // Active listening (push-to-talk) state
  bool _activeListening = false;
  String _partialTranscript = '';
  StreamSubscription<VoiceAssistantEvent>? _vasEventSub;
  bool _gotFinalThisSession = false;
  int _pttSessionCounter =
      0; // increments per mic session to ignore stale events

  static final String _geminiKey = dotenv.env['GEMINI_API'] ?? '';
  static final String _googleKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
  // OpenWeatherMap API key (must be set in .env as OPENWEATHER_API_KEY)
  static final String _weatherKey = dotenv.env['OPENWEATHER_API_KEY'] ?? '';

  // Tracking preference key (kept in sync with home_screen) & gating message
  static const String _kTrackingPrefKey = 'tracking_enabled';
  static const String _kEnableTrackingMsg = 'enable tracking in home screen';
  // TTS preference key
  static const String _kTtsEnabledPrefKey = 'tts_enabled';

  // How many past messages to send to Gemini for context
  static const int _kContextWindow = 12; // last 12 entries (user+bot)

  // Helper to read whether tracking is enabled (defaults to true if missing or error)
  Future<bool> _isTrackingEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kTrackingPrefKey) ?? true;
    } catch (_) {
      // Fail open to avoid blocking features unexpectedly
      return true;
    }
  }

  @override
  void initState() {
    super.initState();
    // Load persisted TTS preference
    () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getBool(_kTtsEnabledPrefKey);
        if (saved != null) {
          if (mounted) {
            setState(() => _ttsEnabled = saved);
          } else {
            _ttsEnabled = saved;
          }
        }
      } catch (_) {}
    }();
    // Mark chat open and subscribe to voice session stream
    ChatSessionService.instance.setOpen(true);
    _sessionSub = ChatSessionService.instance.stream.listen((msg) {
      // Push incoming voice messages into this conversation
      if (mounted) {
        setState(() {
          _messages.add({'sender': 'user', 'text': msg});
          _isLoading = true;
        });
        _scrollToBottomDeferred();
        _handleUserQuery(msg);
      }
    });
    // Backward compatibility: support initialMessage when navigating initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialProcessed) {
        final msg = widget.initialMessage?.trim();
        if (msg != null && msg.isNotEmpty) {
          _initialProcessed = true;
          ChatSessionService.instance.sendVoiceMessage(msg);
        }
      }
    });
  }

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
      return 'Weather API key missing. Add OPENWEATHER_API_KEY to .env and restart the app.';
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

  // 🔹 Resolve a city name to coordinates using OpenWeatherMap Direct Geocoding API
  Future<Map<String, double>> _geocodeCity(String city) async {
    final url = Uri.parse(
        'https://api.openweathermap.org/geo/1.0/direct?q=${Uri.encodeComponent(city)}&limit=1&appid=$_weatherKey');
    try {
      final resp = await http.get(url);
      if (resp.statusCode != 200) return {};
      final data = jsonDecode(resp.body);
      if (data is List && data.isNotEmpty) {
        final first = data[0];
        final lat = (first['lat'] as num?)?.toDouble();
        final lon = (first['lon'] as num?)?.toDouble();
        if (lat != null && lon != null) {
          return {'lat': lat, 'lon': lon};
        }
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  // 🔹 Weather for a specified city name (uses geocoding then regular weather fetch)
  Future<String> _getWeatherForCity(String city) async {
    if (_weatherKey.isEmpty) {
      return 'Weather API key missing. Add OPENWEATHER_API_KEY to .env and restart the app.';
    }
    final coords = await _geocodeCity(city);
    if (coords.isEmpty) {
      return 'Could not find city: $city';
    }
    final uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=${coords['lat']}&lon=${coords['lon']}&appid=$_weatherKey&units=metric');
    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
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
      if (temp == null) return 'Weather data unavailable for $city.';
      return 'Weather in ${_capitalizeWords(city)}: ${temp.toString()}°C, ${desc.isEmpty ? 'conditions unknown' : desc} | Humidity: ${humidity ?? '-'}% | Wind: ${windSpeed ?? '-'} m/s';
    } catch (e) {
      return 'Weather parse/network error: $e';
    }
  }

  String _capitalizeWords(String input) {
    return input
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  // 🔹 Gemini API with conversation history
  Future<String> _sendToGeminiWithHistory(String userMessage) async {
    if (_geminiKey.isEmpty) {
      return 'API key missing. Add GEMINI_API to .env.';
    }

    // Build contents with a rolling window of recent messages for context
    final contents = <Map<String, dynamic>>[];

    // Optional lightweight system-style primer as first content for steerability
    contents.add({
      'role': 'user',
      'parts': [
        {
          'text':
              'You are Sentry, a concise, helpful travel/chat assistant. Use prior messages as context. When I ask follow-ups, remember details from earlier in this chat. If a query was answered with a places list or a route, you can reference it briefly.'
        }
      ]
    });

    // Take last N messages to preserve context
    final start = _messages.length > _kContextWindow
        ? _messages.length - _kContextWindow
        : 0;
    final recent = _messages.sublist(start);

    for (final m in recent) {
      final sender = (m['sender'] ?? 'bot') as String;
      final type = (m['type'] ?? 'text') as String;
      String text; // concise representation for non-text cards

      if (type == 'text') {
        text = (m['text'] ?? '').toString();
      } else if (type == 'places') {
        final places =
            (m['places'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final names =
            places.take(4).map((p) => p['name'] ?? 'place').join(', ');
        text =
            'Provided nearby places list (${places.length} results). Top: $names';
      } else if (type == 'route') {
        final route = (m['route'] as Map?) ?? {};
        final origin = route['origin'] ?? 'origin';
        final dest = route['destination'] ?? 'destination';
        final distance = route['distance'] ?? 'unknown';
        final duration = route['duration'] ?? 'unknown';
        text =
            'Provided route ${origin} -> ${dest} (${distance}, ~${duration}).';
      } else {
        text = (m['text'] ?? '').toString();
      }

      contents.add({
        'role': sender == 'user' ? 'user' : 'model',
        'parts': [
          {'text': text}
        ]
      });
    }

    // Append the new user turn
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ]
    });

    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiKey');

    try {
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': contents,
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

  // 🔹 Handle user query: decide intent, call APIs, update UI
  Future<void> _handleUserQuery(String original) async {
    final lower = original.toLowerCase();
    if (_isRouteIntent(lower)) {
      final parsed = _parseRouteQuery(original);
      // If origin omitted (null) we rely on current location -> gate by tracking state
      if (parsed['origin'] == null) {
        final trackingOn = await _isTrackingEnabled();
        if (!trackingOn) {
          _appendBotText(_kEnableTrackingMsg);
          return;
        }
      }
      final routeResult = await _getRoute(
        originText: parsed['origin'],
        destinationText: parsed['destination'],
      );
      if (routeResult['error'] != null) {
        _appendBotText(routeResult['error']);
      } else {
        _appendBotRoute(routeResult);
      }
    } else if (lower.contains('weather')) {
      // Attempt to extract a city after keywords like 'in', 'of', 'at' if present.
      final city = _extractCityFromWeatherQuery(original);
      String w;
      if (city != null && city.trim().isNotEmpty) {
        w = await _getWeatherForCity(city.trim());
      } else {
        final trackingOn = await _isTrackingEnabled();
        if (!trackingOn) {
          _appendBotText(_kEnableTrackingMsg);
          return;
        }
        w = await _getWeather();
      }
      _appendBotText(w);
    } else if (_isPlacesIntent(lower)) {
      // Gate if tracking disabled
      final trackingOn = await _isTrackingEnabled();
      if (!trackingOn) {
        _appendBotText(_kEnableTrackingMsg);
        return;
      }
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
      final t = await _sendToGeminiWithHistory(original);
      _appendBotText(t);
    }
  }

  // 🔹 Route intent detection
  bool _isRouteIntent(String lower) {
    return lower.contains('how to go') ||
        lower.contains('how do i get') ||
        lower.contains('directions to') ||
        lower.contains('route to') ||
        lower.contains('navigate to') ||
        lower.contains('how to reach') ||
        RegExp(r'\bgo to [a-z]', caseSensitive: false).hasMatch(lower) ||
        RegExp(r'\bhow can i get to\b', caseSensitive: false).hasMatch(lower);
  }

  // 🔹 Places intent detection (nearby search)
  bool _isPlacesIntent(String lower) {
    // generic proximity cues
    final hasNearCue = lower.contains('near me') ||
        lower.contains('nearby') ||
        lower.contains('around me') ||
        lower.contains('closest') ||
        lower.contains('nearest');

    // category cues
    const categories = [
      'restaurant',
      'restaurants',
      'cafe',
      'coffee',
      'atm',
      'hospital',
      'clinic',
      'pharmacy',
      'chemist',
      'police',
      'police station',
      'hotel',
      'hotels',
      'gas station',
      'petrol pump',
      'fuel station',
      'bank',
      'park',
      'mall',
      'shopping',
      'museum',
      'temple',
      'church',
      'mosque',
      'train station',
      'railway station',
      'bus stop',
      'bus station',
      'airport',
      'grocery',
      'supermarket',
      'tourist',
      'attraction',
      'landmark',
    ];

    final hasCategory = categories.any((c) => lower.contains(c));

    // intent verbs
    final hasVerb = lower.contains('find') ||
        lower.contains('show me') ||
        lower.contains('show nearby') ||
        lower.contains('look for') ||
        lower.contains('search') ||
        lower.contains('where is') ||
        lower.contains('where are');

    // Heuristics: either explicit near cue + any text, or a recognized category, or verbs with likely place nouns
    return hasCategory ||
        (hasNearCue && (hasVerb || lower.split(' ').length > 2));
  }

  // 🔹 Extract a keyword for Google Places (maps common synonyms to a single term)
  String _extractKeyword(String lower) {
    // Map common phrases to a canonical keyword
    final Map<String, String> synonyms = {
      'restaurants': 'restaurant',
      'restaurant': 'restaurant',
      'food': 'restaurant',
      'dining': 'restaurant',
      'cafe': 'cafe',
      'coffee': 'cafe',
      'coffee shop': 'cafe',
      'atm': 'atm',
      'cash machine': 'atm',
      'hospital': 'hospital',
      'clinic': 'hospital',
      'pharmacy': 'pharmacy',
      'chemist': 'pharmacy',
      'police station': 'police',
      'police': 'police',
      'hotel': 'lodging',
      'hotels': 'lodging',
      'lodging': 'lodging',
      'gas station': 'gas station',
      'petrol pump': 'gas station',
      'fuel station': 'gas station',
      'bank': 'bank',
      'park': 'park',
      'mall': 'shopping mall',
      'shopping mall': 'shopping mall',
      'shopping': 'shopping mall',
      'museum': 'museum',
      'temple': 'temple',
      'church': 'church',
      'mosque': 'mosque',
      'train station': 'train station',
      'railway station': 'train station',
      'bus stop': 'bus station',
      'bus station': 'bus station',
      'airport': 'airport',
      'grocery': 'grocery store',
      'supermarket': 'supermarket',
      'tourist attraction': 'tourist attraction',
      'attraction': 'tourist attraction',
      'landmark': 'landmark',
    };

    // First, try direct phrase matches longest-first
    final keys = synonyms.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      if (lower.contains(k)) return synonyms[k]!;
    }

    // Try to capture between verbs and near-cues: "find X near me" / "show nearby X"
    final RegExp verbNear = RegExp(
        r'(?:find|show me|show|look for|search for|search)\s+(.+?)\s*(?:near me|nearby|around me)');
    final RegExp nearAfter = RegExp(r'(?:near me|nearby|around me)\s+(.+)$');
    final RegExp showNearby = RegExp(r'show\s+nearby\s+(.+)$');

    String? candidate = verbNear.firstMatch(lower)?.group(1) ??
        nearAfter.firstMatch(lower)?.group(1) ??
        showNearby.firstMatch(lower)?.group(1);

    if (candidate != null) {
      candidate = candidate.replaceAll(RegExp(r'[?!.]'), '').trim();
      // remove common fillers/modifiers
      final stop = {
        'a',
        'an',
        'the',
        'some',
        'good',
        'best',
        'cheap',
        'open',
        'now',
        'please',
        'closest',
        'nearest',
        'nearby',
        'near',
        'me',
        'around'
      };
      final tokens = candidate
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty && !stop.contains(t))
          .toList();
      if (tokens.isNotEmpty) {
        final cleaned = tokens.join(' ');
        // Map again through synonyms if possible
        for (final k in keys) {
          if (cleaned.contains(k)) return synonyms[k]!;
        }
        return cleaned;
      }
    }

    // Fallback: extract the last noun-ish word after verbs like "find" or "show"
    final RegExp verbThing =
        RegExp(r'(?:find|show me|show|look for|search for|search)\s+(.+)$');
    final m = verbThing.firstMatch(lower);
    if (m != null) {
      final tail = m.group(1)!.replaceAll(RegExp(r'[?!.]'), '').trim();
      for (final k in keys) {
        if (tail.contains(k)) return synonyms[k]!;
      }
      return tail;
    }

    // Last resort default
    return 'restaurant';
  }

  // 🔹 Parse route query to extract origin/destination
  // Supports patterns:
  //  - how to go from X to Y
  //  - directions from X to Y
  //  - how to go to Y (origin = current location)
  //  - directions to airport
  Map<String, String?> _parseRouteQuery(String original) {
    final text = original.trim();
    final fromTo = RegExp(r'from\s+(.+?)\s+to\s+(.+)', caseSensitive: false)
        .firstMatch(text);
    if (fromTo != null) {
      final origin = _cleanLocationString(fromTo.group(1));
      final dest = _cleanLocationString(fromTo.group(2));
      if (dest != null && dest.isNotEmpty) {
        return {'origin': origin, 'destination': dest};
      }
    }
    // Destination only patterns
    final toOnly = RegExp(
            r'(?:how to go to|how do i get to|directions to|route to|navigate to|how to reach|go to)\s+(.+)',
            caseSensitive: false)
        .firstMatch(text);
    if (toOnly != null) {
      final dest = _cleanLocationString(toOnly.group(1));
      if (dest != null && dest.isNotEmpty) {
        return {'origin': null, 'destination': dest};
      }
    }
    // Fallback: treat everything after 'to ' as destination
    final fallback =
        RegExp(r'to\s+(.+)', caseSensitive: false).firstMatch(text);
    if (fallback != null) {
      final dest = _cleanLocationString(fallback.group(1));
      if (dest != null) {
        return {'origin': null, 'destination': dest};
      }
    }
    return {'origin': null, 'destination': 'destination'}; // generic fallback
  }

  String? _cleanLocationString(String? raw) {
    if (raw == null) return null;
    return raw
        .replaceAll(RegExp(r'[?!.]'), '')
        .replaceAll(RegExp(r'^to\s+', caseSensitive: false), '')
        .trim();
  }

  // 🔹 Geocode address (Google Geocoding API)
  Future<Map<String, dynamic>?> _geocodeAddress(String address) async {
    if (_googleKey.isEmpty) return null;
    final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_googleKey');
    try {
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body);
      if (data['status'] != 'OK') return null;
      final results = data['results'];
      if (results is List && results.isNotEmpty) {
        final r = results[0];
        final loc = r['geometry']?['location'];
        if (loc != null && loc['lat'] != null && loc['lng'] != null) {
          return {
            'lat': (loc['lat'] as num).toDouble(),
            'lng': (loc['lng'] as num).toDouble(),
            'formatted': r['formatted_address'] ?? address,
          };
        }
      }
    } catch (_) {}
    return null;
  }

  // 🔹 Get directions (origin can be null meaning use current location). Returns map with route info.
  Future<Map<String, dynamic>> _getRoute({
    String? originText,
    required String? destinationText,
  }) async {
    if (_googleKey.isEmpty) {
      return {
        'error': 'Google API key missing for Directions (GOOGLE_API_KEY).'
      };
    }
    if (destinationText == null || destinationText.isEmpty) {
      return {'error': 'No destination specified.'};
    }

    Position? currentPos;
    if (originText == null) {
      try {
        currentPos = await _getCurrentLocation();
      } catch (e) {
        return {'error': 'Could not get current location: $e'};
      }
    }

    final destGeo = await _geocodeAddress(destinationText);
    if (destGeo == null) {
      return {'error': 'Could not locate destination: $destinationText'};
    }

    Map<String, dynamic>? originGeo;
    if (originText != null) {
      originGeo = await _geocodeAddress(originText);
      if (originGeo == null) {
        // Attempt fallback to current location
        try {
          currentPos = await _getCurrentLocation();
        } catch (_) {}
      }
    }

    final originLat =
        originGeo != null ? originGeo['lat'] : (currentPos?.latitude);
    final originLng =
        originGeo != null ? originGeo['lng'] : (currentPos?.longitude);
    if (originLat == null || originLng == null) {
      return {'error': 'Could not determine origin.'};
    }

    final mode = 'driving'; // could be enhanced based on query keywords
    final directionsUri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=$originLat,$originLng&destination=${destGeo['lat']},${destGeo['lng']}&mode=$mode&key=$_googleKey');
    try {
      final resp = await http.get(directionsUri);
      if (resp.statusCode != 200) {
        return {'error': 'Directions HTTP ${resp.statusCode}'};
      }
      final data = jsonDecode(resp.body);
      if (data['status'] != 'OK') {
        return {'error': 'Directions API: ${data['status']}'};
      }
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) {
        return {'error': 'No route found.'};
      }
      final first = routes[0];
      final legs = first['legs'];
      if (legs is! List || legs.isEmpty) {
        return {'error': 'No route legs.'};
      }
      final leg = legs[0];
      final distance = leg['distance']?['text'] ?? 'unknown';
      final duration = leg['duration']?['text'] ?? 'unknown';
      final steps = (leg['steps'] as List?) ?? [];
      final parsedSteps = steps.map((s) {
        final html = s['html_instructions'] ?? '';
        final plain = _stripHtml(html);
        final stepDist = s['distance']?['text'] ?? '';
        return {'instruction': plain, 'distance': stepDist};
      }).toList();
      return {
        'type': 'route',
        'origin': originGeo != null
            ? originGeo['formatted']
            : (currentPos != null
                ? 'Current location (${originLat.toStringAsFixed(4)}, ${originLng.toStringAsFixed(4)})'
                : 'Origin'),
        'destination': destGeo['formatted'],
        'distance': distance,
        'duration': duration,
        'mode': mode,
        'steps': parsedSteps,
        'originLat': originLat,
        'originLng': originLng,
        'destLat': destGeo['lat'],
        'destLng': destGeo['lng'],
        'narrative': _generateRouteNarrative(
          originLabel: originGeo != null
              ? originGeo['formatted']
              : (currentPos != null ? 'your current location' : 'origin'),
          destinationLabel: destGeo['formatted'],
          distance: distance,
          duration: duration,
          steps: parsedSteps,
        ),
      };
    } catch (e) {
      return {'error': 'Directions error: $e'};
    }
  }

  String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _appendBotRoute(Map<String, dynamic> route) {
    setState(() {
      _messages.add({
        'sender': 'bot',
        'type': 'route',
        'route': route,
        'expanded': false
      });
      _isLoading = false;
    });
    _scrollToBottomDeferred();
    if (_ttsEnabled) {
      final narrative = (route['narrative'] as String?)?.trim();
      final origin = route['origin'] ?? 'origin';
      final dest = route['destination'] ?? 'destination';
      final distance = route['distance'] ?? 'unknown';
      final duration = route['duration'] ?? 'unknown';
      final fallback =
          'Route from $origin to $dest. Distance $distance, about $duration.';
      _tts.speak(
          (narrative != null && narrative.isNotEmpty) ? narrative : fallback);
    }
  }

  // 🔹 Generate a human-friendly narrative combining step data + heuristic transport hints
  String _generateRouteNarrative({
    required String originLabel,
    required String destinationLabel,
    required String distance,
    required String duration,
    required List steps,
  }) {
    final distKm = _parseDistanceKm(distance);
    final modeSuggestion = _suggestMode(distKm, destinationLabel.toLowerCase());
    final minutes = _parseDurationMinutes(duration);
    final primaryRoad = _extractPrimaryRoad(steps);
    final openers = [
      'You\'re heading',
      'Journey summary:',
      'Route snapshot:',
      'Trip plan:'
    ];
    final verbs = ['Head', 'Proceed', 'Continue', 'Move'];
    final connectors = ['then', 'after that', 'next', 'followed by'];

    final opener = _selectFrom(openers);
    final verb = _selectFrom(verbs);
    final connector = _selectFrom(connectors);

    final buffer = StringBuffer();
    buffer.writeln(
        '$opener: $distance (~$duration) from $originLabel to $destinationLabel.');
    buffer.writeln('Suggested mode: $modeSuggestion');
    if (primaryRoad != null) {
      buffer.writeln('Main stretch involves $primaryRoad.');
    }
    if (minutes != null && minutes > 0) {
      if (minutes < 8) {
        buffer.writeln('A very short trip — expect minimal turns.');
      } else if (minutes > 45) {
        buffer.writeln('Longer duration: consider traffic conditions.');
      }
    }

    if (steps.isNotEmpty) {
      buffer.writeln('Approximate sequence:');
      for (var i = 0; i < steps.length && i < 4; i++) {
        final s = steps[i];
        final instr = _simplifyInstruction(s['instruction'] ?? '');
        final seg = s['distance'] ?? '';
        final prefix = i == 0 ? verb : connector;
        buffer.writeln('- $prefix $instr ($seg)');
      }
      if (steps.length > 4) {
        buffer.writeln(
            '...then continue with remaining ${steps.length - 4} steps to arrive.');
      }
    }
    buffer.writeln('Open map for live navigation & real-time adjustments.');
    return buffer.toString().trim();
  }

  int? _parseDurationMinutes(String durationText) {
    // Handles patterns like '42 mins', '1 hour 5 mins', '3 min'
    final lower = durationText.toLowerCase();
    try {
      int total = 0;
      final hourMatch = RegExp(r'(\d+)\s*hour').firstMatch(lower);
      if (hourMatch != null) {
        total += int.parse(hourMatch.group(1)!) * 60;
      }
      final minMatch = RegExp(r'(\d+)\s*min').firstMatch(lower);
      if (minMatch != null) {
        total += int.parse(minMatch.group(1)!);
      }
      return total == 0 ? null : total;
    } catch (_) {
      return null;
    }
  }

  String? _extractPrimaryRoad(List steps) {
    // Attempt to find the first major road/highway name
    for (final s in steps) {
      final instr = (s['instruction'] ?? '') as String;
      final m = RegExp(r'onto ([A-Z0-9 /-]{3,})').firstMatch(instr);
      if (m != null) {
        final candidate = m.group(1)!.trim();
        if (candidate.length > 2) return candidate;
      }
    }
    return null;
  }

  String _selectFrom(List<String> options) {
    // Basic variability using current time milliseconds to avoid deterministic repetition per session
    final ms = DateTime.now().millisecondsSinceEpoch;
    return options[ms % options.length];
  }

  double _parseDistanceKm(String distanceText) {
    // Handles patterns like '5.4 km' or '850 m'
    final lower = distanceText.toLowerCase();
    try {
      if (lower.contains('km')) {
        final numStr = lower.split('km')[0].trim();
        return double.parse(numStr.replaceAll(',', ''));
      } else if (lower.contains('m')) {
        final numStr = lower.split('m')[0].trim();
        final meters = double.parse(numStr.replaceAll(',', ''));
        return meters / 1000.0;
      }
    } catch (_) {}
    return 0.0;
  }

  String _suggestMode(double distanceKm, String destLower) {
    // Heuristic suggestions: extendable
    if (distanceKm < 0.9) return 'Walk directly; distance is under 1 km.';
    if (distanceKm < 3.5) return 'Walk or take a short auto/tuk-tuk if tired.';
    if (distanceKm < 8) {
      return 'Auto-rickshaw / taxi is efficient for this mid-range distance.';
    }
    if (destLower.contains('airport')) {
      return 'Book a taxi or app cab for comfort (consider traffic).';
    }
    if (destLower.contains('station')) {
      return 'Use a taxi/auto; if available, consider a local bus or metro line nearby.';
    }
    if (distanceKm < 15) {
      return 'Taxi or ride-share recommended; bus possible if you know the route.';
    }
    return 'Use a taxi/ride-share. For long distances consider intercity bus or rail if applicable.';
  }

  String _simplifyInstruction(String instr) {
    // Remove advisory phrases to keep concise
    var cleaned = instr
        .replaceAll(RegExp(r'head '), 'Go ')
        .replaceAll(RegExp(r'continue straight'), 'continue')
        .replaceAll(RegExp(r'slight right', caseSensitive: false), 'bear right')
        .replaceAll(RegExp(r'slight left', caseSensitive: false), 'bear left');
    return cleaned;
  }

  // 🔹 Extract city name from phrases like:
  //   weather in Kolkata
  //   what's the weather of New York
  //   give me weather at los angeles
  // Returns null if no city pattern detected.
  String? _extractCityFromWeatherQuery(String original) {
    final pattern = RegExp(r'weather\s+(?:in|of|at)\s+([a-zA-Z .,-]+)',
        caseSensitive: false);
    final match = pattern.firstMatch(original);
    if (match != null) {
      final city = match.group(1)?.trim();
      // Heuristic: ignore if city word collides with generic words
      if (city != null && city.isNotEmpty && city.length > 2) {
        return city.replaceAll(RegExp(r'[?!.]'), '').trim();
      }
    }
    // Another fallback: "give the weather of Kolkata" / "weather kolkata"
    final loose = RegExp(r'weather\s+([a-zA-Z .,-]+)', caseSensitive: false)
        .firstMatch(original);
    if (loose != null) {
      final city = loose.group(1)?.trim();
      if (city != null &&
          city.isNotEmpty &&
          !city.toLowerCase().startsWith('in ')) {
        // remove leading filler words
        return city
            .replaceFirst(RegExp(r'^(in|of|at)\s+', caseSensitive: false), '')
            .replaceAll(RegExp(r'[?!.]'), '')
            .trim();
      }
    }
    return null;
  }

  void _appendBotText(String text) {
    setState(() {
      _messages.add({'sender': 'bot', 'type': 'text', 'text': text});
      _isLoading = false;
    });
    _scrollToBottomDeferred();
    if (_ttsEnabled) {
      _tts.speak(text);
    }
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
    if (_ttsEnabled) {
      final count = places.length;
      final topNames = places
          .take(3)
          .map((p) => (p['name'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();
      final summaryNames = topNames.join(', ');
      final baseIntro = intro.replaceAll('(tap to open in Maps):', '').trim();
      final summary = count > 0
          ? (summaryNames.isNotEmpty
              ? '$baseIntro — Top ${topNames.length}: $summaryNames.'
              : baseIntro)
          : '$baseIntro (no results).';
      _tts.speak(summary);
    }
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
  void dispose() {
    ChatSessionService.instance.setOpen(false);
    _sessionSub?.cancel();
    _vasEventSub?.cancel();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chatbot"),
        actions: [
          IconButton(
            tooltip: _ttsEnabled
                ? 'Voice: On (tap to mute)'
                : 'Voice: Off (tap to enable)',
            icon: Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: () async {
              setState(() => _ttsEnabled = !_ttsEnabled);
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(_kTtsEnabledPrefKey, _ttsEnabled);
              } catch (_) {}
              if (!_ttsEnabled) {
                await _tts.stop();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
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
                    } else if (type == 'route') {
                      bubbleChild = _buildRouteBubble(msg['route']);
                    } else {
                      bubbleChild = SelectableText(
                        msg['text'] ?? '',
                        style: TextStyle(
                          color: isUser ? scheme.onPrimary : scheme.onSurface,
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
                            color: isUser
                                ? scheme.primary
                                : scheme.surfaceVariant,
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
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Mic button: activate push-to-talk (no wake word)
                    IconButton(
                      icon: const Icon(Icons.mic),
                      tooltip: 'Speak your query',
                      onPressed: (_isLoading || _activeListening)
                          ? null
                          : () async {
                              // Request mic permission if needed
                              final status =
                                  await Permission.microphone.request();
                              if (!status.isGranted) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Microphone permission denied')),
                                );
                                return;
                              }
                              // Subscribe to voice events for this active session
                              _vasEventSub?.cancel();
                              _gotFinalThisSession = false;
                              final int sessionId = ++_pttSessionCounter;
                              _vasEventSub = _vas.events.listen((evt) async {
                                // Ignore events not belonging to the current session
                                if (sessionId != _pttSessionCounter) return;
                                switch (evt.type) {
                                  case VoiceAssistantEventType.sttListening:
                                    if (!mounted) return;
                                    setState(() {
                                      _activeListening = true;
                                      _partialTranscript = '';
                                    });
                                    break;
                                  case VoiceAssistantEventType.partialResult:
                                    if (!mounted) return;
                                    setState(() {
                                      _partialTranscript = evt.data ?? '';
                                    });
                                    break;
                                  case VoiceAssistantEventType.finalResult:
                                    {
                                      final text = (evt.data ?? '').trim();
                                      _gotFinalThisSession = true;
                                      if (!mounted) return;
                                      setState(() {
                                        _activeListening = false;
                                        _partialTranscript = '';
                                        if (text.isNotEmpty) {
                                          _messages.add(
                                              {'sender': 'user', 'text': text});
                                          _isLoading = true;
                                        }
                                      });
                                      _vasEventSub?.cancel();
                                      // Invalidate this session so any trailing events are ignored
                                      _pttSessionCounter++;
                                      if (text.isNotEmpty) {
                                        _scrollToBottomDeferred();
                                        await _handleUserQuery(text);
                                      } 
                                    }
                                    break;
                                  case VoiceAssistantEventType.error:
                                    if (!mounted) return;
                                    setState(() {
                                      _activeListening = false;
                                      _partialTranscript = '';
                                    });
                                    _vasEventSub?.cancel();
                                    _pttSessionCounter++; // end session
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Speech error: ${evt.data ?? 'unknown'}')),
                                    );
                                    break;
                                  case VoiceAssistantEventType.resumedWake:
                                    // STT session ended; show 'didn't catch' only
                                    // if a final result was NOT received. Delay slightly
                                    // to avoid race with finalResult handler.
                                    if (!mounted) return;
                                    if (_activeListening) {
                                      setState(() {
                                        _activeListening = false;
                                        _partialTranscript = '';
                                      });
                                    }
                                    _vasEventSub?.cancel();
                                    Future.delayed(
                                        const Duration(milliseconds: 80), () {
                                      // If another session started, ignore
                                      if (sessionId != _pttSessionCounter)
                                        return;
                                      if (!mounted) return;
                                      
                                    });
                                    break;
                                  default:
                                    break;
                                }
                              });
                              await _vas.startActiveListening(
                                  pauseFor: const Duration(seconds: 5));
                            },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _isLoading ? null : _sendMessage,
                      color: _isLoading ? scheme.outline : scheme.primary,
                      tooltip: _isLoading ? 'Waiting for response...' : 'Send',
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_activeListening) _buildListeningOverlay(context),
        ],
      ),
    );
  }

  Widget _buildListeningOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.mic, size: 40, color: Colors.redAccent),
              const SizedBox(height: 8),
              const Text('Listening…',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (_partialTranscript.isNotEmpty)
                Text(
                  _partialTranscript,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87),
                )
              else
                const Text('Speak now',
                    style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      _vas.stopListening();
                      if (!mounted) return;
                      setState(() {
                        _activeListening = false;
                        _partialTranscript = '';
                      });
                      _vasEventSub?.cancel();
                    },
                    icon: const Icon(Icons.stop, color: Colors.redAccent),
                    label: const Text('Stop'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlacesBubble(Map<String, dynamic> msg) {
    final scheme = Theme.of(context).colorScheme;
    final List places = msg['places'] ?? [];
    final intro = msg['text'] ?? 'Nearby places:';
    if (places.isEmpty) {
      return Text('$intro\n(No results)');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(intro,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: scheme.onSurface)),
        const SizedBox(height: 8),
        ...places.map((p) {
          final name = p['name'] ?? 'Unknown';
          final vicinity = p['vicinity'] ?? '';
          final lat = p['lat'];
          final lng = p['lng'];
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              title: Text(name,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: scheme.onSurface)),
              subtitle: Text(vicinity,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant)),
              trailing: IconButton(
                icon: Icon(Icons.map, color: scheme.primary),
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

  Widget _buildRouteBubble(Map<String, dynamic>? routeMap) {
    final scheme = Theme.of(context).colorScheme;
    if (routeMap == null) return const Text('No route data.');
    final origin = routeMap['origin'] ?? 'Origin';
    final dest = routeMap['destination'] ?? 'Destination';
    final distance = routeMap['distance'] ?? 'unknown';
    final duration = routeMap['duration'] ?? 'unknown';
    final steps = (routeMap['steps'] as List?) ?? [];
    final originLat = routeMap['originLat'];
    final originLng = routeMap['originLng'];
    final destLat = routeMap['destLat'];
    final destLng = routeMap['destLng'];
    final narrative = routeMap['narrative'] as String?;
    // Find corresponding message entry to read/update expansion state
    bool expanded = false;
    // Not performance critical for small list
    final msgIndex = _messages.indexWhere((m) => m['route'] == routeMap);
    if (msgIndex != -1) {
      expanded = _messages[msgIndex]['expanded'] == true;
    }
    const previewCount = 8;
    final showingSteps = expanded ? steps : steps.take(previewCount).toList();
    final remaining = steps.length - showingSteps.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Route: $origin → $dest',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: scheme.onSurface)),
        const SizedBox(height: 4),
        Text('Distance: $distance  •  Duration: $duration',
            style: TextStyle(color: scheme.onSurfaceVariant)),
        if (narrative != null) ...[
          const SizedBox(height: 8),
          Text(narrative,
              style: TextStyle(fontSize: 13, color: scheme.onSurface)),
        ],
        const SizedBox(height: 10),
        if (steps.isNotEmpty)
          Text('Turn-by-turn (${steps.length} steps):',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: scheme.onSurface)),
        ...showingSteps.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final s = entry.value;
          final instr = s['instruction'] ?? '';
          final sd = s['distance'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${expanded ? idx : idx}. $instr (${sd ?? ''})',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          );
        }),
        if (!expanded && remaining > 0)
          TextButton(
            onPressed: () {
              if (msgIndex != -1) {
                setState(() {
                  _messages[msgIndex]['expanded'] = true;
                });
              }
            },
            child: Text('Show more (+$remaining)',
                style: TextStyle(color: scheme.primary)),
          ),
        if (expanded && remaining > 0)
          TextButton(
            onPressed: () {
              if (msgIndex != -1) {
                setState(() {
                  _messages[msgIndex]['expanded'] = false;
                });
              }
            },
            child:
                Text('Show less', style: TextStyle(color: scheme.primary)),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: (originLat == null ||
                    originLng == null ||
                    destLat == null ||
                    destLng == null)
                ? null
                : () {
                    final url = Uri.parse(
                        'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$destLat,$destLng&travelmode=driving');
                    launchUrl(url, mode: LaunchMode.externalApplication);
                  },
            icon: const Icon(Icons.directions),
            label: const Text('Open in Google Maps'),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          ),
        )
      ],
    );
  }
}
