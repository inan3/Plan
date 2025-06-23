import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../start/welcome_screen.dart';
import '../users_managing/presence_service.dart';
import '../../services/location_update_service.dart';

class CloseSessionScreen extends StatefulWidget {
  const CloseSessionScreen({super.key});

  @override
  State<CloseSessionScreen> createState() => _CloseSessionScreenState();
}

class _CloseSessionScreenState extends State<CloseSessionScreen> {
  @override
  void initState() {
    super.initState();
    _logout();
  }

  Future<void> _logout() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final fcm = FirebaseMessaging.instance;
        final token = await fcm.getToken();

        if (token != null) {
          await FirebaseFirestore.instance.doc('users/${user.uid}').update({
            'tokens': FieldValue.arrayRemove([token])
          });
          // NO borres el token del dispositivo:
          // await fcm.deleteToken();
        }

        PresenceService.dispose(); // sin await
        LocationUpdateService.dispose();
        await FirebaseAuth.instance.signOut();
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
