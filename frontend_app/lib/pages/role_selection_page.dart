import 'package:flutter/material.dart';
// Update this import to match your actual project structure
import '../widget/role_card.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // ── Logo / brand ────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90D9).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFF4A90D9),
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Find my Ah Ma',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Who are you?',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF6B6B80),
                  fontWeight: FontWeight.w400,
                ),
              ),

              const Spacer(),

              // ── Elderly card ────────────────────────────────────────────────
              RoleCard(
                icon: Icons.elderly,
                label: 'I am the Elderly',
                subtitle: 'Show my QR code to connect',
                color: const Color(0xFF4A90D9),
                onTap: () => Navigator.pushNamed(context, '/elderly'),
              ),

              const SizedBox(height: 20),

              // ── Caregiver card ──────────────────────────────────────────────
              RoleCard(
                icon: Icons.favorite_rounded,
                label: 'I am the Caregiver',
                subtitle: 'Scan the QR code to connect',
                color: const Color(0xFF2ECC8A),
                onTap: () => Navigator.pushNamed(context, '/caregiver'),
              ),

              const Spacer(),

              const Text(
                'Your connection is private and secure.',
                style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}