import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/plan_model.dart';
import '../users_grid/plan_card.dart'; // Ajusta la ruta a tu plan_card.dart

class MyPlansSelection extends StatelessWidget {
  final Set<String> selectedIds;
  final Function(String) onToggleSelected;

  const MyPlansSelection({
    Key? key,
    required this.selectedIds,
    required this.onToggleSelected,
  }) : super(key: key);

  // Carga info del creador (nombre/foto) para pasarlo a la PlanCard
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
    return {'name': 'Usuario', 'photoUrl': ''};
  }

  // Participantes para PlanCard si es necesario
  Future<List<Map<String, dynamic>>> _fetchPlanParticipants(PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];
    final docPlan = await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .get();

    if (docPlan.exists && docPlan.data() != null) {
      final planData = docPlan.data()!;
      final List<dynamic> partList = planData['participants'] ?? [];
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
        child: Text('Debes iniciar sesión para ver tus planes.'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('plans')
          .where('createdBy', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No tienes planes aún.',
              style: TextStyle(color: Colors.black),
            ),
          );
        }

        final plans = snapshot.data!.docs.map((doc) {
          final planMap = doc.data() as Map<String, dynamic>;
          planMap['id'] = doc.id;
          return PlanModel.fromMap(planMap);
        }).toList();

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
                  // Sin color ni borde, la tarjeta 'PlanCard' se ve directamente
                  decoration: const BoxDecoration(),
                  child: Stack(
                    children: [
                      // Tarjeta del plan
                      PlanCard(
                        plan: plan,
                        userData: creatorData,
                        fetchParticipants: _fetchPlanParticipants,
                        hideJoinButton: true, // oculta botón "Unirse"
                      ),

                      // Círculo en esquina sup derecha para selección
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
                                  ? Colors.blue // Relleno azul si seleccionado
                                  : Colors.white70, // Hueco blanquecino si no
                              border: Border.all(
                                color: isSelected ? Colors.blue : Colors.grey,
                                width: 2,
                              ),
                            ),
                            // No icon: el relleno azul indica selección
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
  }
}
