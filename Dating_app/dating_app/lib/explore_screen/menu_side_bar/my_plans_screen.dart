import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart'; // Para Share.share()

import '../../models/plan_model.dart';
import '../../main/colors.dart';
import '../../utils/plans_list.dart' as plansData;

// Importa tu PlanCard:
import '../users_grid/plan_card.dart';

// Para tu FrostedPlanDialog especial:
import '../users_managing/frosted_plan_dialog_state.dart' as new_frosted;

class MyPlansScreen extends StatelessWidget {
  const MyPlansScreen({Key? key}) : super(key: key);

  // --------------------------------------------------------------------------
  // Método para obtener todos los participantes de un plan (para PlanCard).
  // --------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];

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

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(
        child: Text(
          'Debes iniciar sesión para ver tus planes.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
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

          // Convertimos cada doc en un PlanModel
          final plans = snapshot.data!.docs.map((doc) {
            final pData = doc.data() as Map<String, dynamic>;
            pData['id'] = doc.id;
            return PlanModel.fromMap(pData);
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return _buildPlanTile(context, plan);
            },
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Decide cómo mostrar la tarjeta: especial vs normal (usando PlanCard).
  // --------------------------------------------------------------------------
  Widget _buildPlanTile(BuildContext context, PlanModel plan) {
    // 1) Plan especial
    if (plan.special_plan == 1) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchAllPlanParticipants(plan),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _buildSpecialPlanLoading();
          }

          final participants = snapshot.data!;
          final creatorAvatar = participants.isNotEmpty &&
                  (participants[0]['photoUrl'] ?? '').isNotEmpty
              ? CircleAvatar(
                  backgroundImage: NetworkImage(participants[0]['photoUrl']),
                  radius: 20,
                )
              : const CircleAvatar(radius: 20);

          final participantAvatar = (participants.length > 1 &&
                  (participants[1]['photoUrl'] ?? '').isNotEmpty)
              ? CircleAvatar(
                  backgroundImage: NetworkImage(participants[1]['photoUrl']),
                  radius: 20,
                )
              : const SizedBox();

          // Encontramos icono en tu lista local
          String iconPath = plan.iconAsset ?? '';
          for (var item in plansData.plans) {
            if (plan.iconAsset == item['icon']) {
              iconPath = item['icon'];
              break;
            }
          }

          return GestureDetector(
            onTap: () => _openFrostedPlanDialog(context, plan),
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

    // 2) Plan normal → reutilizar PlanCard + superponer botón "Eliminar"
    else {
      // Obtenemos los datos del creador => en "Mis Planes", ya sabemos
      // que el creador es el usuario actual, pero si igual quieres mostrar
      // su nombre/foto, lee tu doc en 'users' o pasa algo “dummy”.
      final userData = {
        'name': 'Tú',
        'handle': '@creador',
        'photoUrl': '', // Carga tu foto si gustas
      };

      return Stack(
        clipBehavior: Clip.none,
        children: [
          // La tarjeta reusada
          PlanCard(
            plan: plan,
            userData: userData,
            fetchParticipants: _fetchAllPlanParticipants,
            // Es tu propio plan, así que oculta "Unirse":
            hideJoinButton: true,
          ),
          // Botón para ELIMINAR plan
          Positioned(
            top: 20,
            right: 20,
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
                      Icons.delete,
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
  // Tarjeta "loading" para plan especial
  // --------------------------------------------------------------------------
  Widget _buildSpecialPlanLoading() {
    return Center(
      child: Container(
        width: 300,
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

  // --------------------------------------------------------------------------
  // Muestra el FrostedPlanDialog a pantalla completa
  // --------------------------------------------------------------------------
  void _openFrostedPlanDialog(BuildContext context, PlanModel plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.transparent,
          body: new_frosted.FrostedPlanDialog(
            plan: plan,
            fetchParticipants: _fetchAllPlanParticipants,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Popup de confirmación para ELIMINAR plan
  // --------------------------------------------------------------------------
  void _confirmDeletePlan(BuildContext context, PlanModel plan) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("¿Eliminar este plan?"),
          content: Text("Esta acción eliminará el plan ${plan.type} de forma permanente."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                // 1) Elimina el doc en 'plans'
                await FirebaseFirestore.instance
                    .collection('plans')
                    .doc(plan.id)
                    .delete();

                // 2) Elimina docs de 'subscriptions'
                final subs = await FirebaseFirestore.instance
                    .collection('subscriptions')
                    .where('id', isEqualTo: plan.id)
                    .get();
                for (var doc in subs.docs) {
                  await doc.reference.delete();
                }

                Navigator.pop(ctx); // Cierra el alert
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Plan ${plan.type} eliminado.')),
                );
              },
              child: const Text("Eliminar"),
            ),
          ],
        );
      },
    );
  }
}
