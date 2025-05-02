import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

/// Servicio singleton para gestionar la presencia en Realtime Database
/// usando `WidgetsBindingObserver` para detectar cuándo la app se va
/// al fondo (offline) o al primer plano (online).
class PresenceService with WidgetsBindingObserver {
  PresenceService._(this._uid);

  static PresenceService? _instance;
  final String _uid;

  /// Llamar una sola vez con el usuario autenticado.
  static Future<void> init(User user) async {
    // Si ya está inicializado con el mismo UID, no hacemos nada.
    // (O podrías forzar a que se cree siempre uno nuevo si lo prefieres).
    if (_instance != null && _instance!._uid == user.uid) {
      return;
    }
    // Si hay otro instance para otro UID, lo descartamos
    _instance?._dispose();

    _instance = PresenceService._(user.uid);
    await _instance!._start();
  }

  /// Limpiar el observer y la suscripción para uso en logout.
  static void dispose() => _instance?._dispose();

  late final DatabaseReference _statusRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://plan-social-app-default-rtdb.europe-west1.firebasedatabase.app',
  ).ref('status/$_uid');

  StreamSubscription<DatabaseEvent>? _connSub;

  Future<void> _start() async {
    // Registramos este servicio como observador del ciclo de vida.
    WidgetsBinding.instance.addObserver(this);

    // 1) Listener a .info/connected para re-registrar onDisconnect
    _connSub = FirebaseDatabase.instance
        .ref('.info/connected')
        .onValue
        .listen((event) async {
      final connected = event.snapshot.value == true;
      if (connected) {
        // Al reconectarse, programamos el onDisconnect
        _statusRef.onDisconnect().set({
          'online': false,
          'lastSeen': ServerValue.timestamp,
        });
        await _setOnline();
      }
    });

    // 2) Ponemos online en este momento
    await _setOnline();
  }

  /// Marcar online en la RTDB
  Future<void> _setOnline() => _statusRef.set({
        'online': true,
        'lastSeen': ServerValue.timestamp,
      });

  /// Marcar offline en la RTDB
  Future<void> _setOffline() => _statusRef.update({
        'online': false,
        'lastSeen': ServerValue.timestamp,
      });

  /// Detectamos cambios de estado de la app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Se re-abre la app o vuelve al primer plano
      _setOnline();
    } else if (state == AppLifecycleState.paused) {
      // Se va al segundo plano (opcional marcar offline inmediato)
      // Si prefieres marcar offline solo cuando se cierra bruscamente,
      // puedes comentar este _setOffline().
      _setOffline();
    } else if (state == AppLifecycleState.detached) {
      // Último ciclo antes de “matar” la app
      _setOffline();
    }
  }

  void _dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
  }
}
