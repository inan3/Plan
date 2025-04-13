import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Importamos la PlanCard
import '../users_grid/plan_card.dart';

import '../../models/plan_model.dart';
import '../../main/colors.dart';

/// ---------------------------------------------------------------------------
/// PANTALLA de planes "favoritos" del usuario
/// ---------------------------------------------------------------------------
class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({Key? key}) : super(key: key);

  // ------------------------------------------------------------------------
  // Obtener todos los participantes del plan (lo usará PlanCard)
  // ------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];

    // 1) Buscamos en 'subscriptions' quienes están suscritos a este plan
    final subsSnap = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('id', isEqualTo: plan.id)
        .get();

    for (var sDoc in subsSnap.docs) {
      final sData = sDoc.data();
      final userId = sData['userId'];
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final uData = userDoc.data()!;
        participants.add({
          'uid': userId,
          'name': uData['name'] ?? 'Sin nombre',
          'age': uData['age']?.toString() ?? '',
          'photoUrl': uData['photoUrl'] ?? uData['profilePic'] ?? '',
          'isCreator': (plan.createdBy == userId),
        });
      }
    }

    return participants;
  }

  // ------------------------------------------------------------------------
  // Cargar los planes completos desde IDs en 'favourites'
  // ------------------------------------------------------------------------
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

  // ------------------------------------------------------------------------
  // Build principal: muestra la lista de planes marcados como favoritos
  // ------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text(
          'Usuario no autenticado',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    // Observa el doc del usuario para obtener su array de 'favourites'
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(
            child: Text(
              'No tienes planes favoritos aún.',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final favouritePlanIds = List<String>.from(data['favourites'] ?? []);
        if (favouritePlanIds.isEmpty) {
          return const Center(
            child: Text(
              'No tienes planes favoritos aún.',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        // Cargamos los PlanModels referidos en 'favourites'
        return FutureBuilder<List<PlanModel>>(
          future: _fetchPlansFromIds(favouritePlanIds),
          builder: (context, planSnapshot) {
            if (planSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!planSnapshot.hasData || planSnapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'No tienes planes favoritos aún.',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            final plans = planSnapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];

                // Para mostrar la tarjeta, necesitamos los datos del creador
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(plan.createdBy)
                      .get(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 330,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (userSnapshot.hasError ||
                        !userSnapshot.hasData ||
                        !userSnapshot.data!.exists) {
                      return const SizedBox(
                        height: 330,
                        child: Center(
                          child: Text(
                            'Error al cargar creador del plan',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    }

                    final creatorData = userSnapshot.data!.data() as Map<String, dynamic>;
                    final userData = {
                      'name': creatorData['name'] ?? 'Usuario',
                      'handle': creatorData['handle'] ?? '@usuario',
                      'photoUrl': creatorData['photoUrl'] ?? '',
                    };

                    // Aquí reutilizamos PlanCard.
                    // IMPORTANTE: hideJoinButton = false → mostramos el botón “Unirse”.
                    return PlanCard(
                      plan: plan,
                      userData: userData,
                      fetchParticipants: _fetchAllPlanParticipants,
                      hideJoinButton: false,
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
