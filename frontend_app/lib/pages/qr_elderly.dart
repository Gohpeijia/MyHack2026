import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Future database import
import 'package:qr_flutter/qr_flutter.dart';

class ElderlyQRPage extends StatefulWidget {
  const ElderlyQRPage({super.key});

  @override
  State<ElderlyQRPage> createState() => _ElderlyQRPageState();
}

class _ElderlyQRPageState extends State<ElderlyQRPage> {
  // // Future Firebase setup variable:
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _token;
  bool _loading = true;
  Timer? _mockConnectionTimer;

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  @override
  void dispose() {
    _mockConnectionTimer?.cancel();
    super.dispose();
  }

  Future<void> _createSession() async {
    // Simulate network delay for creating a session token
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      setState(() {
        // Generates a mock session ID using the current timestamp
        _token = 'mock-session-${DateTime.now().millisecondsSinceEpoch}';
        _loading = false;
      });

      // --- FIREBASE IMPLEMENTATION WILL REPLACE THIS BLOCK ---
      // Real flow: Listen to document changes in Firestore collection:
      // _firestore.collection('connections').doc(_token).snapshots().listen((snapshot) {
      //   if (snapshot.exists && snapshot.data()?['status'] == 'connected') {
      //     Navigator.pushReplacementNamed(context, '/elderly_home');
      //   }
      // });
      // ------------------------------------------------------

      // Local UI Test Simulation: Auto-advances to home after 8 seconds 
      // so you can see what happens when a caregiver finishes scanning!
      _mockConnectionTimer = Timer(const Duration(seconds: 8), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/elderly_home');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Text(
                'Your QR Code',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ask your caregiver to scan this',
                style: TextStyle(fontSize: 15, color: Color(0xFF6B6B80)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _loading
                  ? const CircularProgressIndicator(color: Color(0xFF4A90D9))
                  : Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: _token!,
                        version: QrVersions.auto,
                        size: 220,
                      ),
                    ),
              const SizedBox(height: 32),
              const Text(
                'Waiting for caregiver to scan...',
                style: TextStyle(fontSize: 14, color: Color(0xFFAAAAAA)),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}