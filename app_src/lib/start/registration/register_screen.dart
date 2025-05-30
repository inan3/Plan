// lib/start/registration/register_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dating_app/main/colors.dart';
import 'register_with_google.dart';
import 'verification_provider.dart';
import 'user_registration_screen.dart';
import 'local_registration_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> _register() async {
    setState(() => isLoading = true);

    try {
      await LocalRegistrationService.saveEmailPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UserRegistrationScreen(
            provider: VerificationProvider.password,
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          ),
        ),
      );
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
                          hintText: 'Correo electrónico',
                          hintStyle: GoogleFonts.roboto(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20),
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
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Contraseña',
                          hintStyle: GoogleFonts.roboto(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Botón registrarse
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _register,
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
                        Navigator.pop(context);
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
                  Navigator.pop(context);
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
