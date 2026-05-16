import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ElderlyQRPage extends StatefulWidget {
  const ElderlyQRPage({super.key});

  @override
  State<ElderlyQRPage> createState() => _ElderlyQRPageState();
}

class _ElderlyQRPageState extends State<ElderlyQRPage> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String? _sessionId;
  bool _loading = true;
  StreamSubscription<DatabaseEvent>? _sessionSub;

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    // Clean up the session node if the elderly leaves before pairing
    if (_sessionId != null) {
      _db.child('sessions/$_sessionId').remove();
    }
    super.dispose();
  }

  Future<void> _createSession() async {
    // Push a new session node — Firebase generates a unique key
    final sessionRef = _db.child('sessions').push();
    _sessionId = sessionRef.key;

    await sessionRef.set({
      'status': 'waiting',        // caregiver will change this to 'connected'
      'createdAt': ServerValue.timestamp,
    });

    if (!mounted) return;
    setState(() => _loading = false);

    // ── Listen for caregiver login completion ─────────────────────────────────
    _sessionSub = sessionRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final status = data['status'] as String?;

      if (status == 'connected' && mounted) {
        _sessionSub?.cancel();
        // Both sides go home — elderly side is NOT a caregiver
        Navigator.pushReplacementNamed(
          context,
          '/home',
          arguments: {
            'isCaregiver': false,
            'sessionId': _sessionId,
            'caregiverEmail': data['caregiverEmail'] ?? '',
          },
        );
      }
    });
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
          onPressed: () {
            _sessionSub?.cancel();
            if (_sessionId != null) {
              _db.child('sessions/$_sessionId').remove();
            }
            Navigator.pop(context);
          },
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

              // ── QR Code or loader ──────────────────────────────────────────
              _loading || _sessionId == null
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
                      // The QR encodes the session ID so the caregiver's
                      // scanner knows which Firebase node to update
                      child: QrImageView(
                        data: _sessionId!,
                        version: QrVersions.auto,
                        size: 220,
                      ),
                    ),

              const SizedBox(height: 32),

              // ── Waiting indicator ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFAAAAAA),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Waiting for caregiver to scan...',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ],
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}