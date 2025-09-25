import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'providers/blockchain_provider.dart';
import 'providers/locale_provider.dart';
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
import 'screens/group_list_screen.dart';
import 'screens/group_chat_screen.dart';
import 'services/location_service.dart';
import 'services/voice_assistant_service.dart';
import 'services/chat_session_service.dart';
import 'services/geofence_background_service.dart';
import 'services/group_alert_listener.dart';
import 'l10n/app_localizations.dart';
import 'services/risk_score_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  LocationService().init();
  // Start risk scoring ticker regardless of auth state, so safe-zone recovery runs.
  await RiskScoreService.instance.init();
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
  StreamSubscription<User?>? _authSub;

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

  bool _isEmergencyText(String text) {
    final t = text.toLowerCase();
    const phrases = [
      'i am in danger',
      'i need help',
      'help me',
      'emergency',
      'call for help',
      'help',
      'sos',
      'danger',
      'attack',
      'threatened',
      'scared',
      'unsafe',
    ];
    return phrases.any((p) => t.contains(p));
  }

  bool _isCallEmergencyText(String text) {
    final t = text.toLowerCase();
    // Explicit call intents
    final hasCallWord =
        t.contains('call') || t.contains('dial') || t.contains('phone');
    final mentionsEmergency =
        t.contains('emergency') || t.contains('police') || t.contains('help');
    // Specific phrases users may say
    if (t.contains('call emergency number') ||
        t.contains('call emergency contact') ||
        t.contains('emergency call')) {
      return true;
    }
    // "it is emergency" as a direct trigger to call (per request)
    if (t.contains('it is emergency')) return true;
    // General heuristic: call/dial + emergency/help intent
    return hasCallWord && mentionsEmergency;
  }

  Future<void> _callEmergencyContact() async {
    final ctx = _navigatorKey.currentState?.overlay?.context;
    if (ctx == null) return;
    try {
      // Resolve number from metadata
      final number = await _getEmergencyNumber(ctx);
      if (number == null || number.isEmpty) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('No emergency contact number found')),
        );
        return;
      }
      final sanitized = number.replaceAll(RegExp(r'[^+0-9]'), '');
      if (sanitized.isEmpty) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Invalid emergency contact number')),
        );
        return;
      }
      // Try direct call on Android with runtime permission; fallback to dialer otherwise (or on iOS)
      final isAndroid = Theme.of(ctx).platform == TargetPlatform.android;
      if (isAndroid) {
        // Request phone permission at runtime
        final phonePerm = await Permission.phone.request();
        if (phonePerm.isGranted) {
          final success = await FlutterPhoneDirectCaller.callNumber(sanitized);
          if (success == true) return; // Call started
          // If plugin couldn't start call, fallback to dialer
        }
      }
      final uri = Uri(scheme: 'tel', path: sanitized);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
              content: Text('Unable to initiate call on this device')),
        );
      }
    } catch (e) {
      final ctx2 = _navigatorKey.currentState?.overlay?.context;
      if (ctx2 != null) {
        ScaffoldMessenger.of(ctx2).showSnackBar(
          SnackBar(content: Text('Failed to start call: $e')),
        );
      }
    }
  }

  Future<String?> _getEmergencyNumber(BuildContext context) async {
    // 1) Try Firestore first: collection 'users' / doc <uid> / field 'emergencyContactNumber'
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // ignore: avoid_print
        print('[EmergencyCall] currentUser.uid=${user.uid}');
        // Primary expected path per UserService: users/{uid}
        final usersDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (usersDoc.exists) {
          final data = usersDoc.data();
          final raw = data?['emergencyContactNumber'];
          if (raw is String && raw.trim().isNotEmpty) {
            // ignore: avoid_print
            print(
                '[EmergencyCall] Using Firestore users/{uid}.emergencyContactNumber');
            return raw.trim();
          }
          // ignore: avoid_print
          print(
              '[EmergencyCall] users/{uid} missing emergencyContactNumber or empty');
        } else {
          // ignore: avoid_print
          print('[EmergencyCall] users/{uid} doc does not exist');
        }
        // Optional fallback in case the collection name was misspelled elsewhere ('usesrs')
        final typoDoc = await FirebaseFirestore.instance
            .collection('usesrs')
            .doc(user.uid)
            .get();
        if (typoDoc.exists) {
          final data = typoDoc.data();
          final raw = data?['emergencyContactNumber'];
          if (raw is String && raw.trim().isNotEmpty) {
            // ignore: avoid_print
            print(
                '[EmergencyCall] Using Firestore usesrs/{uid}.emergencyContactNumber');
            return raw.trim();
          }
          // ignore: avoid_print
          print(
              '[EmergencyCall] usesrs/{uid} missing emergencyContactNumber or empty');
        } else {
          // ignore: avoid_print
          print('[EmergencyCall] usesrs/{uid} doc does not exist');
        }
      } else {
        // ignore: avoid_print
        print('[EmergencyCall] No signed-in user; falling back to metadata');
      }
    } catch (_) {
      // Fall through to metadata
    }

    // 2) Fallback to on-chain metadata via provider (emergencyPhone -> phoneNumber)
    try {
      final provider = Provider.of<BlockchainProvider>(context, listen: false);
      // Try retrieving metadata (from IPFS via provider)
      final metadata = await provider.getMetadataFromIPFS();
      if (metadata != null) {
        // Prefer emergencyPhone, fall back to phoneNumber
        if (metadata.emergencyPhone.trim().isNotEmpty) {
          return metadata.emergencyPhone.trim();
        }
        if (metadata.phoneNumber.trim().isNotEmpty) {
          return metadata.phoneNumber.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Start/stop group alert listener when auth state changes
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      try {
        if (user != null) {
          await GroupAlertListener.instance.start();
        } else {
          await GroupAlertListener.instance.stop();
        }
      } catch (_) {}
    });
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
        // First, check for a call-intent to emergency contact AFTER wake word
        if (_isCallEmergencyText(text)) {
          _callEmergencyContact();
          return;
        }
        // Next, check for emergency intent to open SOS
        if (_isEmergencyText(text)) {
          final ctx = _navigatorKey.currentState?.overlay?.context;
          if (ctx != null) {
            Navigator.of(ctx).pushNamed('/emergency');
          }
          return; // do not route to chat
        }
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
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BlockchainProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, lp, _) => MaterialApp(
        title: 'Tourist Safety App',
        navigatorKey: _navigatorKey,
        locale: lp.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
          '/groups': (context) => const GroupListScreen(),
          '/groupChat': (context) {
            final id = ModalRoute.of(context)?.settings.arguments as String?;
            return GroupChatScreen(groupId: id ?? '');
          },
        },
        debugShowCheckedModeBanner: false,
      )),
    );
  }
}
