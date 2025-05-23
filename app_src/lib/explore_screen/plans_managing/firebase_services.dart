import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/plan_model.dart';

/// Obtiene los planes de un usuario (que no sean especiales,
/// no hayan finalizado y que tengan visibility = "Público").
Future<List<PlanModel>> fetchUserPlans(String userId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('plans')
      .where('createdBy', isEqualTo: userId)
      .where('visibility', isEqualTo: 'Público') // <-- Solo planes públicos
      .get();

  final now = DateTime.now();
  final filteredDocs = snapshot.docs.where((doc) {
    final data = doc.data();
    final int sp = data['special_plan'] ?? 0;
    if (sp != 0) return false; // si es "especial", se excluye

    final Timestamp? finishTs = data['finish_timestamp'];
    if (finishTs == null) return false;
    final finishDate = finishTs.toDate();
    return finishDate.isAfter(now);
  }).toList();

  return filteredDocs.map((doc) {
    final data = doc.data();
    return PlanModel.fromMap(data);
  }).toList();
}

/// Obtiene la lista de participantes de un Plan.
Future<List<Map<String, dynamic>>> fetchPlanParticipants(PlanModel plan) async {
  final List<Map<String, dynamic>> participants = [];
  final planDoc = await FirebaseFirestore.instance
      .collection('plans')
      .doc(plan.id)
      .get();

  if (!planDoc.exists) {
    return participants;
  }

  final planData = planDoc.data()!;
  final participantsList = List<String>.from(planData['participants'] ?? []);

  for (String userId in participantsList) {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists && userDoc.data() != null) {
      final uData = userDoc.data()!;
      participants.add({
        'uid': userId,
        'name': uData['name'] ?? 'Sin nombre',
        'age': uData['age']?.toString() ?? '',
        'photoUrl': uData['photoUrl'] ?? '',
        'isCreator': (plan.createdBy == userId),
      });
    }
  }
  return participants;
}

/// Increments the view count of a plan only once per user. The creator's own
/// views are ignored.
Future<void> incrementPlanViewIfNeeded(String planId, String createdBy) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  if (user.uid == createdBy) return;

  final viewRef = FirebaseFirestore.instance
      .collection('plans')
      .doc(planId)
      .collection('views')
      .doc(user.uid);

  final snap = await viewRef.get();
  if (snap.exists) return;

  await viewRef.set({'viewedAt': FieldValue.serverTimestamp()});
  await FirebaseFirestore.instance
      .collection('plans')
      .doc(planId)
      .update({'views': FieldValue.increment(1)});
}
