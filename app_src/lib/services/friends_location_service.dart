import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FriendsLocationService {
  final _geo = GeoFlutterFire();
  final _db = FirebaseFirestore.instance;

  Stream<List<DocumentSnapshot>> watchFriends(LatLng center, double radiusKm) {
    final point =
        _geo.point(latitude: center.latitude, longitude: center.longitude);
    return _geo
        .collection(collectionRef: _db.collection('locations'))
        .within(center: point, radius: radiusKm, field: 'position');
  }
}
