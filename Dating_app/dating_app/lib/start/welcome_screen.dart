// welcome_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'registration/register_screen.dart';
import '../explore_screen/main_screen/explore_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // Lista de imágenes de fondo
  final List<String> _backgroundImages = [
    'assets/image-meeting.png',
    'assets/image-padel.png',
    'assets/image-pool-party.png',
    'assets/image-cycling.png',
  ];

  // Controlador para PageView (carrusel)
  late final PageController _pageController;

  // Timer para avanzar página cada 2 seg
  Timer? _timer;

  // El número total que usaremos para “simular infinito”
  final int _totalPages = 10000;

  // Empezamos en la mitad de las páginas disponibles,
  // para evitar llegar rápido al final o al principio.
  int _currentPage = 5000;

  // Variable para indicar si se está comprobando la autenticación
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Verificamos el estado de autenticación
    _checkLoginStatus();

    // Iniciamos el controlador en la página _currentPage
    _pageController = PageController(initialPage: _currentPage);

    // Configuramos un Timer para que cada 2 segundos avance a la siguiente “página”
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      setState(() {
        _currentPage++;
        // Si llegamos cerca del final, nos regresamos a la mitad
        // para mantener la ilusión de un carrusel infinito
        if (_currentPage == _totalPages - 1) {
          _currentPage = _totalPages ~/ 2;
          _pageController.jumpToPage(_currentPage);
        } else {
          // Avanzamos con una animación suave
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    // Cancelar el Timer para evitar fugas de memoria
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // Verificar el estado de autenticación
  void _checkLoginStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    // Pequeño delay para simular tiempo de carga
    await Future.delayed(const Duration(seconds: 1));

    if (user != null) {
      // Si está logueado, nos vamos a ExploreScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ExploreScreen()),
      );
    } else {
      // Si no está logueado, mostramos la pantalla de bienvenida
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mientras comprobamos la autenticación, mostramos el indicador de carga
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Pantalla de bienvenida
    return Scaffold(
      body: Stack(
        children: [
          // --------------------------
          // FONDO: PageView infinito
          // --------------------------
          PageView.builder(
            controller: _pageController,
            // Deshabilitamos el scroll manual
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _totalPages,
            itemBuilder: (context, index) {
              // index % _backgroundImages.length para acceder cíclicamente
              final imageIndex = index % _backgroundImages.length;
              return SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Image.asset(
                  _backgroundImages[imageIndex],
                  fit: BoxFit.cover,
                ),
              );
            },
          ),

          // ----------------------------------------------
          // CAPA SEMITRANSPARENTE PARA OSCURECER EL FONDO
          // ----------------------------------------------
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.3),
          ),

          // --------------------------------------
          // CONTENIDO: LOGO, TEXTO Y BOTONES
          // --------------------------------------
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  Center(
                    child: Image.asset(
                      'assets/plan-sin-fondo.png',
                      height: 150,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Texto descriptivo
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
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
                  // Botones de inicio de sesión y registro
                  Column(
                    children: [
                      // Botón de inicio de sesión
                      SizedBox(
                        width: 200,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
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
                            'Iniciar sesión',
                            style: GoogleFonts.roboto(
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Botón de registro
                      SizedBox(
                        width: 200,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
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
                    ],
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
