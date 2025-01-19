import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseHelpers {
  static void createNewPlan(
    BuildContext context, {
    required String type,
    required String theme,
    required String description,
    int? maxParticipants,
    int? minAge,
    int? maxAge,
    required String genderRestriction,
    required LatLng location,
    required String address,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para crear un plan.')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('plans').add({
        'type': type,
        'theme': theme,
        'description': description,
        'maxParticipants': maxParticipants,
        'minAge': minAge,
        'maxAge': maxAge,
        'genderRestriction': genderRestriction,
        'location': {
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
        'address': address,
        'creatorId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan creado exitosamente.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al crear el plan.')),
      );
    }
  }
}
