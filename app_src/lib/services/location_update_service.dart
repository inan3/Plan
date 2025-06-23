import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

/// Servicio que actualiza la ubicación del usuario cuando la app
/// entra en primer plano. Mantiene la última posición al salir.
class LocationUpdateService with WidgetsBindingObserver {
  LocationUpdateService._(this._uid);

  static LocationUpdateService? _instance;
  final String _uid;

  /// Inicializa el servicio para el usuario autenticado.
  static Future<void> init(User user) async {
    if (_instance != null && _instance!._uid == user.uid) {
      return;
    }
    _instance?._dispose();
    _instance = LocationUpdateService._(user.uid);
    await _instance!._start();
  }

  /// Limpia el observer. Llamar al cerrar sesión.
  static void dispose() => _instance?._dispose();

  Future<void> _start() async {
    WidgetsBinding.instance.addObserver(this);
    await _updateLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateLocation();
    }
  }

  Future<void> _updateLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    await FirebaseFirestore.instance.doc('users/$_uid').update({
      'latitude': position.latitude,
      'longitude': position.longitude,
    });
  }

  void _dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
