// lib/start/registration/register_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dating_app/main/colors.dart';
import '../../l10n/app_localizations.dart';
import 'register_with_google.dart';
import 'verification_provider.dart';
import 'email_verification_screen.dart';
import 'auth_service.dart';
import 'local_registration_service.dart';
import 'user_registration_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login/login_screen.dart';
import '../welcome_screen.dart';
import '../../utils/auth_error_utils.dart';
import '../../services/location_update_service.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool _showPassword = false;
  bool _showConfirm = false;

  bool get _hasUppercase => passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _match => passwordController.text == confirmController.text;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    passwordController.addListener(() => setState(() {}));
    confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  void _showPopup(String message) {
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          t.attention,
          style: const TextStyle(color: AppColors.blue),
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.blue),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              t.ok,
              style: const TextStyle(color: AppColors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement({required bool ok, required String text}) {
    final color = ok ? AppColors.lightTurquoise : Colors.white;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.greyBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check : Icons.close,
              color: ok ? AppColors.planColor : Colors.black),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: ok ? AppColors.planColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _userDocExists(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return false;
    final name = (doc.data()?['name'] ?? '').toString();
    return name.isNotEmpty;
  }

  Future<void> _register() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      final t = AppLocalizations.of(context);
      final missing = <String>[];
      if (emailController.text.trim().isEmpty) missing.add(t.emailWord);
      if (passwordController.text.trim().isEmpty) missing.add(t.password);
      final msg =
          '${t.introduceYour} ${missing.join(t.andWord)} ${t.thenPressRegister}';
      _showPopup(msg);
      return;
    }

    setState(() => isLoading = true);

    try {
      // Crea el usuario y envía el correo de verificación
      await AuthService.createUserWithEmail(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Guardamos que hay un registro pendiente
      await LocalRegistrationService.saveEmailPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
            provider: VerificationProvider.password,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          final cred = await AuthService.signInWithEmail(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );
          final user = cred.user;
          if (user != null && !await _userDocExists(user.uid)) {
            await user.sendEmailVerification();
            await LocalRegistrationService.saveEmailPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim(),
            );
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => EmailVerificationScreen(
                  email: emailController.text.trim(),
                  password: passwordController.text.trim(),
                  provider: VerificationProvider.password,
                ),
              ),
            );
            return;
          }
          await FirebaseAuth.instance.signOut();
          LocationUpdateService.dispose();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t.emailAlreadyRegistered),
            ),
          );
        } on FirebaseAuthException {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.incorrectPassword)),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.registrationError} ${e.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.registrationError} $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    const Color backgroundColor = AppColors.background;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    SizedBox(
                      height: 150,
                      child: Image.asset(
                        'assets/plan-sin-fondo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Título
                    Text(
                      t.createAccount,
                      style: GoogleFonts.roboto(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botón "Continuar con Google"
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterWithGoogle(),
                            ),
                          );
                        },
                        icon: Image.asset(
                          'assets/google_logo.png',
                          height: 24,
                          width: 24,
                        ),
                        label: Text(
                          t.continueWithGoogle,
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor:
                              const Color.fromARGB(236, 0, 4, 227),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          shadowColor: Colors.black.withOpacity(0.2),
                          elevation: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Separador
                    Text(
                      t.orSeparator,
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Campo correo
                    Container(
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
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: t.emailHint,
                          hintStyle: GoogleFonts.roboto(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Campo contraseña
                    Container(
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
                        controller: passwordController,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          hintText: t.password,
                          hintStyle: GoogleFonts.roboto(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Row(
                        children: [
                          _buildRequirement(
                            ok: _hasUppercase,
                            text: t.uppercase,
                          ),
                          const SizedBox(width: 8),
                          _buildRequirement(
                            ok: _hasNumber,
                            text: t.number,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Repetir contraseña
                    Container(
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
                        controller: confirmController,
                        obscureText: !_showConfirm,
                        decoration: InputDecoration(
                          hintText: t.repeatPassword,
                          hintStyle: GoogleFonts.roboto(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _showConfirm = !_showConfirm),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            decoration: TextDecoration.none,
                          ),
                          children: [
                            TextSpan(text: t.byContinuingPrefix),
                            TextSpan(
                              text: t.termsAndConditions,
                              style: const TextStyle(color: Colors.blue),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchUrl(
                                      Uri.parse(
                                          'https://plansocialapp.es/terms_and_conditions.html'),
                                      mode: LaunchMode.externalApplication,
                                    ),
                            ),
                            TextSpan(text: t.commaThe),
                            TextSpan(
                              text: t.privacyPolicy,
                              style: const TextStyle(color: Colors.blue),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchUrl(
                                      Uri.parse(
                                          'https://plansocialapp.es/privacy_policy.html'),
                                      mode: LaunchMode.externalApplication,
                                    ),
                            ),
                            TextSpan(text: t.andCookies),
                            TextSpan(
                              text: t.cookies,
                              style: const TextStyle(color: Colors.blue),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchUrl(
                                      Uri.parse(
                                          'https://plansocialapp.es/cookies.html'),
                                      mode: LaunchMode.externalApplication,
                                    ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Botón registrarse
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                if (!_match) {
                                  _showPopup(t.passwordMismatch);
                                } else {
                                  _register();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor:
                              const Color.fromARGB(236, 0, 4, 227),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          shadowColor: Colors.black.withOpacity(0.2),
                          elevation: 10,
                        ),
                        child: Text(
                          t.register,
                          style: GoogleFonts.roboto(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: Text(
                        t.alreadyHaveAccount,
                        style: const TextStyle(
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Botón atrás
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

            if (isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
