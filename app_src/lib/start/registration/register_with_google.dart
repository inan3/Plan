// lib/start/registration/register_with_google.dart
import 'package:flutter/material.dart';
import 'package:dating_app/main/colors.dart';
import 'user_registration_screen.dart';
import 'password_selection_screen.dart';
import 'verification_provider.dart';
import 'local_registration_service.dart';
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
      final cred = await AuthService.signInWithGoogle();
      final user = cred.user;
      if (user == null) throw Exception('No se pudo iniciar sesión');

      await LocalRegistrationService.saveGoogle(email: user.email);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PasswordSelectionScreen(firebaseUser: user),
        ),
      );
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
