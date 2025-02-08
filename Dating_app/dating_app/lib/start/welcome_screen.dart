// welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importa FirebaseAuth
import 'login_screen.dart';
import 'register_screen.dart';
import '../explore_screen/explore_screen.dart'; // Asegúrate de tener esta pantalla creada

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // Variable para almacenar el estado de autenticación
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // Función para verificar el estado de autenticación
  void _checkLoginStatus() async {
    // Obtiene el usuario actual
    User? user = FirebaseAuth.instance.currentUser;

    // Espera un breve momento para simular una carga o realizar operaciones asíncronas
    await Future.delayed(Duration(seconds: 1));

    if (user != null) {
      // Si el usuario está autenticado, navega a ExploreScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ExploreScreen()),
      );
    } else {
      // Si no está autenticado, permanece en WelcomeScreen
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Muestra un indicador de carga mientras verifica el estado de autenticación
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Si no está autenticado, muestra la pantalla de bienvenida
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 40), // Espacio superior
              // Reemplazo del título "PLAN" con el logo
              Center(
                child: Image.asset(
                  'assets/plan-sin-fondo.png', // Ruta del logo
                  height: 150, // Ajusta el tamaño según lo necesites
                ),
              ),
              SizedBox(height: 20),
              // Contenedor para centrar el texto
              Container(
                margin: EdgeInsets.symmetric(horizontal: 40), // Márgenes laterales
                child: Column(
                  children: [
                    Text(
                      '¡PLAN es la plataforma social donde los intereses comunes se fusionan!',
                      style: GoogleFonts.roboto( // Uso de la fuente Roboto
                        fontSize: 18,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text(
                      '¿Y tú? ¿Qué PLAN propones?',
                      style: GoogleFonts.roboto( // Uso de la fuente Roboto
                        fontSize: 20,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40),
              // Botones
              Column(
                children: [
                  // Botón "Iniciar sesión"
                  SizedBox(
                    width: 200, // Tamaño fijo para ambos botones
                    child: ElevatedButton(
                      onPressed: () {
                        // Navegar a la pantalla de inicio de sesión
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoginScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Color.fromARGB(236, 0, 4, 227), // Fondo azul
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        shadowColor: Colors.black.withOpacity(0.2), // Color de sombra
                        elevation: 10, // Elevación para sombra
                      ),
                      child: Text(
                        'Iniciar sesión',
                        style: GoogleFonts.roboto( // Uso de la fuente Roboto
                          fontSize: 20,
                          color: Colors.white, // Texto blanco
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Botón "Registrarse"
                  SizedBox(
                    width: 200, // Tamaño fijo para ambos botones
                    child: OutlinedButton(
                      onPressed: () {
                        // Navegar a la pantalla de registro
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegisterScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white, // Fondo blanco
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        side: BorderSide(color: const Color.fromARGB(236, 0, 4, 227), width: 2), // Contorno azul
                      ),
                      child: Text(
                        'Registrarse',
                        style: GoogleFonts.roboto( // Uso de la fuente Roboto
                          fontSize: 20,
                          color: Color.fromARGB(236, 0, 4, 227), // Texto azul
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 40), // Espacio inferior
            ],
          ),
        ),
      ),
    );
  }
}
