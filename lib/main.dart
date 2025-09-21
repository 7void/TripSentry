import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'providers/blockchain_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'firebase_options.dart';
import 'screens/tourist_id_registration_screen.dart';
import 'screens/tourist_id_details_screen.dart';
import 'screens/error_screen.dart';
import 'screens/geo_fencing_screen.dart';
import 'screens/test_map_screen.dart';
import 'screens/chat_screen.dart'; // ✅ chatbot screen import
import 'screens/emergency_countdown_screen.dart';
import 'services/location_service.dart';
import 'services/voice_assistant_service.dart';
import 'services/chat_session_service.dart';
import 'services/geofence_background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  LocationService().init();
  await GeofenceBackgroundService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final VoiceAssistantService _voiceAssistantService = VoiceAssistantService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  OverlayEntry? _listeningOverlay;

  void _showListeningOverlay() {
    // If already visible, just return
    if (_listeningOverlay != null) return;
    final overlayState = _navigatorKey.currentState?.overlay;
    if (overlayState == null) return;
    _listeningOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        right: 0,
        top: 60,
        child: IgnorePointer(
          ignoring: true,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.mic, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Listening…', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlayState.insert(_listeningOverlay!);
  }

  void _hideListeningOverlay() {
    _listeningOverlay?.remove();
    _listeningOverlay = null;
  }

  Future<void> requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      // ignore: avoid_print
      print("Microphone permission granted");
      await _voiceAssistantService.initWakeWord();
    } else {
      // ignore: avoid_print
      print("Microphone permission denied");
    }
  }

  @override
  void initState() {
    super.initState();
    _voiceAssistantService.events.listen((e) {
      // ignore: avoid_print
      print(
          '[VoiceAssistant] ${e.type} ${e.data != null ? '- ' + e.data! : ''}');
      // Minimal listening overlay lifecycle
      switch (e.type) {
        case VoiceAssistantEventType.sttListening:
          _showListeningOverlay();
          break;
        case VoiceAssistantEventType.finalResult:
        case VoiceAssistantEventType.error:
        case VoiceAssistantEventType.resumedWake:
        case VoiceAssistantEventType.wakeListening:
          _hideListeningOverlay();
          break;
        default:
          break;
      }

      if (e.type == VoiceAssistantEventType.finalResult) {
        final text = e.data?.trim();
        if (text == null || text.isEmpty) return;
        final session = ChatSessionService.instance;
        // If chat is already open, just send the message into it
        if (session.isChatOpen) {
          session.sendVoiceMessage(text);
          return;
        }
        // Otherwise, buffer and open the chat once
        session.sendVoiceMessage(text);
        if (!session.isOpening) {
          session.setOpening(true);
          final ctx = _navigatorKey.currentState?.overlay?.context;
          if (ctx != null) {
            Navigator.of(ctx)
                .push(MaterialPageRoute(builder: (_) => const ChatScreen()))
                .whenComplete(() => session.setOpening(false));
          } else {
            session.setOpening(false);
          }
        }
      }
    });
    requestMicPermission();
  }

  @override
  void dispose() {
    _hideListeningOverlay();
    _voiceAssistantService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => BlockchainProvider())],
      child: MaterialApp(
        title: 'Tourist Safety App',
        navigatorKey: _navigatorKey,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue, brightness: Brightness.light),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.black),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
        builder: (context, child) => child ?? const SizedBox.shrink(),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/tourist-id-registration': (context) =>
              const TouristIDRegistrationScreen(),
          '/tourist-id-details': (context) => const TouristIDDetailsScreen(),
          '/error': (context) => const ErrorScreen(),
          '/geo-fencing': (context) => const GeoFencingScreen(),
          '/test-map': (context) => const TestMapScreen(),
          '/chat': (context) => const ChatScreen(),
          '/emergency': (context) => const EmergencyCountdownScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
