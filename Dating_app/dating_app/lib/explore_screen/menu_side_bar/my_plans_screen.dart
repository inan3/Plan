import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../users_managing/frosted_plan_dialog_state.dart' as new_frosted;
import '../../models/plan_model.dart';
import '../../main/colors.dart';
import '../../utils/plans_list.dart' as plansData;

/// ---------------------------------------------------------------------------
/// PANTALLA PRINCIPAL donde se listan los planes del usuario logueado.
/// ---------------------------------------------------------------------------
class MyPlansScreen extends StatelessWidget {
  const MyPlansScreen({Key? key}) : super(key: key);

  // --------------------------------------------------------------------------
  // Método para obtener todos los participantes de un plan (creator + subs).
  // --------------------------------------------------------------------------
Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(
  PlanModel plan,
) async {
  final List<Map<String, dynamic>> participants = [];

  // 1) Datos del plan
  final planDoc = await FirebaseFirestore.instance
      .collection('plans')
      .doc(plan.id)
      .get();
  if (planDoc.exists) {
    final planData = planDoc.data();
    final creatorId = planData?['createdBy'];
    if (creatorId != null) {
      final creatorUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(creatorId)
          .get();
      if (creatorUserDoc.exists) {
        final cdata = creatorUserDoc.data()!;
        participants.add({
          'uid': creatorId,  // <--- MUY IMPORTANTE
          'name': cdata['name'] ?? 'Sin nombre',
          'age': cdata['age']?.toString() ?? '',
          'photoUrl': cdata['photoUrl'] ?? cdata['profilePic'] ?? '',
          'isCreator': true,
        });
      }
    }
  }

  // 2) Datos de subscripciones
  final subsSnap = await FirebaseFirestore.instance
      .collection('subscriptions')
      .where('id', isEqualTo: plan.id)
      .get();
  for (var sDoc in subsSnap.docs) {
    final sData = sDoc.data();
    final userId = sData['userId'];
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (userDoc.exists) {
      final uData = userDoc.data()!;
      participants.add({
        'uid': userId,  // <--- TAMBIÉN AQUÍ
        'name': uData['name'] ?? 'Sin nombre',
        'age': uData['age']?.toString() ?? '',
        'photoUrl': uData['photoUrl'] ?? uData['profilePic'] ?? '',
        'isCreator': false,
      });
    }
  }

  return participants;
}

  // --------------------------------------------------------------------------
  // Construye la pantalla con las tarjetas de planes creados por el usuario.
  // --------------------------------------------------------------------------
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

