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
  DateTime? date;
  String createdBy;          
  String? creatorName;       
  String? creatorProfilePic;
  DateTime? createdAt;       
  // Nuevo campo para la imagen de fondo.
  String? backgroundImage;   
  // Nuevo campo para la visibilidad del plan.
  String? visibility;
  // Nuevo campo para el icono del plan.
  String? iconAsset;
  // Lista de participantes
  List<String>? participants;
  // NUEVO: Contador de likes
  int likes; 

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
    this.date,
    required this.createdBy,
    this.creatorName,
    this.creatorProfilePic,
    this.createdAt,
    this.backgroundImage,
    this.visibility,
    this.iconAsset,
    this.participants,
    this.likes = 0, // Valor por defecto 0
  });

  // Genera un ID único para el plan de 10 caracteres alfanuméricos
  static Future<String> generateUniqueId() async {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random();
    String id;
    do {
      id = List.generate(10, (index) => chars[random.nextInt(chars.length)]).join();
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
      'date': date?.toIso8601String(),
      'createdBy': createdBy,
      'creatorName': creatorName,
      'creatorProfilePic': creatorProfilePic,
      'createdAt': createdAt?.toIso8601String(),
      'backgroundImage': backgroundImage,
      'visibility': visibility,
      'iconAsset': iconAsset,
      'participants': participants ?? [],
      'likes': likes, // NUEVO
    };
  }

  // Crea un objeto PlanModel a partir de un Map (documento Firestore)
  factory PlanModel.fromMap(Map<String, dynamic> map) {
    return PlanModel(
      id: map['id'] == null ? '' : map['id'] as String,
      type: map['type'] == null ? '' : map['type'] as String,
      description: map['description'] == null ? '' : map['description'] as String,
      minAge: map['minAge'] == null ? 0 : map['minAge'] as int,
      maxAge: map['maxAge'] == null ? 99 : map['maxAge'] as int,
      maxParticipants: map['maxParticipants'] != null
          ? map['maxParticipants'] as int
          : null,
      location: map['location'] == null ? '' : map['location'] as String,
      latitude: _parseDouble(map['latitude']),
      longitude: _parseDouble(map['longitude']),
      date: _parseDate(map['date']),
      createdBy: map['createdBy'] == null ? '' : map['createdBy'] as String,
      creatorName: map['creatorName'] as String?,
      creatorProfilePic: map['creatorProfilePic'] as String?,
      createdAt: _parseDate(map['createdAt']),
      backgroundImage: map['backgroundImage'] as String?,
      visibility: map['visibility'] as String?,
      iconAsset: map['iconAsset'] as String?,
      participants: map['participants'] != null
          ? List<String>.from(map['participants'] as List)
          : <String>[],
      likes: map['likes'] != null ? map['likes'] as int : 0,
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

  // Formatea la fecha/hora en dd/MM/yyyy HH:mm
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
    DateTime? date,
    String? backgroundImage,
    String? visibility,
    String? iconAsset,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Usuario no autenticado");
    }

    // Datos del usuario que crea el plan
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    if (userData == null) {
      throw Exception("No se encontraron datos del usuario");
    }

    // Genera un ID único de 10 caracteres
    final String uniqueId = await generateUniqueId();

    // Construimos el plan
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
      date: date,
      createdBy: user.uid,
      creatorName: userData['name'],
      creatorProfilePic: userData['profilePic'],
      createdAt: DateTime.now(),
      backgroundImage: backgroundImage,
      visibility: visibility,
      iconAsset: iconAsset,
      participants: [],
      likes: 0, // Inicialmente 0
    );

    // Guardar en la colección 'plans'
    await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .set(plan.toMap());

    return plan;
  }
}
