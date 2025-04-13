import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Ya NO necesitas muchos de los imports previos relacionados a la UI manual.
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/plan_model.dart';
import '../../main/colors.dart';
import '../../utils/plans_list.dart' as plansData;
import '../users_managing/frosted_plan_dialog_state.dart' as new_frosted;

// IMPORTA TU PlanCard
import '../users_grid/plan_card.dart';

class SubscribedPlansScreen extends StatelessWidget {
  final String userId;

  const SubscribedPlansScreen({Key? key, required this.userId})
      : super(key: key);

  // --------------------------------------------------------------------------
  // Mostrar el FrostedPlanDialog a pantalla completa (se usa solo en plan especial)
  // --------------------------------------------------------------------------
  void _showFrostedPlanDialog(BuildContext context, PlanModel plan) {
    showDialog(
      context: context,
      barrierDismissible: true,
      useSafeArea: false,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: SizedBox(
            width: MediaQuery.of(ctx).size.width,
            height: MediaQuery.of(ctx).size.height,
            child: new_frosted.FrostedPlanDialog(
              plan: plan,
              fetchParticipants: _fetchAllPlanParticipants,
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Obtener todos los participantes leyendo el campo 'participants' del plan
  // --------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(
    PlanModel plan,
  ) async {
    final List<Map<String, dynamic>> participants = [];
    final planDoc =
        await FirebaseFirestore.instance.collection('plans').doc(plan.id).get();
    if (!planDoc.exists) return participants;

    final planData = planDoc.data()!;
    final participantUids = List<String>.from(planData['participants'] ?? []);
    for (String uid in participantUids) {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final uData = userDoc.data()!;
        participants.add({
          'uid': uid,
          'name': uData['name'] ?? 'Sin nombre',
          'age': uData['age']?.toString() ?? '',
          'photoUrl': uData['photoUrl'] ?? uData['profilePic'] ?? '',
          'isCreator': (plan.createdBy == uid),
        });
      }
    }
    return participants;
  }

  // --------------------------------------------------------------------------
  // Obtener los PlanModel completos a partir de IDs
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Lógica para "Abandonar" plan (borrado de 'subscriptions' y participants)
  // --------------------------------------------------------------------------
  void _confirmDeletePlan(BuildContext context, PlanModel plan) {
    final String currentUserId = userId;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("¿Quieres abandonar este plan?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("No"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                // 1) Elimina el doc de 'subscriptions'
                final subs = await FirebaseFirestore.instance
                    .collection('subscriptions')
                    .where('userId', isEqualTo: currentUserId)
                    .where('id', isEqualTo: plan.id)
                    .get();
                for (var doc in subs.docs) {
                  await doc.reference.delete();
                }
                // 2) Remueve al usuario del array 'participants' en 'plans'
                await FirebaseFirestore.instance
                    .collection('plans')
                    .doc(plan.id)
                    .update({
                  'participants': FieldValue.arrayRemove([currentUserId])
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Has abandonado el plan ${plan.type}.'),
                  ),
                );
                Navigator.pop(context); // Cierra el alert
              },
              child: const Text("Sí"),
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Construye el widget final para cada plan (plan especial o normal)
  // --------------------------------------------------------------------------
  Widget _buildPlanTile(
    BuildContext context,
    Map<String, dynamic> userData,
    PlanModel plan,
  ) {
    // PLAN ESPECIAL
    if (plan.special_plan == 1) {
      // Reutilizamos la UI previa para "plan especial"
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchAllPlanParticipants(plan),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: 100,
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueAccent, width: 2),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            );
          }
          final participants = snapshot.data!;
          final Widget creatorAvatar = participants.isNotEmpty &&
                  (participants[0]['photoUrl'] ?? '').isNotEmpty
              ? CircleAvatar(
                  backgroundImage: NetworkImage(participants[0]['photoUrl']),
                  radius: 20,
                )
              : const CircleAvatar(radius: 20);
          final Widget participantAvatar = (participants.length > 1 &&
                  (participants[1]['photoUrl'] ?? '').isNotEmpty)
              ? CircleAvatar(
                  backgroundImage: NetworkImage(participants[1]['photoUrl']),
                  radius: 20,
                )
              : const SizedBox();

          // Buscamos el icono si existe en tu lista
          String iconPath = plan.iconAsset ?? '';
          for (var item in plansData.plans) {
            if (plan.iconAsset == item['icon']) {
              iconPath = item['icon'];
              break;
            }
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showFrostedPlanDialog(context, plan),
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: 80,
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(color: Colors.blueAccent, width: 2),
                ),
                child: Row(
                  children: [
                    // Icono + tipo de plan
                    Row(
                      children: [
                        if (iconPath.isNotEmpty)
                          SvgPicture.asset(
                            iconPath,
                            width: 40,
                            height: 40,
                            color: Colors.amber,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          plan.type,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Avatares
                    Row(
                      children: [
                        creatorAvatar,
                        const SizedBox(width: 8),
                        participantAvatar,
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // PLAN NORMAL → Usar PlanCard + botón "Abandonar"
    else {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          // La tarjeta principal
          PlanCard(
            plan: plan,
            userData: userData,
            fetchParticipants: _fetchAllPlanParticipants,
            hideJoinButton: true, // <--- Importante
          ),

          // Botón para "Abandonar" (arriba a la derecha, con un offset)
          Positioned(
            top: 14,
            right: 12,
            child: GestureDetector(
              onTap: () => _confirmDeletePlan(context, plan),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.exit_to_app,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  // --------------------------------------------------------------------------
  // Build principal: muestra la lista de planes a los que estoy suscrito
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('subscriptions')
            .where('userId', isEqualTo: userId) // <--- IMPORTANTE
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

          // Recopilamos todos los IDs de plan a los que el usuario está suscrito
          final planIds = snapshot.data!.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['id'] as String? ?? '';
              })
              .where((id) => id.isNotEmpty)
              .toList();

          return FutureBuilder<List<PlanModel>>(
            future: _fetchPlansFromIds(planIds),
            builder: (context, planSnapshot) {
              if (!planSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final plans = planSnapshot.data!;
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
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(plan.createdBy)
                        .get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
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
                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>;
                      // Aquí llamamos a nuestra función que decide
                      // si se muestra "plan especial" o un PlanCard:
                      return _buildPlanTile(context, userData, plan);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
