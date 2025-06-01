// lib/start/registration/email_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dating_app/main/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dating_app/explore_screen/main_screen/explore_screen.dart';
import 'verification_provider.dart';
import 'auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    Key? key,
    required this.email,
    required this.provider,
    this.password,
  }) : super(key: key);

  final String email;
  final String? password;
  final VerificationProvider provider;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _checking = false;

  Future<void> _checkVerification() async {
    setState(() => _checking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed != null && refreshed.emailVerified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ExploreScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aún no has verificado el correo.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al verificar: $e')),
      );
    } finally {
      setState(() => _checking = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _checking = true);
    try {
      await AuthService.resendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo de verificación reenviado.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reenviar: $e')),
      );
    } finally {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 150,
                    child: Image.asset('assets/plan-sin-fondo.png'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verificación de correo',
                    style: GoogleFonts.roboto(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Te enviamos un enlace a:\n${widget.email}\n\n'
                    'Haz clic, vuelve a la app y pulsa el botón de abajo para continuar.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _checking ? null : _checkVerification,
                    child: const Text('Ya verifiqué'),
                  ),
                  TextButton(
                    onPressed: _checking ? null : _resendEmail,
                    child: const Text('Reenviar correo'),
                  ),
                ],
              ),
            ),
          ),
          if (_checking) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
