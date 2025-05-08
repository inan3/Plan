import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import para Realtime Database
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../explore_screen/main_screen/explore_screen.dart';
import '../../main/colors.dart';

// IMPORTA TU SERVICIO DE PRESENCIA:
import '../../explore_screen/users_managing/presence_service.dart'; // Ajusta el path según tu estructura

// Import de la nueva pantalla de recuperación
import 'recover_password.dart';

const Color backgroundColor = AppColors.background; // Azul turquesa

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController emailController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  Future<bool> _userDocExists(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.exists;
  }

  Future<void> _goToExplore() async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ExploreScreen()),
    );
  }

  Future<void> _loginWithEmail() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'USER_NULL');
      }

      final existsInUsers = await _userDocExists(user.uid);
      if (!existsInUsers) {
        await _auth.signOut();
        if (!mounted) return;
        _showNoProfileDialog();
        return;
      }

      await PresenceService.init(user);

      if (mounted) setState(() => isLoading = false);
      await _goToExplore();

    } on FirebaseAuthException {
      if (mounted) {
        _showErrorDialog('Correo o contraseña incorrectos.');
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      await GoogleSignIn().signOut();

      final GoogleSignInAccount? acc = await GoogleSignIn().signIn();
      if (acc == null) return;

      final auth = await acc.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      final userCred = await _auth.signInWithCredential(cred);
      final user = userCred.user;
      if (user == null) throw FirebaseAuthException(code: 'USER_NULL');

      final existsInUsers = await _userDocExists(user.uid);
      if (!existsInUsers) {
        await _auth.signOut();
        if (mounted) _showNoProfileDialog();
        return;
      }

      await PresenceService.init(user);

      if (mounted) setState(() => isLoading = false);
      await _goToExplore();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de inicio de sesión con Google.')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showNoProfileDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('No estás registrado'),
        content: const Text(
          'No hay ningún perfil en la base de datos para este usuario. '
          'Debes registrarte primero.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error de inicio de sesión'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            _buildForm(),
            if (isLoading)
              const Center(child: CircularProgressIndicator()),
            Positioned(
              top: 40,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                color: AppColors.blue,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // LOGO
            SizedBox(
              height: 150,
              child: Image.asset(
                'assets/plan-sin-fondo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 30),

            Text(
              'Inicio de sesión',
              style: GoogleFonts.roboto(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            _googleButton(),

            const SizedBox(height: 10),
            Text('- o -', style: GoogleFonts.roboto(fontSize: 18)),
            const SizedBox(height: 10),

            _inputField(
              controller: emailController,
              hint: 'Correo electrónico',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),

            _inputField(
              controller: passwordController,
              hint: 'Contraseña',
              obscure: true,
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: _loginWithEmail,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Color.fromARGB(236, 0, 4, 227),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 10,
                ),
                child: const Text(
                  'Iniciar sesión',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RecoverPasswordScreen()),
                );
              },
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(
                  color: Colors.black,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _googleButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loginWithGoogle,
        icon: Image.asset(
          'assets/google_logo.png',
          height: 24,
          width: 24,
        ),
        label: Text(
          'Continuar con Google',
          style: GoogleFonts.roboto(fontSize: 18, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Color.fromARGB(236, 0, 4, 227),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 10,
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.roboto(fontSize: 16, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
    );
  }
}
