// welcome_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import 'registration/register_screen.dart';
import '../explore_screen/main_screen/explore_screen.dart';
import 'registration/user_registration_screen.dart';
import 'registration/verification_provider.dart';
import 'registration/email_verification_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  /* ------------------------------------------------------------------ */
  /* ------------------  CONFIGURACIÓN DEL CARRUSEL  ------------------ */
  /* ------------------------------------------------------------------ */
  final List<String> _backgroundImages = [
    'assets/image-meeting.png',
    'assets/image-padel.png',
    'assets/image-pool-party.png',
    'assets/image-cycling.png',
  ];
  late final PageController _pageController;
  Timer? _timer;
  final int _totalPages = 10000;
  int _currentPage = 5000;

  /* ------------------------------------------------------------------ */
  bool _isLoading = true;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
    _autoSlideBackground();
    _listenAuthChanges(); // Escuchamos la sesión de Firebase
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _authSub?.cancel();
    super.dispose();
  }

  /* ---------------------------  LISTENER  --------------------------- */
  void _listenAuthChanges() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(
      (user) async {
        if (user == null) {
          // Sin sesión → mostramos bienvenida
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        // Recargamos info para asegurar que emailVerified está actualizado
        await user.reload();

        // Si el correo NO está verificado
        if (!user.emailVerified) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => EmailVerificationScreen(
                  email: user.email ?? '', // El user.email
                  password: null, // O lo que necesites
                  provider:
                      VerificationProvider.password, // Ajusta según tu flujo
                ),
              ),
            );
          }
          return;
        }

        // Si está verificado, revisamos si ya hay doc en Firestore
        final exists = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .then((d) => d.exists)
            .catchError((_) => false);

        if (!exists) {
          // No hay doc → vamos a UserRegistrationScreen
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const UserRegistrationScreen(
                  provider: VerificationProvider.password, // o google...
                ),
              ),
            );
          }
          return;
        }

        // Todo OK → ir a ExploreScreen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ExploreScreen()),
          );
        }
      },
    );
  }

  /* --------------------  CARRUSEL “INFINITO”  -------------------- */
  void _autoSlideBackground() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _currentPage++;
        if (_currentPage == _totalPages - 1) {
          _currentPage = _totalPages ~/ 2;
          _pageController.jumpToPage(_currentPage);
        } else {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  /* ---------------------------  UI  --------------------------- */
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _totalPages,
            itemBuilder: (_, index) {
              final img = _backgroundImages[index % _backgroundImages.length];
              return Image.asset(img, fit: BoxFit.cover);
            },
          ),
          Container(color: Colors.black.withOpacity(0.3)),
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Image.asset('assets/plan-sin-fondo.png', height: 150),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        Text(
                          '¡PLAN es la plataforma social donde los intereses comunes se fusionan!',
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '¿Y tú? ¿Qué PLAN propones?',
                          style: GoogleFonts.roboto(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color.fromARGB(236, 0, 4, 227),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        shadowColor: Colors.black.withOpacity(0.2),
                        elevation: 10,
                      ),
                      child: Text(
                        'Iniciar sesión',
                        style: GoogleFonts.roboto(
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 200,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        side: const BorderSide(
                          color: Color.fromARGB(236, 0, 4, 227),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'Registrarse',
                        style: GoogleFonts.roboto(
                          fontSize: 20,
                          color: Color.fromARGB(236, 0, 4, 227),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
