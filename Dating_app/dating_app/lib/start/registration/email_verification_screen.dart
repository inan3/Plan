// lib/start/registration/email_verification_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dating_app/main/colors.dart';
// Importamos la enum y la pantalla de registro
import 'verification_provider.dart';
import 'package:dating_app/start/registration/user_registration_screen.dart'
    as userReg;

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _checking = false;

  Future<void> _checkVerification() async {
    setState(() => _checking = true);

    try {
      // Para Email/Password, hacemos un login silencioso:
      if (widget.provider == VerificationProvider.password &&
          widget.password != null) {
        await _auth.signInWithEmailAndPassword(
          email: widget.email,
          password: widget.password!,
        );
      } else if (widget.provider == VerificationProvider.google) {
        // Si fuese necesario, aquí manejaríamos la verificación de Google,
        // pero Google normalmente ya viene verificado y este flujo de Email
        // no aplica igual. Lo omitimos si no lo usas.
      }

      User? user = _auth.currentUser;
      await user?.reload();
      user = _auth.currentUser;

      if (user != null && user.emailVerified) {
        // CERRAMOS SESIÓN para que no quede logueado todavía
        await _auth.signOut();

        // Navegamos a UserRegistrationScreen, pasándole email/pass
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => userReg.UserRegistrationScreen(
              provider: widget.provider,
              email: widget.email,
              password: widget.password,
            ),
          ),
          (_) => false,
        );
      } else {
        // Si no está verificado
        await _auth.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tu correo aún no está verificado.')),
        );
      }
    } catch (e) {
      await _auth.signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al verificar: $e')),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
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
                  // LOGO
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
                    onPressed: _checking
                        ? null
                        : () async {
                            final user = _auth.currentUser;
                            if (user != null && !user.emailVerified) {
                              await user.sendEmailVerification();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Correo de verificación reenviado.',
                                  ),
                                ),
                              );
                            }
                          },
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
