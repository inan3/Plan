/* ─────────────────────────────────────────────────────────
 *  lib/main.dart  ·  FCM multi-usuario / multi-dispositivo
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
 *  Handler FCM en background
 * ────────────────────────────────────────────────────────*/
@pragma('vm:entry-point')
Future<void> _firebaseBgHandler(RemoteMessage msg) async {
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

  // 2 ▸ Fechas ES
  await initializeDateFormatting('es');

  // 3 ▸ Notificaciones locales (estado guardado)
  final prefs = await SharedPreferences.getInstance();
  final enabled = prefs.getBool('notificationsEnabled') ?? true;
  await NotificationService.instance.init(enabled: enabled);

  // 4 ▸ Mostrar notificaciones en foreground
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  FirebaseMessaging.onMessage.listen(NotificationService.instance.show);

  // 5 ▸ Presencia + token si hay sesión persistente
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    PresenceService.dispose();
    await PresenceService.init(user);
    await _registerFcmToken(user);
  }

  runApp(const MyApp());
}

/* ─────────────────────────────────────────────────────────
 *  FCM ⇆ Firestore (token único por dispositivo)
 * ────────────────────────────────────────────────────────*/
Future<void> _registerFcmToken(User user) async {
  final fcm = FirebaseMessaging.instance;

  final perm = await fcm.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );
  if (perm.authorizationStatus != AuthorizationStatus.authorized) return;

  Future<void> _save(String token) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // eliminar de otros usuarios
    final q = await db
        .collection('users')
        .where('tokens', arrayContains: token)
        .get();
    for (final d in q.docs) {
      if (d.id != user.uid) {
        batch.update(d.reference, {
          'tokens': FieldValue.arrayRemove([token])
        });
      }
    }

    // añadir al usuario actual
    batch.set(
        db.doc('users/${user.uid}'),
        {
          'tokens': FieldValue.arrayUnion([token])
        },
        SetOptions(merge: true));

    await batch.commit();
  }

  String? token = await fcm.getToken();
  token ??= await fcm.onTokenRefresh.first;
  await _save(token);

  fcm.onTokenRefresh.listen(_save);
}

/* ─────────────────────────────────────────────────────────
 *  Logout helper (sin borrar token local)
 * ────────────────────────────────────────────────────────*/
Future<void> signOutAndRemoveToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final fcm = FirebaseMessaging.instance;
  final token = await fcm.getToken();
  if (token != null) {
    await FirebaseFirestore.instance.doc('users/${user.uid}').update({
      'tokens': FieldValue.arrayRemove([token])
    });
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
  String? _lastUid; // detecta cambio de usuario

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      _intentSub = ReceiveSharingIntent.instance
          .getMediaStream()
          .listen(_onMedia); // ← ahora devuelve StreamSubscription

      ReceiveSharingIntent.instance.getInitialMedia().then((files) {
        if (files.isNotEmpty) _onMedia(files);
        ReceiveSharingIntent.instance.reset();
      });
    }
  }

  void _onMedia(List<SharedMediaFile> files) {
    for (final f in files) {
      if (f.type == SharedMediaType.text) {
        setState(() => _sharedText = f.path);
        break;
      }
    }
  }

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
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            return const Scaffold(body: Center(child: Text('Error Firebase')));
          }

          final user = snap.data;

          // ── cambia de usuario ───────────────────────────────
          if (user != null && user.uid != _lastUid) {
            _lastUid = user.uid;

            SharedPreferences.getInstance().then((prefs) {
              final enabled = prefs.getBool('notificationsEnabled') ?? true;
              NotificationService.instance.init(enabled: enabled);
            });

            _registerFcmToken(user);
          }

          if (_sharedText != null) {
            return ChatsScreen(sharedText: _sharedText!);
          }

          return user == null ? const WelcomeScreen() : const ExploreScreen();
        },
      ),
    );
  }
}
