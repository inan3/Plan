import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/plan_model.dart';
// IMPORTA plan_card.dart
import '../users_grid/plan_card.dart';

class SubscribedPlansSelection extends StatelessWidget {
  final Set<String> selectedIds;
  final Function(String) onToggleSelected;

  const SubscribedPlansSelection({
    Key? key,
    required this.selectedIds,
    required this.onToggleSelected,
  }) : super(key: key);

  // Busca datos (nombre/foto) del creador del plan para pasar a PlanCard
  Future<Map<String, dynamic>> _fetchCreatorUserData(String creatorUid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(creatorUid)
        .get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      return {
        'name': data['name'] ?? 'Sin nombre',
        'photoUrl': data['photoUrl'] ?? '',
      };
    }
    return {
      'name': 'Usuario',
      'photoUrl': '',
    };
  }

  // Obtiene PlanModel de la lista de IDs
  Future<List<PlanModel>> _fetchPlansFromIds(List<String> planIds) async {
    if (planIds.isEmpty) return [];
    final List<PlanModel> plans = [];
    for (String planId in planIds) {
      final planDoc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(planId)
          .get();
      if (planDoc.exists) {
        final planData = planDoc.data() as Map<String, dynamic>;
        planData['id'] = planDoc.id;
        plans.add(PlanModel.fromMap(planData));
      }
    }
    return plans;
  }

  // Para si PlanCard requiere participantes
  Future<List<Map<String, dynamic>>> _fetchPlanParticipants(PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];
    final docPlan = await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .get();

    if (docPlan.exists && docPlan.data() != null) {
      final data = docPlan.data()!;
      final List<dynamic> partList = data['participants'] ?? [];
      for (var uid in partList) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final uData = userDoc.data()!;
          participants.add({
            'uid': uid,
            'name': uData['name'] ?? 'Usuario',
            'photoUrl': uData['photoUrl'] ?? '',
            'age': uData['age']?.toString() ?? '',
          });
        }
      }
    }
    return participants;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(
        child: Text('Debes iniciar sesión.'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('subscriptions')
          .where('userId', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No tienes planes suscritos aún.',
              style: TextStyle(color: Colors.black),
            ),
          );
        }
        // Extraemos la lista de IDs de planes suscritos
        final planIds = snapshot.data!.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['id'] as String? ?? '';
            })
            .where((id) => id.isNotEmpty)
            .toList();

        // Obtenemos la lista de PlanModels
        return FutureBuilder<List<PlanModel>>(
          future: _fetchPlansFromIds(planIds),
          builder: (context, planSnapshot) {
            if (planSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final plans = planSnapshot.data ?? [];
            if (plans.isEmpty) {
              return const Center(
                child: Text(
                  'No tienes planes suscritos aún.',
                  style: TextStyle(color: Colors.black),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                final bool isSelected = selectedIds.contains(plan.id);

                return FutureBuilder<Map<String, dynamic>>(
                  future: _fetchCreatorUserData(plan.createdBy),
                  builder: (ctx, userSnap) {
                    final creatorData = userSnap.data ?? {
                      'name': 'Usuario',
                      'photoUrl': '',
                    };

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: const BoxDecoration(),
                      child: Stack(
                        children: [
                          // La PlanCard
                          PlanCard(
                            plan: plan,
                            userData: creatorData,
                            fetchParticipants: _fetchPlanParticipants,
                            hideJoinButton: true, 
                          ),

                          // Círculo en la esquina sup. derecha
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                if (plan.id != null) {
                                  onToggleSelected(plan.id!);
                                }
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected 
                                    ? Colors.blue // relleno azul si seleccionado
                                    : Colors.white70, // hueco "blanco" si no
                                  border: Border.all(
                                    color: isSelected ? Colors.blue : Colors.grey,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
