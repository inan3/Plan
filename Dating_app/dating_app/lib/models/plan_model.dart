// plan_model.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlanModel {
  // Campos principales
  String id;
  String type;
  String description;
  int minAge;
  int maxAge;
  int? maxParticipants;
  String location;
  double? latitude;
  double? longitude;

  // Usamos dos campos en vez de 'date'
  DateTime? startTimestamp;
  DateTime? finishTimestamp;

  String createdBy;
  String? creatorName;
  String? creatorProfilePic;
  DateTime? createdAt;

  // (Opcional) Si antes usabas solo 1 imagen
  String? backgroundImage;

  String? visibility;
  String? iconAsset;
  List<String>? participants;
  int likes;
  int special_plan;

  // Array con varias URLs de imágenes (baja/media resolución)
  List<String>? images;

  // Array con varias URLs de imágenes en resolución original
  List<String>? originalImages;

  // Campo con la URL del video (si se subió)
  String? videoUrl;

  // NUEVO: si quieres almacenar la privacidad del creador en el plan
  // (0 = público, 1 = privado). Esto es opcional.
  int? creatorProfilePrivacy;

  // Constructor
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
    this.startTimestamp,
    this.finishTimestamp,
    required this.createdBy,
    this.creatorName,
    this.creatorProfilePic,
    this.createdAt,
    this.backgroundImage,
    this.visibility,
    this.iconAsset,
    this.participants,
    this.likes = 0,
    this.special_plan = 0,
    this.images,
    this.originalImages,
    this.videoUrl,
    // Nuevo
    this.creatorProfilePrivacy,
  });

  // Genera un ID único de 10 caracteres alfanuméricos
  static Future<String> generateUniqueId() async {
    const String chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random();
    String id;
    do {
      id = List.generate(10, (index) => chars[random.nextInt(chars.length)])
          .join();
    } while (await _idExistsInFirebase(id));
    return id;
  }

  static Future<bool> _idExistsInFirebase(String id) async {
    final DocumentSnapshot snapshot =
        await FirebaseFirestore.instance.collection('plans').doc(id).get();
    return snapshot.exists;
  }

  // Convierte este objeto a Map para guardar en Firestore
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
      'start_timestamp': startTimestamp != null
          ? Timestamp.fromDate(startTimestamp!)
          : null,
      'finish_timestamp': finishTimestamp != null
          ? Timestamp.fromDate(finishTimestamp!)
          : null,
      'createdBy': createdBy,
      'creatorName': creatorName,
      'creatorProfilePic': creatorProfilePic,
      'createdAt': createdAt?.toIso8601String(),
      'backgroundImage': backgroundImage,
      'visibility': visibility,
      'iconAsset': iconAsset,
      'participants': participants ?? [],
      'likes': likes,
      'special_plan': special_plan,
      // Nuevos campos
      'images': images ?? [],
      'originalImages': originalImages ?? [],
      'videoUrl': videoUrl ?? '',
      'creatorProfilePrivacy': creatorProfilePrivacy ?? 0,
    };
  }

  // Crea un objeto PlanModel a partir de un Map (documento Firestore)
  factory PlanModel.fromMap(Map<String, dynamic> map) {
    return PlanModel(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      description: map['description'] ?? '',
      minAge: map['minAge'] ?? 0,
      maxAge: map['maxAge'] ?? 99,
      maxParticipants: map['maxParticipants'],
      location: map['location'] ?? '',
      latitude: _parseDouble(map['latitude']),
      longitude: _parseDouble(map['longitude']),
      startTimestamp: map['start_timestamp'] != null
          ? (map['start_timestamp'] as Timestamp).toDate()
          : null,
      finishTimestamp: map['finish_timestamp'] != null
          ? (map['finish_timestamp'] as Timestamp).toDate()
          : null,
      createdBy: map['createdBy'] ?? '',
      creatorName: map['creatorName'],
      creatorProfilePic: map['creatorProfilePic'],
      createdAt: _parseDate(map['createdAt']),
      backgroundImage: map['backgroundImage'],
      visibility: map['visibility'],
      iconAsset: map['iconAsset'],
      participants: map['participants'] != null
          ? List<String>.from(map['participants'] as List)
          : <String>[],
      likes: map['likes'] ?? 0,
      special_plan: map['special_plan'] ?? 0,
      images: map['images'] != null
          ? List<String>.from(map['images'] as List)
          : <String>[],
      originalImages: map['originalImages'] != null
          ? List<String>.from(map['originalImages'] as List)
          : <String>[],
      videoUrl: map['videoUrl'] ?? '',
      creatorProfilePrivacy: map['creatorProfilePrivacy'] ?? 0,
    );
  }

  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val);
    }
    return null;
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) {
      return val.toDate();
    }
    if (val is String) {
      return DateTime.tryParse(val);
    }
    return null;
  }

  // Método auxiliar para formatear fechas en tu UI
  String formattedDate(DateTime? d) {
    if (d == null) return 'Sin fecha';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  // Crea y guarda un plan en Firestore
  static Future<PlanModel> createPlan({
    required String type,
    required String description,
    required int minAge,
    required int maxAge,
    int? maxParticipants,
    required String location,
    double? latitude,
    double? longitude,
    required DateTime startTimestamp,
    required DateTime finishTimestamp,
    String? backgroundImage,
    String? visibility,
    String? iconAsset,
    int special_plan = 0,
    // Par de campos nuevos para el array de imágenes y el video
    List<String>? images,
    List<String>? originalImages,
    String? videoUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Usuario no autenticado");
    }

    // Datos del usuario que crea el plan
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    final userData = userDoc.data();
    if (userData == null) {
      throw Exception("No se encontraron datos del usuario");
    }

    // Genera un ID único de 10 caracteres
    final String uniqueId = await generateUniqueId();

    // Leemos también la privacidad del creador (0 o 1)
    final int? privacy = userData['profile_privacy'] is int
        ? userData['profile_privacy'] as int
        : 0;

    // Construimos el plan con todos los campos
    final plan = PlanModel(
      id: uniqueId,
      type: type,
      description: description,
      minAge: minAge,
      maxAge: maxAge,
      maxParticipants: maxParticipants,
      location: location,
      latitude: latitude,
      longitude: longitude,
      startTimestamp: startTimestamp,
      finishTimestamp: finishTimestamp,
      createdBy: user.uid,
      creatorName: userData['name'],
      creatorProfilePic: userData['profilePic'],
      createdAt: DateTime.now(),
      backgroundImage: backgroundImage,
      visibility: visibility,
      iconAsset: iconAsset,
      participants: [],
      likes: 0,
      special_plan: special_plan,
      images: images ?? [],
      originalImages: originalImages ?? [],
      videoUrl: videoUrl ?? '',
      creatorProfilePrivacy: privacy,
    );

    // Guardar en la colección 'plans' (se crea un doc con ID = uniqueId)
    await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .set(plan.toMap());

    // Actualiza el campo 'total_created_plans' del usuario creador
    await userRef.update({
      'total_created_plans': FieldValue.increment(1),
    });

    return plan;
  }
}
