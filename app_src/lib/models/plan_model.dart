//plan_model.dart
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

  // Fechas de inicio y fin
  DateTime? startTimestamp;
  DateTime? finishTimestamp;

  // Creador
  String createdBy;
  String? creatorName;
  String? creatorProfilePic;
  DateTime? createdAt;

  // Imagen principal (opcional)
  String? backgroundImage;

  // Visibilidad
  String? visibility;
  String? iconAsset;
  List<String>? participants;
  List<String>? removedParticipants;
  List<String>? invitedUsers;
  int likes;
  int special_plan;
  int views;
  List<String>? viewedBy;
  int share_count;

  // Varias imágenes + video
  List<String>? images;
  List<String>? originalImages;
  String? videoUrl;

  // Privacidad del perfil del creador
  int? creatorProfilePrivacy;

  // Campo para búsquedas case-insensitive por tipo
  String? typeLowercase;

  // -----------------------------
  //  Campos Check-in
  // -----------------------------
  bool? checkInActive;
  String? checkInCode;
  DateTime? checkInCodeTimestamp;
  List<String>? checkedInUsers;

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
    this.removedParticipants,
    this.likes = 0,
    this.special_plan = 0,
    this.views = 0,
    this.share_count = 0,
    this.viewedBy,
    this.images,
    this.originalImages,
    this.videoUrl,
    this.creatorProfilePrivacy,
    this.invitedUsers,

    // Campo nuevo
    this.typeLowercase,

    // Check-in
    this.checkInActive,
    this.checkInCode,
    this.checkInCodeTimestamp,
    this.checkedInUsers,
  });

  static Future<String> generateUniqueId() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    String id;
    do {
      id = List.generate(10, (index) => chars[random.nextInt(chars.length)]).join();
    } while (await _idExistsInFirebase(id));
    return id;
  }

  static Future<bool> _idExistsInFirebase(String id) async {
    final doc = await FirebaseFirestore.instance.collection('plans').doc(id).get();
    return doc.exists;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'typeLowercase': typeLowercase ?? '',
      'description': description,
      'minAge': minAge,
      'maxAge': maxAge,
      'maxParticipants': maxParticipants,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'start_timestamp':
          startTimestamp != null ? Timestamp.fromDate(startTimestamp!) : null,
      'finish_timestamp':
          finishTimestamp != null ? Timestamp.fromDate(finishTimestamp!) : null,
      'createdBy': createdBy,
      'creatorName': creatorName,
      'creatorProfilePic': creatorProfilePic,
      'createdAt': createdAt?.toIso8601String(),
      'backgroundImage': backgroundImage,
      'visibility': visibility,
      'iconAsset': iconAsset,
      'participants': participants ?? [],
      'removedParticipants': removedParticipants ?? [],
      'invitedUsers': invitedUsers ?? [],
      'likes': likes,
      'special_plan': special_plan,
      'views': views,
      'share_count': share_count,
      'viewedBy': viewedBy ?? [],
      'images': images ?? [],
      'originalImages': originalImages ?? [],
      'videoUrl': videoUrl ?? '',
      'creatorProfilePrivacy': creatorProfilePrivacy ?? 0,

      // Check-in
      'checkInActive': checkInActive ?? false,
      'checkInCode': checkInCode ?? '',
      'checkInCodeTimestamp': checkInCodeTimestamp != null
          ? Timestamp.fromDate(checkInCodeTimestamp!)
          : null,
      'checkedInUsers': checkedInUsers ?? [],
    };
  }

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
          : _parseDate(map['date']),
      finishTimestamp: map['finish_timestamp'] != null
          ? (map['finish_timestamp'] as Timestamp).toDate()
          : _parseDate(map['finish_date']),
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
      removedParticipants: map['removedParticipants'] != null
          ? List<String>.from(map['removedParticipants'] as List)
          : <String>[],
      invitedUsers: map['invitedUsers'] != null
          ? List<String>.from(map['invitedUsers'] as List)
          : <String>[],
      likes: map['likes'] ?? 0,
      special_plan: map['special_plan'] ?? 0,
      views: map['views'] ?? 0,
      share_count: map['share_count'] ?? 0,
      viewedBy: map['viewedBy'] != null
          ? List<String>.from(map['viewedBy'] as List)
          : <String>[],
      images: map['images'] != null
          ? List<String>.from(map['images'] as List)
          : <String>[],
      originalImages: map['originalImages'] != null
          ? List<String>.from(map['originalImages'] as List)
          : <String>[],
      videoUrl: map['videoUrl'] ?? '',
      creatorProfilePrivacy: map['creatorProfilePrivacy'] ?? 0,

      // Campo para búsqueda case-insensitive
      typeLowercase: map['typeLowercase'] ?? '',

      checkInActive: map['checkInActive'] ?? false,
      checkInCode: map['checkInCode'] ?? '',
      checkInCodeTimestamp: map['checkInCodeTimestamp'] != null
          ? (map['checkInCodeTimestamp'] as Timestamp).toDate()
          : null,
      checkedInUsers: map['checkedInUsers'] != null
          ? List<String>.from(map['checkedInUsers'] as List)
          : <String>[],
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

  /// Formatear fecha
  String formattedDate(DateTime? d) {
    if (d == null) return 'Sin fecha';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  /// Crear un plan y guardarlo en Firestore
  static Future<PlanModel> createPlan({
    required String type,
    required String typeLowercase,  // <--- Nuevo parámetro
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
    List<String>? images,
    List<String>? originalImages,
    String? videoUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Usuario no autenticado");
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    final userData = userDoc.data();
    if (userData == null) {
      throw Exception("No se encontraron datos del usuario");
    }

    // Generamos un ID único para este plan
    final String uniqueId = await generateUniqueId();

    // Leemos la privacidad de perfil del usuario creador
    final int? privacy = userData['profile_privacy'] is int
        ? userData['profile_privacy'] as int
        : 0;

    // Construimos el PlanModel en memoria
    final plan = PlanModel(
      id: uniqueId,
      type: type,
      typeLowercase: typeLowercase, // Almacenamos
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
      removedParticipants: [],
      invitedUsers: [],
      likes: 0,
      special_plan: special_plan,
      views: 0,
      share_count: 0,
      viewedBy: [],
      images: images ?? [],
      originalImages: originalImages ?? [],
      videoUrl: videoUrl ?? '',
      creatorProfilePrivacy: privacy,

      // Check-in
      checkInActive: false,
      checkInCode: '',
      checkInCodeTimestamp: null,
      checkedInUsers: [],
    );

    // Guardamos en Firestore
    await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .set(plan.toMap());

    // Aumentamos el número de planes creados por el usuario
    await userRef.update({
      'total_created_plans': FieldValue.increment(1),
    });

    await updateUserHasActivePlan(user.uid);

    return plan;
  }

  /// Actualizar un plan existente en Firestore
  static Future<void> updatePlan(
    String planId, {
    required String type,
    required String typeLowercase,
    required String description,
    required int minAge,
    required int maxAge,
    int? maxParticipants,
    required String location,
    double? latitude,
    double? longitude,
    required DateTime startTimestamp,
    required DateTime finishTimestamp,
    required String backgroundImage,
    String? visibility,
    String? iconAsset,
    List<String>? images,
    List<String>? originalImages,
    String? videoUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Usuario no autenticado");
    }

    final docRef = FirebaseFirestore.instance.collection('plans').doc(planId);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      throw Exception("El plan con ID '$planId' no existe en la base de datos.");
    }

    final Map<String, dynamic> updates = {
      'type': type,
      'typeLowercase': typeLowercase,
      'description': description,
      'minAge': minAge,
      'maxAge': maxAge,
      'maxParticipants': maxParticipants,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'start_timestamp': Timestamp.fromDate(startTimestamp),
      'finish_timestamp': Timestamp.fromDate(finishTimestamp),
      'backgroundImage': backgroundImage,
      'visibility': visibility,
      'iconAsset': iconAsset,
      'images': images ?? [],
      'originalImages': originalImages ?? [],
      'videoUrl': videoUrl ?? '',
    };

    await docRef.update(updates);

    await updateUserHasActivePlan(user.uid);
  }

  static Future<void> updateUserHasActivePlan(String uid) async {
    final now = DateTime.now();
    bool active = false;

    final createdSnap = await FirebaseFirestore.instance
        .collection('plans')
        .where('createdBy', isEqualTo: uid)
        .where('special_plan', isEqualTo: 0)
        .get();
    for (final d in createdSnap.docs) {
      final ts = d.data()['start_timestamp'] as Timestamp?;
      if (ts != null && ts.toDate().isAfter(now)) {
        active = true;
        break;
      }
    }

    if (!active) {
      final joinedSnap = await FirebaseFirestore.instance
          .collection('plans')
          .where('participants', arrayContains: uid)
          .where('special_plan', isEqualTo: 0)
          .get();
      for (final d in joinedSnap.docs) {
        final ts = d.data()['start_timestamp'] as Timestamp?;
        if (ts != null && ts.toDate().isAfter(now)) {
          active = true;
          break;
        }
      }
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'hasActivePlan': active});
  }
}