          final plans = snapshot.data!.docs
              .map((doc) => PlanModel.fromMap(doc.data() as Map<String, dynamic>))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return _buildPlanCard(context, plan, index);
            },
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Construye cada tarjeta de plan. Al pulsar, abre la pantalla de detalles.
  // --------------------------------------------------------------------------
  Widget _buildPlanCard(BuildContext context, PlanModel plan, int index) {
    // Si es plan especial -> estilo específico para la tarjeta
    if (plan.special_plan == 1) {
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
                  (participants[0]['photoUrl'] ?? '').toString().isNotEmpty
              ? CircleAvatar(
                  backgroundImage: NetworkImage(participants[0]['photoUrl']),
                  radius: 20,
                )
              : const CircleAvatar(radius: 20);

          final Widget participantAvatar =
              (participants.length > 1 &&
                      (participants[1]['photoUrl'] ?? '').toString().isNotEmpty)
                  ? CircleAvatar(
                      backgroundImage: NetworkImage(participants[1]['photoUrl']),
                      radius: 20,
                    )
                  : const SizedBox();

          // Encontrar el icono desde tu lista local
          String iconPath = plan.iconAsset ?? '';
          for (var item in plansData.plans) {
            if (plan.iconAsset == item['icon']) {
              iconPath = item['icon'];
              break;
            }
          }

          return GestureDetector(
            onTap: () {
              // En lugar de showGeneralDialog, usamos un Navigator.push
              // para que ocupe toda la pantalla.
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
            },
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
                    // Lado izquierdo: icono + tipo
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
                    // Lado derecho: avatares
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
    } else {
      // Si NO es especial, construimos la tarjeta "normal"
      final String? backgroundImage = plan.backgroundImage;
      final String caption = plan.description.isNotEmpty
          ? plan.description
          : 'Descripción breve o #hashtags';
      const String sharesCount = '227';

      return GestureDetector(
        onTap: () {
          // Reemplazamos showGeneralDialog por un push a pantalla completa
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
        },
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: 330,
            margin: const EdgeInsets.only(bottom: 15),
            child: Stack(
              children: [
                // Imagen de fondo
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: (backgroundImage != null && backgroundImage.isNotEmpty)
                      ? Image.network(
                          backgroundImage,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
                // Botón eliminar y compartir
                Positioned(
                  top: 16,
                  right: 16,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botón compartir
                      GestureDetector(
                        onTap: () {
                          // Acción para compartir (implementar funcionalidad)
                        },
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  'assets/compartir.svg',
                                  width: 20,
                                  height: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botón eliminar
                      GestureDetector(
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
                    ],
                  ),
                ),
                // Parte inferior: contadores + descripción
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.5),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildIconText(
                                  icon: Icons.favorite_border,
                                  label: plan.likes.toString(),
                                ),
                                const SizedBox(width: 25),
                                // Usamos un StreamBuilder para leer 'commentsCount'
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('plans')
                                      .doc(plan.id)
                                      .snapshots(),
                                  builder: (context, snap) {
                                    if (!snap.hasData || !snap.data!.exists) {
                                      return _buildIconText(
                                        icon: Icons.chat_bubble_outline,
                                        label: '0',
                                      );
                                    }
                                    final data =
                                        snap.data!.data() as Map<String, dynamic>;
                                    final count = data['commentsCount'] ?? 0;
                                    return _buildIconText(
                                      icon: Icons.chat_bubble_outline,
                                      label: count.toString(),
                                    );
                                  },
                                ),
                                const SizedBox(width: 25),
                                _buildIconText(
                                  icon: Icons.share,
                                  label: sharesCount,
                                ),
                                const Spacer(),
                                // Contador de participantes dinámico
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('plans')
                                      .doc(plan.id)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return Row(
                                        children: [
                                          Text(
                                            '0/0',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          SvgPicture.asset(
                                            'assets/users.svg',
                                            color: AppColors.blue,
                                            width: 20,
                                            height: 20,
                                          ),
                                        ],
                                      );
                                    }
                                    final updatedData =
                                        snapshot.data!.data() as Map<String, dynamic>;
                                    final List<dynamic> updatedParticipants =
                                        updatedData['participants'] as List<dynamic>? ??
                                            [];
                                    final int participantes = updatedParticipants.length;
                                    final int maxPart = updatedData['maxParticipants'] ??
                                        plan.maxParticipants ??
                                        0;
                                    return Row(
                                      children: [
                                        Text(
                                          '$participantes/$maxPart',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        SvgPicture.asset(
                                          'assets/users.svg',
                                          color: AppColors.blue,
                                          width: 20,
                                          height: 20,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              caption,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Popup de confirmación de eliminar plan
  // --------------------------------------------------------------------------
  void _confirmDeletePlan(BuildContext context, PlanModel plan) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("¿Eliminar este plan?"),
          content: Text("Esta acción eliminará el plan ${plan.type}."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('plans')
                    .doc(plan.id)
                    .delete();
                final subs = await FirebaseFirestore.instance
                    .collection('subscriptions')
                    .where('id', isEqualTo: plan.id)
                    .get();
                for (var doc in subs.docs) {
                  await doc.reference.delete();
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Plan ${plan.type} eliminado correctamente.'),
                  ),
                );
              },
              child: const Text("Eliminar"),
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Placeholder para cuando no hay imagen o falla la carga
  // --------------------------------------------------------------------------
  Widget _buildPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.grey[200],
        height: 350,
        width: double.infinity,
        child: const Center(
          child: Icon(Icons.image, size: 40, color: Colors.grey),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Helper para icono + texto
  // --------------------------------------------------------------------------
  Widget _buildIconText({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
