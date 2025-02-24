import '../models/plan_model.dart';

class UserAndPlans {
  final Map<String, dynamic> userData; // Información del usuario (nombre, foto, uid, etc.)
  final List<PlanModel> plans;         // Lista de planes creados por el usuario

  UserAndPlans({
    required this.userData,
    required this.plans,
  });
}
