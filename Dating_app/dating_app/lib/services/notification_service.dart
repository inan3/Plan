// =========================
// lib/services/notification_service.dart
// =========================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Servicio singleton encargado de registrar el token FCM y
/// mostrar notificaciones locales (Android/iOS).
///  - Sin iconos de acción.
///  - Muestra avatar (si viene en los datos) y cuerpo de texto.
///  - Se reserva la integración con chat (TODO en _handleForeground).
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _enabled = true;

  Future<void> init({required bool enabled}) async {
    _enabled = enabled;

    // Permisos (iOS + Android 13+).
    await _messaging.requestPermission();

    // Canal de prioridad alta (Android).
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

    // Inicializa plugin de notificaciones locales.
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _fln.initialize(initSettings);

    if (!_enabled) return;

    // Guarda/actualiza token del usuario.
    final token = await _messaging.getToken();
    await _saveToken(token);
    _messaging.onTokenRefresh.listen(_saveToken);

    // Listener para mensajes en primer plano.
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // (Se puede añadir onBackgroundOpenedApp y onMessageOpenedApp si se desea.)
  }

  Future<void> enable() async {
    if (_enabled) return;
    _enabled = true;
    await init(enabled: true);
  }

  Future<void> disable() async {
    _enabled = false;
  }

  // Guarda el token FCM en el documento del usuario.
  Future<void> _saveToken(String? token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || token == null) return;
    await _firestore.collection('users').doc(user.uid).update({'fcmToken': token});
  }

  // Muestra notificación local cuando el mensaje se recibe en foreground.
  Future<void> _handleForeground(RemoteMessage msg) async {
    if (!_enabled) return;

    final data = msg.data;
    final notif = msg.notification;

    final title = notif?.title ?? data['title'] ?? 'Plan';
    final body = notif?.body ?? data['body'] ?? '';

    final androidDetails = AndroidNotificationDetails(
      'plan_high',
      'Plan – Notificaciones',
      channelDescription: 'Notificaciones push de Plan',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: const BigTextStyleInformation(''),
      largeIcon: data['avatar'] != null
          ? ByteArrayAndroidBitmap.fromBase64String(data['avatar'])
          : null,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _fln.show(msg.hashCode, title, body, details,
        payload: data['payload']);

    // TODO: integrar notificaciones de chat (usar otro canal si procede).
  }
}