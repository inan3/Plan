// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'explore_screen/users_managing/presence_service.dart';
import 'explore_screen/chats/chats_screen.dart';
import 'explore_screen/main_screen/explore_screen.dart';
import 'start/welcome_screen.dart';

/* ─────────────────────────────────────────────────────────
 *  FCM handler en background
 * ────────────────────────────────────────────────────────*/
@pragma('vm:entry-point')
Future<void> _firebaseBgHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/* ─────────────────────────────────────────────────────────
 *  main
 * ────────────────────────────────────────────────────────*/
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1 ▸ Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseBgHandler);

  // 2 ▸ Fecha/hora ES
  await initializeDateFormatting('es');

  // 3 ▸ Notificaciones locales (estado guardado por el usuario)
  final prefs   = await SharedPreferences.getInstance();
  final enabled = prefs.getBool('notificationsEnabled') ?? true;
  await NotificationService.instance.init(enabled: enabled);

  // 4 ▸ Presencia (si la sesión persiste)
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    PresenceService.dispose();
    await PresenceService.init(currentUser);
    await _registerFcmToken(currentUser); // asegura token único
  }

  runApp(const MyApp());
}

/* ─────────────────────────────────────────────────────────
 *  FCM ⇆ Cloud Functions (token único por usuario)
 * ────────────────────────────────────────────────────────*/
Future<void> _registerFcmToken(User user) async {
  final fcm = FirebaseMessaging.instance;
  await fcm.requestPermission();

  final token = await fcm.getToken();
  if (token != null) {
    await _callRegisterToken(token);
  }

  fcm.onTokenRefresh.listen(_callRegisterToken);
}

Future<void> _callRegisterToken(String token) async {
  final callable = FirebaseFunctions.instance.httpsCallable('registerToken');
  try {
    await callable.call(<String, dynamic>{'token': token});
  } catch (_) {
    // Silenciar: Cloud Functions puede fallar offline; se reintenta al refrescar
  }
}

/// Llamar desde tu botón «Cerrar sesión»
Future<void> signOutAndRemoveToken() async {
  final user  = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final fcm   = FirebaseMessaging.instance;
  final token = await fcm.getToken();

  if (token != null) {
    await FirebaseFirestore.instance
        .doc('users/${user.uid}')
        .update({'tokens': FieldValue.arrayRemove([token])});
    await fcm.deleteToken();
  }

  await FirebaseAuth.instance.signOut();
}

/* ─────────────────────────────────────────────────────────
 *  ROOT APP
 * ────────────────────────────────────────────────────────*/
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _sharedText;
  StreamSubscription<List<SharedMediaFile>>? _intentSub;
  bool _fcmDone = false; // evita doble registro en hot‑reload

  @override
  void initState() {
    super.initState();

    // Texto compartido (Android/iOS)
    if (!kIsWeb) {
      _intentSub = ReceiveSharingIntent.instance
          .getMediaStream()
          .listen(_onMedia, onError: (e) => debugPrint('RSI error: $e'));

      ReceiveSharingIntent.instance.getInitialMedia().then((files) {
        if (files.isNotEmpty) _onMedia(files);
        ReceiveSharingIntent.instance.reset();
      });
    }
  }

  void _onMedia(List<SharedMediaFile> files) {
    for (final f in files) {
      if (f.type == SharedMediaType.text) {
        _handleSharedText(f.path);
        break;
      }
    }
  }

  void _handleSharedText(String text) => setState(() => _sharedText = text);

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plan',
      theme: ThemeData(primarySwatch: Colors.pink),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            return const Scaffold(body: Center(child: Text('Error al inicializar Firebase')));
          }

          final user = snap.data;

          if (user != null && !_fcmDone) {
            _fcmDone = true;
            _registerFcmToken(user);
          }

          if (_sharedText != null) return ChatsScreen(sharedText: _sharedText!);

          return user == null ? const WelcomeScreen() : const ExploreScreen();
        },
      ),
    );
  }
}
