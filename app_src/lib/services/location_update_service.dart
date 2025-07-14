import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

/// Servicio que actualiza la ubicación del usuario.
class LocationUpdateService with WidgetsBindingObserver {
  LocationUpdateService._(this._uid);

  final CollectionReference _locRef =
      FirebaseFirestore.instance.collection('locations');

  static LocationUpdateService? _instance;
  final String _uid;

  /// Inicializa el servicio para el usuario autenticado.
  static Future<void> init(User user) async {
    if (_instance != null && _instance!._uid == user.uid) return;
    _instance?._dispose();
    _instance = LocationUpdateService._(user.uid);
    await _instance!._start();
  }

  /// Limpia el observer.
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
    if (!await Geolocator.isLocationServiceEnabled()) return;

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

    final geoPoint =
        GeoFirePoint(GeoPoint(position.latitude, position.longitude));

    // Obtener la foto de perfil del usuario para almacenarla junto a la ubicación
    final uDoc =
        await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    final photoUrl = (uDoc.data() as Map<String, dynamic>?)?['photoUrl'];

    await _locRef.doc(_uid).set({
      'position': geoPoint.data,
      'accuracy': position.accuracy,
      'updatedAt': FieldValue.serverTimestamp(),
      'expireAt': DateTime.now().add(const Duration(hours: 8)),
      if (photoUrl != null) 'photoUrl': photoUrl,
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
