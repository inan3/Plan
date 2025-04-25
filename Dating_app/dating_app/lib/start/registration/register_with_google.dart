// lib/start/registration/register_with_google.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:dating_app/main/colors.dart';
import 'email_verification_screen.dart'; 
import 'verification_provider.dart';
import 'package:dating_app/start/registration/user_registration_screen.dart'
    as userReg;

class RegisterWithGoogle extends StatefulWidget {
  const RegisterWithGoogle({Key? key}) : super(key: key);

  @override
  State<RegisterWithGoogle> createState() => _RegisterWithGoogleState();
}

class _RegisterWithGoogleState extends State<RegisterWithGoogle> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startGoogleFlow();
  }

  /// Inicia el proceso de Google Sign-In, obtiene credenciales,
  /// cierra sesión inmediatamente y navega a UserRegistrationScreen
  /// con los tokens para que el login final se haga al pulsar "Completar registro".
  Future<void> _startGoogleFlow() async {
    setState(() => _loading = true);

    try {
      // Asegurarnos de salir de cualquier sesión previa en GoogleSignIn
      await GoogleSignIn().signOut();

      final GoogleSignInAccount? acc = await GoogleSignIn().signIn();
      if (acc == null) {
        // Usuario canceló el flujo de Google
        Navigator.pop(context);
        return;
      }

      // Obtenemos el token/credenciales de Google
      final authAccount = await acc.authentication;
      final accessToken = authAccount.accessToken;
      final idToken = authAccount.idToken;

      if (accessToken == null || idToken == null) {
        // Algo fue mal al obtener tokens
        Navigator.pop(context);
        return;
      }

      // Logueamos brevemente en Firebase para confirmar la cuenta
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      // Cerramos sesión para que no quede logueado
      await _auth.signOut();

      if (!mounted) return;

      // Navegamos a la pantalla de registro de perfil, pasándole los tokens
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => userReg.UserRegistrationScreen(
            provider: VerificationProvider.google,
            googleAccessToken: accessToken,
            googleIdToken: idToken,
          ),
        ),
      );
    } catch (e) {
      await _auth.signOut();
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
