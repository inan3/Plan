import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../main/colors.dart';
import 'email_verification_screen.dart';
import '../username_screen.dart';

class RegisterWithGoogle extends StatefulWidget {
  const RegisterWithGoogle({Key? key}) : super(key: key);

  @override
  State<RegisterWithGoogle> createState() => _RegisterWithGoogleState();
}

class _RegisterWithGoogleState extends State<RegisterWithGoogle> {
  final _auth = FirebaseAuth.instance;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startGoogleFlow();
  }

  Future<void> _startGoogleFlow() async {
    setState(() => _loading = true);

    try {
      // 1. Iniciar sesión con Google
      final GoogleSignInAccount? acc = await GoogleSignIn().signIn();
      if (acc == null) {
        // El usuario canceló
        Navigator.pop(context);
        return;
      }
      final auth = await acc.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final uCred = await _auth.signInWithCredential(cred);

      User? user = uCred.user;
      // Recargamos la info del usuario y obtenemos el currentUser
      await user?.reload();
      user = _auth.currentUser;

      final isNew = uCred.additionalUserInfo?.isNewUser ?? false;

      // 2. Verificamos si es nuevo y si no está verificado
      if (user == null) {
        // Si por alguna razón user es null, volvemos
        Navigator.pop(context);
        return;
      }

      // Creamos una variable local no nula para que el compilador lo sepa
      final currentUser = user;

      if (!currentUser.emailVerified && isNew) {
        // Nuevo y no verificado: enviamos verificación, cerramos sesión y vamos a EmailVerification
        await currentUser.sendEmailVerification();
        await _auth.signOut();

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(
              email: currentUser.email!, // ahora sí es seguro usar !
              provider: VerificationProvider.google,
            ),
          ),
        );
      } else {
        // Ya estaba verificado o no era nuevo
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UsernameScreen()),
        );
      }
    } catch (e) {
      // Ante cualquier error, cerramos sesión y mostramos SnackBar
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
            : const Text('Iniciando con Google…'),
      ),
    );
  }
}
