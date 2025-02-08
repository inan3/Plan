import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'start/welcome_screen.dart'; // Importa la nueva pantalla inicial

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Inicializa Firebase aquí
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoveMe',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: WelcomeScreen(), // Pantalla inicial configurada
    );
  }
}
