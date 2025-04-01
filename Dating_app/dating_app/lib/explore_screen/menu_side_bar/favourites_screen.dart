import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';

// 1) Importamos el archivo con el diálogo FrostedPlanDialog real:
import '../users_managing/frosted_plan_dialog_state.dart' as new_frosted;
import '../users_managing/user_info_check.dart' as profile_readonly;

import '../../models/plan_model.dart';
import '../../main/colors.dart';

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({Key? key}) : super(key: key);

  // ------------------------------------------------------------------------
  // Obtener todos los participantes (creador + suscriptores) de un plan
  // ------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(
      PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];

    final planDoc =
        await FirebaseFirestore.instance.collection('plans').doc(plan.id).get();
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
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
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

  // ------------------------------------------------------------------------
  // Pantalla principal: planes marcados como favoritos
  // ------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(
        child: Text(
          'Usuario no autenticado',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
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

        return FutureBuilder<List<PlanModel>>(
          future: _fetchPlansFromIds(favouritePlanIds),
          builder: (context, planSnapshot) {
            if (!planSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final plans = planSnapshot.data!;
            if (plans.isEmpty) {
              return const Center(
                child: Text(
                  'No tienes planes favoritos aún.',
                  style: TextStyle(color: Colors.white),
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

                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    return _buildPlanCard(context, userData, plan);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------------------
  // Obtener planes completos desde la colección 'plans'
  // ------------------------------------------------------------------------
  Future<List<PlanModel>> _fetchPlansFromIds(List<String> planIds) async {
    if (planIds.isEmpty) return [];

    final List<PlanModel> plans = [];
    for (String planId in planIds) {
      final planDoc =
          await FirebaseFirestore.instance.collection('plans').doc(planId).get();
      if (planDoc.exists) {
        final planData = planDoc.data() as Map<String, dynamic>;
        // Aseguramos que planData tenga el id
        planData['id'] = planDoc.id;
        plans.add(PlanModel.fromMap(planData));
      }
    }
    return plans;
  }

  // ------------------------------------------------------------------------
  // Construir una tarjeta de plan (con fondo, avatar, etc.)
  // Al pulsar, mostramos FrostedPlanDialog A PANTALLA COMPLETA
  // ------------------------------------------------------------------------
  Widget _buildPlanCard(
      BuildContext context, Map<String, dynamic> userData, PlanModel plan) {
    final String name = userData['name']?.toString().trim() ?? 'Usuario';
    final String userHandle = userData['handle']?.toString() ?? '@usuario';
    final String? fallbackPhotoUrl = userData['photoUrl']?.toString();
    final String? backgroundImage = plan.backgroundImage;
    final String caption = plan.description.isNotEmpty
        ? plan.description
        : 'Descripción breve o #hashtags';
    const String sharesCount = '227';

    return GestureDetector(
      onTap: () {
        // Abre los detalles del plan a pantalla completa
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
              // Avatar + nombre en la esquina superior izquierda.
              Positioned(
                top: 10,
                left: 10,
                child: GestureDetector(
                  onTap: () {
                    // Obtén el uid: si userData tiene 'uid', lo usamos; de lo contrario, usamos plan.createdBy.
                    final String? uid = userData['uid']?.toString() ?? plan.createdBy;
                    if (uid != null && uid.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => profile_readonly.UserInfoCheck(userId: uid),
                        ),
                      );
                    }
                  },
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
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Menú con 3 iconos en la esquina superior derecha
              Positioned(
                top: 16,
                right: 16,
                child: _buildThreeDotsMenu(userData, plan),
              ),
              // Parte inferior: contadores + descripción (lee commentsCount en tiempo real)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('plans')
                      .doc(plan.id)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData || !snap.data!.exists) {
                      return _buildBottomStats(
                        likesValue: plan.likes,
                        commentsValue: 0,
                        sharesValue: sharesCount,
                        caption: caption,
                      );
                    }
                    final data = snap.data!.data() as Map<String, dynamic>;
                    final comments = data['commentsCount'] ?? 0;
                    final likes = data['likes'] ?? plan.likes;

                    return _buildBottomStats(
                      likesValue: likes,
                      commentsValue: comments,
                      sharesValue: sharesCount,
                      caption: caption,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Muestra la parte inferior con likes, comments, shares y la descripción.
  Widget _buildBottomStats({
    required int likesValue,
    required int commentsValue,
    required String sharesValue,
    required String caption,
  }) {
    return ClipRRect(
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
                    label: likesValue.toString(),
                  ),
                  const SizedBox(width: 25),
                  _buildIconText(
                    icon: Icons.chat_bubble_outline,
                    label: commentsValue.toString(),
                  ),
                  const SizedBox(width: 25),
                  _buildIconText(
                    icon: Icons.share,
                    label: sharesValue,
                  ),
                  const Spacer(),
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
    );
  }

  // Menú de 3 iconos (compartir, like, unión)
  Widget _buildThreeDotsMenu(Map<String, dynamic> userData, PlanModel plan) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFrostedIcon(
          'assets/compartir.svg',
          size: 40,
          onTap: () {
            // Acción para compartir
          },
        ),
        const SizedBox(width: 16),
        LikeButton(plan: plan),
        const SizedBox(width: 16),
        _buildFrostedIcon(
          'assets/union.svg',
          size: 40,
          onTap: () {
            // Acción de unión o lo que necesites
          },
        ),
      ],
    );
  }

  // Helper para un icono con efecto frosted
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

  // Helper para avatar de perfil
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

  // Placeholder para cuando no hay imagen
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

  // Icono + texto
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

// ------------------------------------------------------------------------
// Botón de Like que actualiza el contador de likes y el array favourites
// ------------------------------------------------------------------------
class LikeButton extends StatefulWidget {
  final PlanModel plan;
  const LikeButton({Key? key, required this.plan}) : super(key: key);

  @override
  _LikeButtonState createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool liked = false;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await userRef.get();
    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data() as Map<String, dynamic>;
      final favourites = data['favourites'] as List<dynamic>? ?? [];
      if (favourites.contains(widget.plan.id)) {
        setState(() {
          liked = true;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final planRef = FirebaseFirestore.instance.collection('plans').doc(widget.plan.id);
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    // Actualizamos contador 'likes' en la colección 'plans'.
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(planRef);
      if (!snapshot.exists) return;
      int currentLikes = snapshot.data()!['likes'] ?? 0;
      if (!liked) {
        currentLikes++;
      } else {
        currentLikes = currentLikes > 0 ? currentLikes - 1 : 0;
      }
      transaction.update(planRef, {'likes': currentLikes});
    });

    // Actualizamos el array 'favourites' en 'users'.
    if (!liked) {
      await userRef.update({
        'favourites': FieldValue.arrayUnion([widget.plan.id])
      });
    } else {
      await userRef.update({
        'favourites': FieldValue.arrayRemove([widget.plan.id])
      });
    }

    setState(() {
      liked = !liked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleLike,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 175, 173, 173).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/corazon.svg',
                width: 20,
                height: 20,
                color: liked ? Colors.red : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
