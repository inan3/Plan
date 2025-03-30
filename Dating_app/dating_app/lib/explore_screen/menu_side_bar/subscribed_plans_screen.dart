import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Importa la clase real FrostedPlanDialog desde el archivo adecuado.
import '../users_managing/frosted_plan_dialog_state.dart' as new_frosted;

import '../../models/plan_model.dart';
import '../../main/colors.dart';
import '../../utils/plans_list.dart' as plansData;

class SubscribedPlansScreen extends StatelessWidget {
  final String userId;
  const SubscribedPlansScreen({Key? key, required this.userId}) : super(key: key);

  // Método para obtener todos los participantes de un plan (creador + suscriptores).
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];

    final planDoc = await FirebaseFirestore.instance.collection('plans').doc(plan.id).get();
    if (planDoc.exists) {
      final planData = planDoc.data();
      final creatorId = planData?['createdBy'];
      if (creatorId != null) {
        final creatorUserDoc = await FirebaseFirestore.instance.collection('users').doc(creatorId).get();
        if (creatorUserDoc.exists) {
          final cdata = creatorUserDoc.data()!;
          participants.add({
            'name': cdata['name'] ?? 'Sin nombre',
            'age': cdata['age']?.toString() ?? '',
            'photoUrl': cdata['photoUrl'] ?? cdata['profilePic'] ?? '',
            'isCreator': true,
          });
        }
      }
    }

    final subsSnap = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('id', isEqualTo: plan.id)
        .get();
    for (var sDoc in subsSnap.docs) {
      final sData = sDoc.data();
      final uid = sData['userId'];
      if (uid == null) continue;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final uData = userDoc.data()!;
        participants.add({
          'name': uData['name'] ?? 'Sin nombre',
          'age': uData['age']?.toString() ?? '',
          'photoUrl': uData['photoUrl'] ?? uData['profilePic'] ?? '',
          'isCreator': false,
        });
      }
    }
    return participants;
  }

  // Método auxiliar para obtener los planes completos desde la colección 'plans'
  Future<List<PlanModel>> _fetchPlansFromIds(List<String> planIds) async {
    if (planIds.isEmpty) return [];
    final List<PlanModel> plans = [];
    for (String planId in planIds) {
      final planDoc = await FirebaseFirestore.instance.collection('plans').doc(planId).get();
      if (planDoc.exists) {
        final planData = planDoc.data() as Map<String, dynamic>;
        planData['id'] = planDoc.id;
        plans.add(PlanModel.fromMap(planData));
      }
    }
    return plans;
  }

  // Construye cada tarjeta de plan.
  Widget _buildPlanCard(BuildContext context, Map<String, dynamic> userData, PlanModel plan) {
    final String name = userData['name']?.toString().trim() ?? 'Usuario';
    final String userHandle = userData['handle']?.toString() ?? '@usuario';
    final String? fallbackPhotoUrl = userData['photoUrl']?.toString();
    final String? backgroundImage = plan.backgroundImage;
    final String caption = plan.description.isNotEmpty ? plan.description : 'Descripción breve o #hashtags';
    const String sharesCount = '227';

    // Si es un plan especial, se aplica un estilo específico.
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
          final Widget creatorAvatar = participants.isNotEmpty && (participants[0]['photoUrl'] ?? '').isNotEmpty
              ? CircleAvatar(
                  backgroundImage: NetworkImage(participants[0]['photoUrl']),
                  radius: 20,
                )
              : const CircleAvatar(radius: 20);
          final Widget participantAvatar = participants.length > 1 && (participants[1]['photoUrl'] ?? '').isNotEmpty
              ? CircleAvatar(
                  backgroundImage: NetworkImage(participants[1]['photoUrl']),
                  radius: 20,
                )
              : const SizedBox();
          String iconPath = plan.iconAsset ?? '';
          for (var item in plansData.plans) {
            if (plan.iconAsset == item['icon']) {
              iconPath = item['icon'];
              break;
            }
          }
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              showGeneralDialog(
                context: context,
                barrierDismissible: true,
                barrierLabel: 'Cerrar',
                transitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (context, animation, secondaryAnimation) {
                  return SafeArea(
                    child: Align(
                      alignment: Alignment.center,
                      child: Material(
                        color: Colors.transparent,
                        child: new_frosted.FrostedPlanDialog(
                          plan: plan,
                          fetchParticipants: _fetchAllPlanParticipants,
                        ),
                      ),
                    ),
                  );
                },
                transitionBuilder: (context, anim1, anim2, child) {
                  return FadeTransition(opacity: anim1, child: child);
                },
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
                    // Lado izquierdo: icono + tipo de plan
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
                          style: const TextStyle(fontSize: 20, color: Colors.white),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Lado derecho: avatares de participantes
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
      // Para un plan normal, usamos un StreamBuilder para actualizar likes, commentsCount y participants en tiempo real
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('plans').doc(plan.id).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const SizedBox(
              height: 330,
              child: Center(
                child: Text(
                  'Plan no encontrado',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          final updatedData = snapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> updatedParticipants = updatedData['participants'] as List<dynamic>? ?? [];
          final int participantes = updatedParticipants.length;
          final int maxPart = updatedData['maxParticipants'] ?? plan.maxParticipants ?? 0;
          final int commentsCount = updatedData['commentsCount'] ?? 0;
          final int likesCount = updatedData['likes'] ?? plan.likes;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              showGeneralDialog(
                context: context,
                barrierDismissible: true,
                barrierLabel: 'Cerrar',
                transitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (context, animation, secondaryAnimation) {
                  return SafeArea(
                    child: Align(
                      alignment: Alignment.center,
                      child: Material(
                        color: Colors.transparent,
                        child: new_frosted.FrostedPlanDialog(
                          plan: plan,
                          fetchParticipants: _fetchAllPlanParticipants,
                        ),
                      ),
                    ),
                  );
                },
                transitionBuilder: (context, anim1, anim2, child) {
                  return FadeTransition(opacity: anim1, child: child);
                },
              );
            },
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: 330,
                margin: const EdgeInsets.only(bottom: 15),
                child: Stack(
                  children: [
                    // Imagen de fondo.
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
                    // Avatar + nombre en la esquina superior izquierda.
                    Positioned(
                      top: 10,
                      left: 10,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            color: const Color.fromARGB(255, 14, 14, 14).withOpacity(0.2),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildProfileAvatar(fallbackPhotoUrl),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        SvgPicture.asset(
                                          'assets/verificado.svg',
                                          width: 14,
                                          height: 14,
                                          color: Colors.blueAccent,
                                        ),
                                      ],
                                    ),
                                    Text(
                                      userHandle,
                                      style: const TextStyle(fontSize: 12, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Botones en la esquina superior derecha: menú y botón de abandonar.
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Row(
                        children: [
                          _buildThreeDotsMenu(userData, plan),
                          const SizedBox(width: 16),
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
                                  child: const Icon(Icons.exit_to_app, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Parte inferior: contadores e información adicional.
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                                    _buildIconText(icon: Icons.favorite_border, label: likesCount.toString()),
                                    const SizedBox(width: 25),
                                    _buildIconText(icon: Icons.chat_bubble_outline, label: commentsCount.toString()),
                                    const SizedBox(width: 25),
                                    _buildIconText(icon: Icons.share, label: sharesCount),
                                    const Spacer(),
                                    // Aquí se muestra el número actual de participantes y el máximo permitido.
                                    Row(
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
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  caption,
                                  style: const TextStyle(fontSize: 13, color: Colors.white),
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
        },
      );
    }
  }

  // Menú de opciones (fila de 3 iconos frosted).
  Widget _buildThreeDotsMenu(Map<String, dynamic> userData, PlanModel plan) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFrostedIcon(
          'assets/compartir.svg',
          size: 40,
          onTap: () {
            // Acción para compartir.
          },
        ),
        // Aquí podrías incluir un LikeButton, etc. si quieres
        // LikeButton(plan: plan),
      ],
    );
  }

  // Helper para construir un icono con efecto frosted.
  Widget _buildFrostedIcon(
    String assetPath, {
    double size = 40,
    Color iconColor = Colors.white,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 175, 173, 173).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                assetPath,
                width: size * 0.5,
                height: size * 0.5,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper para construir el avatar de perfil.
  Widget _buildProfileAvatar(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(photoUrl),
      );
    } else {
      return const CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, color: Colors.white),
      );
    }
  }

  // Popup de confirmación para abandonar un plan.
  void _confirmDeletePlan(BuildContext context, PlanModel plan) {
    final String currentUserId = userId; // Id del usuario actual (suscriptor)
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("¿Quieres abandonar este plan?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("No"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                // Se elimina solo el registro de suscripción para abandonar el plan.
                final subs = await FirebaseFirestore.instance
                    .collection('subscriptions')
                    .where('userId', isEqualTo: currentUserId)
                    .where('id', isEqualTo: plan.id)
                    .get();
                for (var doc in subs.docs) {
                  await doc.reference.delete();
                }
                // Actualiza el documento del plan removiendo al usuario de 'participants'
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
                Navigator.pop(context);
              },
              child: const Text("Si"),
            ),
          ],
        );
      },
    );
  }

  // Placeholder para cuando no hay imagen o falla la carga.
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

  // Helper para mostrar un icono junto a un texto.
  Widget _buildIconText({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('subscriptions')
            .where('userId', isEqualTo: userId)
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
                      final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                      return _buildPlanCard(context, userData, plan);
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
