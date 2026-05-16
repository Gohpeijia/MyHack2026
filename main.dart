
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 
import 'register_elder_screen.dart'; // This links your main file to your UI file

void main() async {
  // This line is the "handshake" between Flutter and your Mac/Phone
  WidgetsFlutterBinding.ensureInitialized();
  
  // This line wakes up your Firebase project (myhack-55a43)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elderly Care App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      // THIS IS THE KEY: We are telling the app to show your 
      // Registration Screen instead of the counter button.
      home: const RegisterElderScreen(), 
    );
  }
}