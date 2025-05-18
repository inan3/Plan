/* ─────────────────────────────────────────────────────────
 *  lib/main.dart  ·  versión con FCM completamente operativa
 * ────────────────────────────────────────────────────────*/
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  /* ─── NUEVO ─── mostrar notificaciones cuando la app está en primer plano */
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, badge: true, sound: true,
  );
  FirebaseMessaging.onMessage.listen(NotificationService.instance.show);

  // 4 ▸ Presencia (si la sesión persiste)
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    PresenceService.dispose();
    await PresenceService.init(currentUser);
    await _registerFcmToken(currentUser); // asegura token único POR dispositivo
  }

  runApp(const MyApp());
}

/* ─────────────────────────────────────────────────────────
 *  FCM ⇆ Firestore (token único por dispositivo, multi‑dispositivo soportado)
 * ────────────────────────────────────────────────────────*/
Future<void> _registerFcmToken(User user) async {
  final fcm = FirebaseMessaging.instance;

  // Solicita permisos (iOS + Android ≥ 13)
  final settings = await fcm.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );
  if (settings.authorizationStatus != AuthorizationStatus.authorized) return;

 // Guarda el token garantizando que no quede asociado a otros usuarios
  Future<void> _save(String token) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // 1 ▸ Remove token from any other user
    final q = await db
        .collection('users')
        .where('tokens', arrayContains: token)
        .get();
    for (final doc in q.docs) {
      if (doc.id != user.uid) {
        batch.update(doc.reference, {
          'tokens': FieldValue.arrayRemove([token])
        });
      }
    }

    // 2 ▸ Add token to current user
    batch.set(
      db.doc('users/${user.uid}'),
      {'tokens': FieldValue.arrayUnion([token])},
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  final token = await fcm.getToken();
  if (token != null) await _save(token);

  // Se dispara cuando el sistema renueva el token
  fcm.onTokenRefresh.listen(_save);
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
  String? _fcmUserId; // para registrar token solo cuando cambia el usuario

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

          if (user != null) {
            if (_fcmUserId != user.uid) {
              _fcmUserId = user.uid;
              _registerFcmToken(user); // se registra si el usuario cambió
            }
          } else {
            _fcmUserId = null; // resetea para próximas sesiones
          }

          if (_sharedText != null) return ChatsScreen(sharedText: _sharedText!);

          return user == null ? const WelcomeScreen() : const ExploreScreen();
        },
      ),
    );
  }
}
