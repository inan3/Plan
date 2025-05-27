//settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../menu_side_bar_screen.dart';
import 'account.dart';
import 'privacy.dart';
import 'general_notifications.dart';
import 'help_center.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _failureController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _failureController.dispose();
    super.dispose();
  }

  Future<void> _sendFailureReport() async {
    final String text = _failureController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, describe el fallo antes de enviar.')),
      );
      return;
    }

    try {
      final User? user = _auth.currentUser;
      final String uid = user?.uid ?? 'unknown';

      await _firestore.collection('appFailures').add({
        'userId': uid,
        'fail': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias por tu reporte.')),
      );
      _failureController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar el reporte: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Colors.grey.shade200;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Ajustes',
          style: TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sección: Configuración general
              const Text(
                'Configuración general',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),

              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: SvgPicture.asset(
                        'assets/usuario.svg',
                        width: 24,
                        height: 24,
                      ),
                      title: const Text('Cuenta'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AccountScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: SvgPicture.asset(
                        'assets/icono-candado.svg',
                        width: 24,
                        height: 24,
                      ),
                      title: const Text('Privacidad'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PrivacyScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: SvgPicture.asset(
                        'assets/icono-general-notifications.svg',
                        width: 24,
                        height: 24,
                      ),
                      title: const Text('Notificaciones'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const GeneralNotificationsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Sección: Soporte
              const Text(
                'Soporte',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),

              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: SvgPicture.asset(
                        'assets/icono-help-center.svg',
                        width: 24,
                        height: 24,
                      ),
                      title: const Text('Centro de ayuda'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const HelpCenterScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Image.asset(
                        'assets/plan-sin-fondo.png',
                        width: 24,
                        height: 24,
                      ),
                      title: const Text('Acerca de Plan'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final uri = Uri.parse('https://plansocialapp.es/#menu');
                        try {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        } catch (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo abrir el enlace'),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: SvgPicture.asset(
                        'assets/icono-valoration.svg',
                        width: 24,
                        height: 24,
                      ),
                      title: const Text('Valora Plan'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // TODO: Navegar a valora_plan.dart
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Contenedor de Reportar fallos de la aplicación
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SvgPicture.asset('assets/icono-reportar.svg',
                            width: 24, height: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          // <- clave
                          child: Text(
                            'Reportar fallos de la aplicación',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TextField(
                        controller: _failureController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Describe aquí el fallo...',
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _sendFailureReport,
                        child: const Text('Enviar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
