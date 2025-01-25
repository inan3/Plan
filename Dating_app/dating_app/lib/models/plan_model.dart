// plan_model.dart
class PlanModel {
  final String id; // ID único del plan (generado en Firebase)
  final String planType; // Tipo de plan (e.g., "Deporte", "Cena")
  final String description; // Descripción del plan
  final int? maxParticipants; // Número máximo de participantes
  final String? location; // Ubicación seleccionada
  final DateTime? dateTime; // Fecha y hora del plan
  final DateTime createdAt; // Fecha de creación del plan

  PlanModel({
    required this.id,
    required this.planType,
    required this.description,
    this.maxParticipants,
    this.location,
    this.dateTime,
    required this.createdAt,
  });

  // Método para convertir el plan a un mapa (para Firebase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'planType': planType,
      'description': description,
      'maxParticipants': maxParticipants,
      'location': location,
      'dateTime': dateTime?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Método para crear un plan desde un mapa (para Firebase)
  factory PlanModel.fromMap(Map<String, dynamic> map) {
    return PlanModel(
      id: map['id'] as String,
      planType: map['planType'] as String,
      description: map['description'] as String,
      maxParticipants: map['maxParticipants'] as int?,
      location: map['location'] as String?,
      dateTime: map['dateTime'] != null
          ? DateTime.parse(map['dateTime'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
