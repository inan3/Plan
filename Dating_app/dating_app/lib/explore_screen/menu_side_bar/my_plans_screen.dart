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
import '../plans_managing/plan_card.dart';

// Para tu FrostedPlanDialog especial:
import '../plans_managing/frosted_plan_dialog_state.dart' as new_frosted;

class MyPlansScreen extends StatelessWidget {
  const MyPlansScreen({Key? key}) : super(key: key);

  // --------------------------------------------------------------------------
  // Método para obtener todos los participantes del plan usando el array
  // "participants" en el documento de la colección 'plans'.
  // --------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(
    PlanModel plan,
  ) async {
    final doc = await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .get();

    final List<Map<String, dynamic>> participants = [];
    if (!doc.exists || doc.data() == null) return participants;

    final data = doc.data()!;
    // Leemos el array 'participants' del doc:
    final participantUids = List<String>.from(data['participants'] ?? []);

    // Por cada UID, buscamos su info en 'users'
    for (String uid in participantUids) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
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
    // CASO 1: Plan especial
    if (plan.special_plan == 1) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchAllPlanParticipants(plan),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSpecialPlanLoading();
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar participantes: ${snapshot.error}'),
            );
          }
          final participants = snapshot.data ?? [];

          // Tomamos hasta 2 para mostrar en "mini avatares"
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

          // Construimos la "tarjeta" (en realidad un container con tu estilo)
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

    // CASO 2: Plan normal
      else {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 330,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          // fallback mínimo
          final fallbackData = {
            'name': 'Tú',
            'handle': '@creador',
            'photoUrl': '',
          };
          return _buildMyPlanCard(context, plan, fallbackData);
        }

        final data = snap.data!.data() as Map<String, dynamic>;
        final userData = {
          'name': data['name'] ?? 'Tú',
          'handle': data['handle'] ?? '@creador',
          'photoUrl': data['photoUrl'] ?? '',
        };
        return _buildMyPlanCard(context, plan, userData);
      },
    );
  }
  }

  Widget _buildMyPlanCard(BuildContext context, PlanModel plan, Map<String, dynamic> userData) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      PlanCard(
        plan: plan,
        userData: userData,
        fetchParticipants: _fetchAllPlanParticipants,
        hideJoinButton: true,
      ),
      Positioned(
        top: 14,
        right: 14,
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
                child: const Icon(Icons.delete, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    ],
  );
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
            // Le pasamos la misma función de participantes unificada
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
          content: Text(
            "Esta acción eliminará el plan ${plan.type} de forma permanente.",
          ),
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

                // 2) (Opcional) Elimina docs de 'subscriptions' si usas esa colección
                // para almacenar que un usuario "se suscribió". Si ya no la usas,
                // puedes eliminar este bloque.
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
