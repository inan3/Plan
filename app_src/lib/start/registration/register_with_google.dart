// lib/start/registration/register_with_google.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dating_app/main/colors.dart';
import 'package:dating_app/start/registration/user_registration_screen.dart';
import 'verification_provider.dart';
import 'email_verification_screen.dart';
import 'auth_service.dart';

class RegisterWithGoogle extends StatefulWidget {
  const RegisterWithGoogle({Key? key}) : super(key: key);

  @override
  State<RegisterWithGoogle> createState() => _RegisterWithGoogleState();
}

class _RegisterWithGoogleState extends State<RegisterWithGoogle> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startGoogleFlow();
  }

  Future<void> _startGoogleFlow() async {
    setState(() => _loading = true);

    try {
      final credential = await AuthService.signInWithGoogle();
      final user = credential.user;
      if (user == null) {
        Navigator.pop(context);
        return;
      }

      if (!mounted) return;

      if (!user.emailVerified) {
        await user.sendEmailVerification();

        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Verifica tu correo'),
            content: Text(
              'Se ha enviado un correo de verificación a ${user.email}. '
              'Sigue el enlace recibido para continuar.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(
              email: user.email ?? '',
              provider: VerificationProvider.google,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UserRegistrationScreen(
              provider: VerificationProvider.google,
              firebaseUser: user,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error con Google: $e')),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : const Text(
                'Iniciando con Google…',
                style: TextStyle(color: Colors.white),
              ),
      ),
    );
  }
}
