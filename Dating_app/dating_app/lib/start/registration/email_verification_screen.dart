import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';

// Ajusta la ruta si tu AppColors está en otra ubicación
import '../../main/colors.dart';
import '../username_screen.dart';

/// Nuevo nombre para evitar conflicto con AuthProvider de Firebase
enum VerificationProvider {
  password,
  google,
}

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    Key? key,
    required this.email,
    required this.provider,
    this.password, // solo se usa cuando provider == VerificationProvider.password
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
      User? user;

      if (widget.provider == VerificationProvider.password) {
        // Iniciamos sesión silenciosamente con email/contraseña
        await _auth.signInWithEmailAndPassword(
          email: widget.email,
          password: widget.password!,
        );
        user = _auth.currentUser;
      } else {
        // GOOGLE → intentamos login silencioso
        final GoogleSignInAccount? googleAcc =
            await GoogleSignIn().signInSilently();
        if (googleAcc == null) {
          // Si no hay sesión, pedimos seleccionar cuenta
          final GoogleSignInAccount? interactive =
              await GoogleSignIn().signIn();
          if (interactive == null) {
            // canceló
            setState(() => _checking = false);
            return;
          }
        }
        // Generamos credencial y entramos en Firebase
        final googleAuth = await GoogleSignIn().currentUser!.authentication;
        final cred = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await _auth.signInWithCredential(cred);
        user = _auth.currentUser;
      }

      // Recargamos para actualizar emailVerified
      await user?.reload();
      user = _auth.currentUser;

      if (user != null && user.emailVerified) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const UsernameScreen()),
          (_) => false,
        );
      } else {
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Te enviamos un enlace a:\n${widget.email}\n\n'
                    'Haz clic, vuelve a la app y pulsa el botón de abajo.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(fontSize: 16),
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
                            await user?.sendEmailVerification();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Correo de verificación reenviado.'),
                              ),
                            );
                          },
                    child: const Text('Reenviar correo'),
                  ),
                ],
              ),
            ),
          ),

          if (_checking)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
