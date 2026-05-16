import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CaregiverScanPage extends StatefulWidget {
  const CaregiverScanPage({super.key});

  @override
  State<CaregiverScanPage> createState() => _CaregiverScanPageState();
}

class _CaregiverScanPageState extends State<CaregiverScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false; // prevent firing multiple times

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.first;
    final raw = barcode.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _scanned = true);
    _controller.stop();

    // raw = sessionId written by the elderly's QR page
    Navigator.pushReplacementNamed(
      context,
      '/login',
      arguments: {'sessionId': raw},
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          // Torch toggle
          IconButton(
            icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Live camera feed ───────────────────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // ── Scanning frame overlay ─────────────────────────────────────────
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2ECC8A), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // ── Bottom hint ────────────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 60),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Point camera at the elderly\'s screen',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),

          // ── Processing overlay after scan ──────────────────────────────────
          if (_scanned)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2ECC8A)),
                    SizedBox(height: 16),
                    Text(
                      'QR Detected! Loading...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}