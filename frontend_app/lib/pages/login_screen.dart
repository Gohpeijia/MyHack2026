import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isSignUp    = false; // toggle between Login / Sign Up
  bool _loading     = false;
  bool _obscure     = true;
  String? _errorMsg;

  late final String _sessionId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    _sessionId = args?['sessionId'] as String? ?? '';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Auth logic ─────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMsg = null; });

    try {
      final auth = FirebaseAuth.instance;
      final db   = FirebaseDatabase.instance.ref();
      UserCredential cred;

      if (_isSignUp) {
        // ── Create account ─────────────────────────────────────────────────
        cred = await auth.createUserWithEmailAndPassword(
          email:    _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );

        // Save caregiver profile (only once — keyed by UID)
        await db.child('caregivers/${cred.user!.uid}').set({
          'name':      _nameCtrl.text.trim(),
          'email':     _emailCtrl.text.trim(),
          'createdAt': ServerValue.timestamp,
        });
      } else {
        // ── Sign in ────────────────────────────────────────────────────────
        cred = await auth.signInWithEmailAndPassword(
          email:    _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      }

      // ── Mark session as connected in Firebase ──────────────────────────────
      // The elderly page is listening to this node and will navigate to /home
      // as soon as it sees status == 'connected'
      if (_sessionId.isNotEmpty) {
        await db.child('sessions/$_sessionId').update({
          'status':         'connected',
          'caregiverUid':   cred.user!.uid,
          'caregiverEmail': cred.user!.email ?? '',
          'connectedAt':    ServerValue.timestamp,
        });
      }

      if (!mounted) return;

      // ── Caregiver goes home immediately ────────────────────────────────────
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
        arguments: {
          'isCaregiver':    true,
          'sessionId':      _sessionId,
          'caregiverEmail': cred.user!.email ?? '',
        },
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMsg = _friendlyError(e.code));
    } catch (e) {
      setState(() => _errorMsg = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':  return 'This email is already registered. Please log in.';
      case 'wrong-password':        return 'Incorrect password. Please try again.';
      case 'user-not-found':        return 'No account found. Please sign up first.';
      case 'invalid-email':         return 'Please enter a valid email address.';
      case 'weak-password':         return 'Password must be at least 6 characters.';
      case 'too-many-requests':     return 'Too many attempts. Please wait and try again.';
      default:                      return 'Authentication failed. Please try again.';
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // ── Icon ────────────────────────────────────────────────────
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC8A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFF2ECC8A),
                    size: 36,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Title ───────────────────────────────────────────────────
                Text(
                  _isSignUp ? 'Create Account' : 'Welcome Back',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isSignUp
                      ? 'Sign up to start caring for your loved one.'
                      : 'Sign in to continue as caregiver.',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B6B80)),
                ),

                const SizedBox(height: 32),

                // ── Name field (sign-up only) ────────────────────────────────
                if (_isSignUp) ...[
                  _buildField(
                    controller: _nameCtrl,
                    label: 'Full Name',
                    icon: Icons.person_outline_rounded,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Email ───────────────────────────────────────────────────
                _buildField(
                  controller: _emailCtrl,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your email';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ── Password ────────────────────────────────────────────────
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: Color(0xFF9999AA)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF9999AA),
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2ECC8A), width: 2),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter your password';
                    if (_isSignUp && v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // ── Error message ────────────────────────────────────────────
                if (_errorMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE74C3C).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Color(0xFFE74C3C), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMsg!,
                            style: const TextStyle(
                                color: Color(0xFFE74C3C), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Submit button ────────────────────────────────────────────
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC8A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF2ECC8A).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _isSignUp ? 'Create Account' : 'Sign In',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Toggle login / signup ────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUp
                          ? 'Already have an account? '
                          : "Don't have an account? ",
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF6B6B80)),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _isSignUp = !_isSignUp;
                        _errorMsg = null;
                      }),
                      child: Text(
                        _isSignUp ? 'Sign In' : 'Sign Up',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2ECC8A),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Info note ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90D9).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Color(0xFF4A90D9), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your account is saved — you only need to sign up once.',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF4A90D9)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF9999AA)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2ECC8A), width: 2),
        ),
      ),
      validator: validator,
    );
  }
}