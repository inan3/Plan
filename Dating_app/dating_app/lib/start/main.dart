// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/date_symbol_data_local.dart'; // <-- Importante para inicializar localización

// Paquete para leer el Intent ACTION_SEND
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

// (1) IMPORTA EL SERVICIO DE PRESENCIA (ajusta la ruta a tu carpeta real)
import '../../explore_screen/users_managing/presence_service.dart';

import 'chats_screen.dart';
import 'welcome_screen.dart';
import 'plan_detail_screen.dart';
import 'models/plan_model.dart';
// import 'firebase_options.dart'; // Si usas FlutterFire

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase
  await Firebase.initializeApp();
  // (2) Si ya hay un usuario autenticado, inicializa el servicio de presencia
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    PresenceService.dispose();
    await PresenceService.init(user);
  }

  // Inicializa la localización para español
  await initializeDateFormatting('es', null);
  print('⚙️ Firebase DatabaseURL: ${Firebase.app().options.databaseURL}');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _sharedText; // Contendrá el texto (enlace) que recibimos
  String? _initialPlanId; // Para deep link, si lo usas

  @override
  void initState() {
    super.initState();

    // 1) Lee planId de la URL en caso de web o deep link
    final Uri uri = Uri.base;
    final String? planId = uri.queryParameters['planId'];
    _initialPlanId = planId;

    // 2) Configurar receive_sharing_intent en Android/iOS
    if (!kIsWeb) {
      // App en 1er plano
      ReceiveSharingIntent.getTextStream().listen((String value) {
        debugPrint("Texto compartido (foreground): $value");
        _handleSharedText(value);
      }, onError: (err) {
        debugPrint("Error getTextStream: $err");
      });

      // App en “cold start”
      ReceiveSharingIntent.getInitialText().then((String? value) {
        if (value != null) {
          debugPrint("Texto compartido (initial): $value");
          _handleSharedText(value);
        }
      });
    }
  }

  void _handleSharedText(String text) {
    setState(() {
      _sharedText = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plan Social',
      theme: ThemeData(primarySwatch: Colors.pink),
      home: FutureBuilder<User?>(
        future: _getCurrentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text('Error al inicializar Firebase')),
            );
          }
          final user = snapshot.data;

          // A) Si hay planId en la URL, mostramos la pantalla de detalles (opcional)
          if (_initialPlanId != null) {
            return PlanDetailScreen(planId: _initialPlanId!);
          }
          // B) Si recibimos texto compartido, abre ChatsScreen
          else if (_sharedText != null) {
            return ChatsScreen(sharedText: _sharedText);
          }
          // C) Flujo normal: revisa auth
          else {
            if (user == null) {
              return const WelcomeScreen();
            }
            // Si tu app requiere verificación de email
            else if (!user.emailVerified) {
              FirebaseAuth.instance.signOut();
              return const WelcomeScreen();
            } else {
              // Si ya está logueado, mostrará la pantalla principal
              return const MainAppScreen();
            }
          }
        },
      ),
    );
  }

  Future<User?> _getCurrentUser() async {
    // Pequeña pausa para que Firebase Auth tenga tiempo de leer info
    await Future.delayed(const Duration(milliseconds: 300));
    return FirebaseAuth.instance.currentUser;
  }
}

// Asegúrate de tener tu pantalla principal:
class MainAppScreen extends StatelessWidget {
  const MainAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Implementa tu pantalla principal
    return const Scaffold(
      body: Center(
        child: Text('Pantalla principal de la app'),
      ),
    );
  }
}
