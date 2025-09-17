import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
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
import 'services/location_service.dart';
import 'services/geofence_background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (.env) before using any keys
  // Expects a .env file at project root; adjust fileName if different.
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // Fail silently: app can still run with defaults; consider logging in debug
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  LocationService().init();
  await GeofenceBackgroundService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BlockchainProvider()),
      ],
      child: MaterialApp(
        title: 'Tourist Safety App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.black,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
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
          '/chat': (context) => const ChatScreen(), // ✅ chatbot route
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
