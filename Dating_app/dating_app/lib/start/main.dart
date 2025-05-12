// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../../explore_screen/users_managing/presence_service.dart';

import '../explore_screen/chats/chats_screen.dart';
import 'welcome_screen.dart';
import 'plan_detail_screen.dart';   // deep-link

// ───────────────────────────────────────────────────────────────────────────
//  HANDLER FCM EN 2º PLANO / APP CERRADA
// ───────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')           // necesario en Flutter 3.16+
Future<void> _firebaseBgHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Aquí solo registramos llegada para debug.
  // Si envías mensajes tipo “data” y quieres mostrarlos tú mismo,
  // llama a NotificationService.instance.showFromRemote(message);
  debugPrint('📩 (BG) mensaje: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1- Firebase
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseBgHandler);

  // 2- Localización ES
  await initializeDateFormatting('es', null);

  // 3- Permiso y token FCM
  final fcm = FirebaseMessaging.instance;
  final perm = await fcm.requestPermission();
  debugPrint('🔔 permiso notificaciones: ${perm.authorizationStatus}');
  final token = await fcm.getToken();
  debugPrint('🔑 FCM token: $token');

  // 4- Preferencia + registro en nuestro servicio
  final prefs   = await SharedPreferences.getInstance();
  final enabled = prefs.getBool('notificationsEnabled') ?? true;
  await NotificationService.instance.init(enabled: enabled);

  // 5- Servicio de presencia (si ya hay usuario)
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    PresenceService.dispose();
    await PresenceService.init(currentUser);
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _sharedText;
  String? _initialPlanId;

  @override
  void initState() {
    super.initState();

    // A- planId vía query-param (web / dynamic link)
    _initialPlanId = Uri.base.queryParameters['planId'];

    // B- texto compartido (Android/iOS)
    if (!kIsWeb) {
      ReceiveSharingIntent.getTextStream()
          .listen(_handleSharedText, onError: (e) => debugPrint('RSI error: $e'));
      ReceiveSharingIntent.getInitialText()
          .then((v) => v != null ? _handleSharedText(v) : null);
    }
  }

  void _handleSharedText(String text) => setState(() => _sharedText = text);

  // Firebase Auth tarda un poco en leer la sesión
  Future<User?> _getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return FirebaseAuth.instance.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plan Social',
      theme: ThemeData(primarySwatch: Colors.pink),
      home: FutureBuilder<User?>(
        future: _getCurrentUser(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            return const Scaffold(body: Center(child: Text('Error al inicializar Firebase')));
          }

          final user = snap.data;

          if (_initialPlanId != null)            // deep-link a plan
            return PlanDetailScreen(planId: _initialPlanId!);

          if (_sharedText != null)               // texto compartido
            return ChatsScreen(sharedText: _sharedText);

          if (user == null || !user.emailVerified)
            return const WelcomeScreen();        // flujo auth

          return const MainAppScreen();          // dentro de la app
        },
      ),
    );
  }
}

// Placeholder pantalla principal
class MainAppScreen extends StatelessWidget {
  const MainAppScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Pantalla principal de la app')));
}
