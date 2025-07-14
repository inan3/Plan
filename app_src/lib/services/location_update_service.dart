import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

/// Servicio que actualiza la ubicación del usuario cuando la app
/// entra en primer plano. Mantiene la última posición al salir.
class LocationUpdateService with WidgetsBindingObserver {
  LocationUpdateService._(this._uid);

  final GeoFlutterFire _geo = GeoFlutterFire();
  final CollectionReference _locRef =
      FirebaseFirestore.instance.collection('locations');

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

    final point =
        _geo.point(latitude: position.latitude, longitude: position.longitude);

    await _locRef.doc(_uid).set({
      'position': point.data,
      'accuracy': position.accuracy,
      'updatedAt': FieldValue.serverTimestamp(),
      'expireAt': DateTime.now().add(const Duration(hours: 8)),
    });

    await FirebaseFirestore.instance.doc('users/$_uid').update({
      'latitude': position.latitude,
      'longitude': position.longitude,
    });
  }

  void _dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
