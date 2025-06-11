// lib/start/registration/register_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dating_app/main/colors.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'register_with_google.dart';
import 'verification_provider.dart';
import 'email_verification_screen.dart';
import 'auth_service.dart';
import 'local_registration_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login/login_screen.dart';
import '../welcome_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  String? _phoneNumber;

  bool _showPassword = false;
  bool _showConfirm = false;
  bool _isEmail = true;

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
    phoneController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  void _showPopup(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Atención',
          style: TextStyle(color: AppColors.blue),
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.blue),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: AppColors.blue),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Este correo ya está registrado. Inicia sesión para continuar.'),
            ),
          );
        } on FirebaseAuthException {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contraseña incorrecta.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar registro: ${e.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar registro: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      'Crea tu cuenta',
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
                          'Continuar con Google',
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
                      '- o -',
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Selector Correo/Teléfono
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isEmail = true),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: _isEmail
                                    ? AppColors.planColor
                                    : AppColors.lightLilac,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.greyBorder),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Correo electrónico',
                                style: TextStyle(
                                  color:
                                      _isEmail ? Colors.white : Colors.black,
                                  fontFamily: 'Inter-Regular',
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isEmail = false),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: !_isEmail
                                    ? AppColors.planColor
                                    : AppColors.lightLilac,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.greyBorder),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Número de teléfono',
                                style: TextStyle(
                                  color:
                                      !_isEmail ? Colors.white : Colors.black,
                                  fontFamily: 'Inter-Regular',
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Campo correo o teléfono
                    if (_isEmail)
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
                            hintText: 'Correo electrónico',
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
                      )
                    else
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
                        child: IntlPhoneField(
                          controller: phoneController,
                          initialCountryCode: 'ES',
                          decoration: InputDecoration(
                            hintText: 'Número de teléfono',
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
                          onChanged: (phone) => _phoneNumber = phone.completeNumber,
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
                          hintText: 'Contraseña',
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
                            text: 'Mayúscula',
                          ),
                          const SizedBox(width: 8),
                          _buildRequirement(
                            ok: _hasNumber,
                            text: 'Número',
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
                          hintText: 'Repetir contraseña',
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

                    // Botón registrarse
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                if (!_match) {
                                  _showPopup('Las contraseñas no coinciden');
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
                          'Registrarse',
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
                      child: const Text(
                        '¿Ya tienes una cuenta? Inicia sesión',
                        style: TextStyle(
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
