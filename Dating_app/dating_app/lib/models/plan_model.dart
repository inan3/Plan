import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  DateTime? date; // Hacemos la fecha opcional para inicializar el objeto sin errores
  String createdBy;

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
  });

  /// Genera un ID único alfanumérico de 12 caracteres
  static Future<String> generateUniqueId() async {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random();
    String id;

    do {
      id = List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
    } while (await _idExistsInFirebase(id));

    return id;
  }

  /// Verifica si el ID ya existe en Firebase
  static Future<bool> _idExistsInFirebase(String id) async {
    final DocumentSnapshot snapshot =
        await FirebaseFirestore.instance.collection('plans').doc(id).get();
    return snapshot.exists;
  }

  /// Convierte el modelo a un mapa para guardar en Firebase
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
      'date': date?.toIso8601String(), // Maneja el caso donde date sea null
      'createdBy': createdBy,
    };
  }

  /// Crea un modelo desde un mapa
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
    );
  }
}
