import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../start/welcome_screen.dart'; // Asegúrate de importar la pantalla de bienvenida
import '../users_managing/presence_service.dart'; // Asegúrate de importar el servicio de presencia

class CloseSessionScreen extends StatelessWidget {
  const CloseSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    _logout(context); // Llama al método de cierre de sesión al entrar en esta pantalla

    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(), // Indicador de carga mientras se cierra la sesión
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      // Cierra sesión en Firebase
      await FirebaseAuth.instance.signOut();
      //PresenceService.dispose();

      // Redirige a la pantalla de bienvenida
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => WelcomeScreen()),
        (Route<dynamic> route) => false, // Elimina el historial de navegación
      );
    } catch (e) {
      // Manejar errores (por ejemplo, si hay un problema cerrando sesión)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: ${e.toString()}')),
      );
    }
  }
}
