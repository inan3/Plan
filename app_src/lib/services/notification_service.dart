/* ─────────────────────────────────────────────────────────
 *  lib/services/notification_service.dart
 *  Servicio singleton para notificaciones push + locales
 * ────────────────────────────────────────────────────────*/
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _enabled = true;

  /* ────────────────────────────────────────────────────────
   *  Init – debe llamarse una sola vez tras Firebase.initializeApp()
   * ────────────────────────────────────────────────────────*/
  Future<void> init({required bool enabled}) async {
    _enabled = enabled;

    /* 1 ▸ Permisos (iOS + Android 13) */
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized) return;

    /* 2 ▸ Canal de prioridad alta (Android) */
    const channel = AndroidNotificationChannel(
      'plan_high',
      'Plan – Notificaciones',
      description: 'Notificaciones push de Plan',
      importance: Importance.high,
    );
    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    /* 3 ▸ Configuración inicial del plugin */
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _fln.initialize(initSettings);

    if (!_enabled) return;

    /* 4 ▸ Mostrar notificaciones en foreground */
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    /* 5 ▸ Guardar/actualizar token */
    final token = await _messaging.getToken();
    await _saveToken(token);
    _messaging.onTokenRefresh.listen(_saveToken);

    /* 6 ▸ Listener foreground */
    FirebaseMessaging.onMessage.listen(show);
  }

  Future<void> enable() async {
    if (_enabled) return;
    _enabled = true;
    await init(enabled: true);
  }

  Future<void> disable() async => _enabled = false;

  /*  Expuesto para poder usarlo fuera si se desea */
  Future<void> show(RemoteMessage msg) async {
    if (!_enabled) return;
    await _showLocal(msg);
  }

  /* Guarda el token en array `tokens` (multi-dispositivo) */
  Future<void> _saveToken(String? token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || token == null) return;
    await _firestore.doc('users/${user.uid}').set({
      'tokens': FieldValue.arrayUnion([token])
    }, SetOptions(merge: true));
  }

  /* Muestra notificación local en foreground */
  Future<void> _showLocal(RemoteMessage msg) async {
    final data  = msg.data;
    final notif = msg.notification;

    final title = notif?.title ?? data['title'] ?? 'Plan';
    final body  = notif?.body  ?? data['body']  ?? '';

    final largeIcon = (data['avatar'] is String)
        ? ByteArrayAndroidBitmap.fromBase64String(data['avatar'] as String)
        : null;

    final androidDetails = AndroidNotificationDetails(
      'plan_high',
      'Plan – Notificaciones',
      channelDescription: 'Notificaciones push de Plan',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: const BigTextStyleInformation(''),
      largeIcon: largeIcon,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _fln.show(msg.hashCode, title, body, details,
        payload: data['payload']);
  }
}