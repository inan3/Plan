// lib/explore_screen/settings/close_session_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../start/welcome_screen.dart';
import '../users_managing/presence_service.dart';

class CloseSessionScreen extends StatelessWidget {
  const CloseSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    _logout(context); // Ejecuta el cierre de sesión al entrar

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1 ▸ Elimina token FCM del array de Firestore y local
        final fcm   = FirebaseMessaging.instance;
        final token = await fcm.getToken();

        if (token != null) {
          await FirebaseFirestore.instance
              .doc('users/${user.uid}')
              .update({'tokens': FieldValue.arrayRemove([token])});
          await fcm.deleteToken();
        }

        // 2 ▸ Cierra sesión y presencia
        PresenceService.dispose();
        await FirebaseAuth.instance.signOut();
      }

      // 3 ▸ Redirige a WelcomeScreen limpiando historial
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
    }
  }
}
