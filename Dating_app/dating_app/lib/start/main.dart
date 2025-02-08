import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../start/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Inicializa Firebase

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dating App',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: FutureBuilder<User?>(
        future: _getCurrentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Mostrar un indicador de carga mientras se resuelve el estado del usuario
            return Scaffold(
              backgroundColor: Colors.white,
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            // Manejar errores (por ejemplo, fallo en Firebase.initializeApp)
            return Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Text(
                  'Error al inicializar la app.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            );
          } else {
            final user = snapshot.data;

            if (user == null) {
              // Usuario no autenticado
              return WelcomeScreen();
            } else if (!user.emailVerified) {
              // Usuario autenticado pero con correo no verificado
              FirebaseAuth.instance.signOut();
              return WelcomeScreen();
            } else {
              // Usuario autenticado y verificado
              return MainAppScreen();
            }
          }
        },
      ),
    );
  }

  Future<User?> _getCurrentUser() async {
    // Espera un pequeño tiempo para evitar problemas de inicialización
    await Future.delayed(Duration(milliseconds: 500));
    return FirebaseAuth.instance.currentUser;
  }
}

// Función para adaptar dinámicamente el brillo de los íconos de la barra de estado
void setStatusBarStyle({required bool isLightBackground}) {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isLightBackground ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
}
