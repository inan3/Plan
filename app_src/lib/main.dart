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

import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'services/language_service.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/fcm_token_service.dart';
import 'explore_screen/users_managing/presence_service.dart';
import 'services/location_update_service.dart';
import 'explore_screen/chats/chats_screen.dart';
import 'explore_screen/main_screen/explore_screen.dart';
import 'start/welcome_screen.dart';
import 'start/registration/user_registration_screen.dart';
import 'start/registration/verification_provider.dart';
import 'start/registration/local_registration_service.dart';

import 'services/update_service.dart';
import 'models/plan_model.dart';
import 'explore_screen/users_managing/user_info_check.dart';
import 'package:app_links/app_links.dart';
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
  await LanguageService.loadLocale();

  // 4 ▸ Limpiar registro pendiente (sin cerrar sesión)
  final (provider, _, __) = await LocalRegistrationService.getPending();
  if (provider != null) {
    await LocalRegistrationService.clear();
    await signOutAndRemoveToken();
  }

  // 5 ▸ Mostrar notificaciones en foreground
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  FirebaseMessaging.onMessage.listen(NotificationService.instance.show);

  // 6 ▸ Presencia, ubicación y token si hay sesión persistente
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    PresenceService.dispose();
    await PresenceService.init(user);
    await LocationUpdateService.init(user);
    await FcmTokenService.register(user);
  }

  runApp(const MyApp());
}

/* ─────────────────────────────────────────────────────────
 *  FCM ⇆ Firestore (token único por dispositivo)
 * ────────────────────────────────────────────────────────*/

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
  // Stop presence updates for the current user before signing out.
  PresenceService.dispose();
  LocationUpdateService.dispose();
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _sharedText;
  StreamSubscription<List<SharedMediaFile>>? _intentSub;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription? _linkSub;
  Uri? _initialUri;
  String? _lastUid; // detecta cambio de usuario

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      _intentSub = ReceiveSharingIntent.instance
          .getMediaStream()
          .listen(_onMedia);

      ReceiveSharingIntent.instance.getInitialMedia().then((files) {
        if (files.isNotEmpty) _onMedia(files);
        ReceiveSharingIntent.instance.reset();
      });
    }

    _initDeepLinks();
  }

  void _onMedia(List<SharedMediaFile> files) {
    for (final f in files) {
      if (f.type == SharedMediaType.text) {
        setState(() => _sharedText = f.path);
        break;
      }
    }
  }

  void _initDeepLinks() async {
    try {
      _initialUri = await _appLinks.getInitialAppLink();
      if (_initialUri != null) _handleUri(_initialUri!);
    } catch (_) {}

    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      if (uri != null) _handleUri(uri);
    }, onError: (_) {});
  }

  Future<void> _handleUri(Uri uri) async {
    if (uri.path == '/plan') {
      final planId = uri.queryParameters['planId'];
      if (planId != null && planId.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        final doc = await FirebaseFirestore.instance
            .collection('plans')
            .doc(planId)
            .get();
        if (!doc.exists) return;
        final data = doc.data()!..['id'] = planId;
        final plan = PlanModel.fromMap(data);
        UserInfoCheck.open(
          _navigatorKey.currentContext!,
          plan.createdBy,
          planId: planId,
        );
      }
    }
  }



  @override
  void dispose() {
    _intentSub?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LanguageService.locale,
      builder: (context, locale, _) {
        return ForceUpdateGuard(
          navigatorKey: _navigatorKey,
          child: MaterialApp(
            navigatorKey: _navigatorKey,
            locale: locale,
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            title: 'Plan',
            theme: ThemeData(primarySwatch: Colors.pink),
            // Always start at WelcomeScreen. It handles auth changes internally.
            // This ensures that every app launch shows the welcome screen first.
            home: const WelcomeScreen(),
          ),
        );
      },
    );
  }
}
