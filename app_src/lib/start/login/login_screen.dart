// login_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';   // (si lo usas)
import 'package:firebase_core/firebase_core.dart';           // (si lo usas)
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';          // ← NUEVO
import '../../services/notification_service.dart';                    // ← NUEVO

import '../../explore_screen/main_screen/explore_screen.dart';
import '../../main/colors.dart';
import '../../explore_screen/users_managing/presence_service.dart';
import 'recover_password.dart';
import '../registration/register_screen.dart';
import '../welcome_screen.dart';

const Color backgroundColor = AppColors.background;

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
  bool _rememberLogin = false;
  bool _showPassword = false;

  static const _rememberKey = 'rememberLogin';
  static const _emailKey = 'rememberEmail';
  static const _passwordKey = 'rememberPassword';

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_rememberKey) ?? false;
    if (!remember) return;
    setState(() {
      _rememberLogin = true;
      emailController.text = prefs.getString(_emailKey) ?? '';
      passwordController.text = prefs.getString(_passwordKey) ?? '';
    });
  }

  Future<bool> _userDocExists(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return false;
    final name = (doc.data()?['name'] ?? '').toString();
    return name.isNotEmpty;
  }

  Future<void> _goToExplore() async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ExploreScreen()),
    );
  }

  /* ───────────────────────────────────────────────────────────
   *  Email / Contraseña
   * ───────────────────────────────────────────────────────── */
  Future<void> _loginWithEmail() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = credential.user;
      if (user == null) throw FirebaseAuthException(code: 'USER_NULL');

      if (!await _userDocExists(user.uid)) {
        await _auth.signOut();
        if (mounted) _showNoProfileDialog();
        return;
      }

      await PresenceService.init(user);

      /* ─── NUEVO: reinicia notificaciones para este usuario ─── */
      final prefs   = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notificationsEnabled') ?? true;
      await NotificationService.instance.init(enabled: enabled);
      /* ──────────────────────────────────────────────────────── */

      if (_rememberLogin) {
        await prefs.setBool(_rememberKey, true);
        await prefs.setString(_emailKey, emailController.text.trim());
        await prefs.setString(_passwordKey, passwordController.text.trim());
      } else {
        await prefs.setBool(_rememberKey, false);
        await prefs.remove(_emailKey);
        await prefs.remove(_passwordKey);
      }

      await _goToExplore();
    } on FirebaseAuthException {
      if (mounted) _showErrorDialog('Correo o contraseña incorrectos.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /* ───────────────────────────────────────────────────────────
   *  Google
   * ───────────────────────────────────────────────────────── */
  Future<void> _loginWithGoogle() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      await GoogleSignIn().signOut();
      final GoogleSignInAccount? acc = await GoogleSignIn().signIn();
      if (acc == null) return;

      final auth  = await acc.authentication;
      final cred  = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final userCred = await _auth.signInWithCredential(cred);
      final user = userCred.user;
      if (user == null) throw FirebaseAuthException(code: 'USER_NULL');

      if (!await _userDocExists(user.uid)) {
        await _auth.signOut();
        if (!mounted) return;
        final create = await _showGoogleNoProfileDialog();
        if (create == true && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          );
        }
        return;
      }

      await PresenceService.init(user);

      /* ─── NUEVO: reinicia notificaciones para este usuario ─── */
      final prefs   = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notificationsEnabled') ?? true;
      await NotificationService.instance.init(enabled: enabled);
      /* ──────────────────────────────────────────────────────── */

      await prefs.setBool(_rememberKey, false);
      await prefs.remove(_emailKey);
      await prefs.remove(_passwordKey);
      if (mounted) setState(() => _rememberLogin = false);

      await _goToExplore();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de inicio de sesión con Google.')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /* ───────────────────────────────────────────────────────────
   *  Diálogos de error
   * ───────────────────────────────────────────────────────── */
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Aceptar')),
        ],
      ),
    );
  }

  Future<bool?> _showGoogleNoProfileDialog() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('No hay perfil'),
        content: const Text(
          'No hay un perfil asociado a tu cuenta de Google. ¿Crear una nueva cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Aceptar')),
        ],
      ),
    );
  }

  /* ───────────────────────────────────────────────────────────
   *  UI
   * ───────────────────────────────────────────────────────── */
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
            if (isLoading) const Center(child: CircularProgressIndicator()),
            Positioned(
              top: 40,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                color: AppColors.blue,
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WelcomeScreen(),
                    ),
                  );
                },
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
            SizedBox(height: 150, child: Image.asset('assets/plan-sin-fondo.png')),
            const SizedBox(height: 30),
            Text('Inicio de sesión',
                style: GoogleFonts.roboto(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _googleButton(),
            const SizedBox(height: 10),
            Text('- o -', style: GoogleFonts.roboto(fontSize: 18)),
            const SizedBox(height: 10),
            _inputField(controller: emailController, hint: 'Correo electrónico',
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 20),
            _inputField(controller: passwordController, hint: 'Contraseña', obscure: true),
            const SizedBox(height: 10),
            _rememberCheckbox(),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: _loginWithEmail,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color.fromARGB(236, 0, 4, 227),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 10,
                ),
                child: const Text('Iniciar sesión', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const RecoverPasswordScreen())),
              child: const Text('¿Olvidaste tu contraseña?',
                  style: TextStyle(decoration: TextDecoration.underline)),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              ),
              child: const Text(
                '¿No tienes una cuenta? Regístrate.',
                style: TextStyle(decoration: TextDecoration.underline),
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
        icon: Image.asset('assets/google_logo.png', height: 24, width: 24),
        label: Text('Continuar con Google',
            style: GoogleFonts.roboto(fontSize: 18, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: const Color.fromARGB(236, 0, 4, 227),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure ? !_showPassword : false,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.roboto(fontSize: 16, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          suffixIcon: obscure
              ? IconButton(
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                )
              : null,
        ),
      ),
    );
  }

  Widget _rememberCheckbox() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        children: [
          Checkbox(
            value: _rememberLogin,
            onChanged: (v) => setState(() => _rememberLogin = v ?? false),
            activeColor: AppColors.planColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: const BorderSide(color: AppColors.planColor),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Recordar datos de inicio de sesión'),
          ),
        ],
      ),
    );
  }
}
