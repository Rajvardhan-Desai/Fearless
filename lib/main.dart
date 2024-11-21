import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fearless/screens/home_screen.dart';
import 'package:fearless/screens/signup_screen.dart';
import 'package:fearless/screens/signin_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

// Create a global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  if (dotenv.env['GOOGLE_MAPS_API_KEY'] == null) {
    throw Exception('GOOGLE_MAPS_API_KEY is not set in .env file');
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends ConsumerState<MyApp> {
  static const MethodChannel _sharingChannel = MethodChannel('com.fearless.app/sharing');

  @override
  void initState() {
    super.initState();

    // Set up the method call handler
    _sharingChannel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'emergencySharingTriggered') {
      // Handle the emergency sharing action
      // Since we might not have a BuildContext, use navigatorKey
      _triggerEmergencySharing();
    }
  }

  void _triggerEmergencySharing() {
    // Use the navigator key to navigate
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => const HomeScreen(
          initialIndex: 0, // Ensure we navigate to the Home tab
          triggerEmergencySharing: true, // Pass a flag to trigger sharing
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Fearless',
      navigatorKey: navigatorKey, // Set the navigator key
      theme: ThemeData(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme,
        ),
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: authState.when(
        data: (user) {
          if (user == null) {
            return const SignInScreen();
          } else {
            return const HomeScreen(triggerEmergencySharing: true,);
          }
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stackTrace) => Scaffold(
          body: Center(
            child: Text('Error: $error'),
          ),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('en', 'GB'),
      ],
      routes: {
        'SignInScreen': (context) => const SignInScreen(),
        'HomeScreen': (context) => const HomeScreen(triggerEmergencySharing: false),
        'SignUpScreen': (context) => const SignUpScreen(),
      },
    );
  }
}
