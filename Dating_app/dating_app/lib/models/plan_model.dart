import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importa FirebaseAuth para autenticación

class PlanModel {
  String id;
  String type;
  String description;
  int minAge;
  int maxAge;
  int? maxParticipants;
  String location;
  double? latitude;
  double? longitude;
  DateTime? date; // Fecha del evento
  String createdBy; // ID del usuario que crea el plan
  String? creatorName; // Nombre del creador del plan
  String? creatorProfilePic; // Foto de perfil del creador
  DateTime? createdAt; // Fecha y hora de creación del plan

  PlanModel({
    required this.id,
    required this.type,
    required this.description,
    required this.minAge,
    required this.maxAge,
    this.maxParticipants,
    required this.location,
    this.latitude,
    this.longitude,
    this.date,
    required this.createdBy,
    this.creatorName,
    this.creatorProfilePic,
    this.createdAt,
  });

  static Future<String> generateUniqueId() async {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random();
    String id;

    do {
      id = List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
    } while (await _idExistsInFirebase(id));

    return id;
  }

  static Future<bool> _idExistsInFirebase(String id) async {
    final DocumentSnapshot snapshot =
        await FirebaseFirestore.instance.collection('plans').doc(id).get();
    return snapshot.exists;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'description': description,
      'minAge': minAge,
      'maxAge': maxAge,
      'maxParticipants': maxParticipants,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'date': date?.toIso8601String(),
      'createdBy': createdBy,
      'creatorName': creatorName,
      'creatorProfilePic': creatorProfilePic,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  String formattedDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  factory PlanModel.fromMap(Map<String, dynamic> map) {
    return PlanModel(
      id: map['id'] as String,
      type: map['type'] as String,
      description: map['description'] as String,
      minAge: map['minAge'] as int,
      maxAge: map['maxAge'] as int,
      maxParticipants: map['maxParticipants'] != null ? map['maxParticipants'] as int : null,
      location: map['location'] as String,
      latitude: map['latitude'] != null ? map['latitude'] as double : null,
      longitude: map['longitude'] != null ? map['longitude'] as double : null,
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : null,
      createdBy: map['createdBy'] as String,
      creatorName: map['creatorName'] as String?,
      creatorProfilePic: map['creatorProfilePic'] as String?,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : null,
    );
  }

  static Future<PlanModel> createPlan({
    required String type,
    required String description,
    required int minAge,
    required int maxAge,
    String? location,
    double? latitude,
    double? longitude,
    DateTime? date,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("Usuario no autenticado");
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data();

    if (userData == null) {
      throw Exception("No se encontraron datos del usuario");
    }

    final plan = PlanModel(
      id: await generateUniqueId(),
      type: type,
      description: description,
      minAge: minAge,
      maxAge: maxAge,
      location: location ?? '',
      latitude: latitude,
      longitude: longitude,
      date: date,
      createdBy: user.uid,
      creatorName: userData['name'],
      creatorProfilePic: userData['profilePic'],
      createdAt: DateTime.now(),
    );

    await FirebaseFirestore.instance.collection('plans').doc(plan.id).set(plan.toMap());
    return plan;
  }
}
