import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';

import 'firebase_options.dart';
import 'pages/role_selection_page.dart';
import 'pages/qr_elderly.dart';
import 'pages/caregiver_scanpage.dart';
import 'pages/login_screen.dart';
import 'pages/home_screen.dart';

// ── Dev SSL override ──────────────────────────────────────────────────────────
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  HttpOverrides.global = MyHttpOverrides();
  runApp(const CareConnectApp());
}

class CareConnectApp extends StatelessWidget {
  const CareConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Find my Ah Ma',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans-serif',
        colorSchemeSeed: const Color(0xFF4A90D9),
      ),

      initialRoute: '/',

      // ── Named routes ────────────────────────────────────────────────────────
      routes: {
        // 1. Role selection
        '/': (context) => const RoleSelectionPage(),

        // 2a. Elderly: display QR and wait
        '/elderly': (context) => const ElderlyQRPage(),

        // 2b. Caregiver: scan the QR
        '/caregiver': (context) => const CaregiverScanPage(),

        // 3. Caregiver: login / sign-up (sessionId passed via arguments)
        '/login': (context) => const LoginScreen(),

        // 4. Both land here after successful pairing
        '/home': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ?? {};
          return HomeScreen(isCaregiver: args['isCaregiver'] as bool? ?? false);
        },
      },
    );
  }
}