import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/plan_model.dart';
import '../../main/colors.dart';
import '../../utils/plans_list.dart' as plansData;
// Importa tu FrostedPlanDialog (alias si gustas)
import '../users_managing/frosted_plan_dialog_state.dart' as new_frosted;

// ---------------------------------------------------------------------------
// Pantalla donde se listan los planes a los que un usuario se ha suscrito
// ---------------------------------------------------------------------------
class SubscribedPlansScreen extends StatelessWidget {
  final String userId;

  const SubscribedPlansScreen({Key? key, required this.userId})
      : super(key: key);

  // --------------------------------------------------------------------------
  // Mostrar el FrostedPlanDialog a pantalla completa al pulsar la tarjeta
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
              fetchParticipants: _fetchAllPlanParticipants, // <-- usamos abajo
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

    // 1) Traemos el documento del plan
    final planDoc = await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .get();

    if (!planDoc.exists) {
      // Si el plan ya no existe, devolvemos vacío
      return participants;
    }

    final planData = planDoc.data()!;
    // Este campo 'participants' debe ser una lista de UIDs (strings)
    final participantUids = List<String>.from(planData['participants'] ?? []);

    // 2) Por cada UID en participants, cargamos datos del usuario
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
          // Marcamos si este UID es el creador
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
        // Ponemos 'id' manualmente porque no vendrá dentro de data()
        planData['id'] = planDoc.id;
        plans.add(PlanModel.fromMap(planData));
      }
    }
    return plans;
  }

  // --------------------------------------------------------------------------
  // Construye la tarjeta del plan
  // --------------------------------------------------------------------------
  Widget _buildPlanCard(
    BuildContext context,
    Map<String, dynamic> userData,
    PlanModel plan,
  ) {
    final String name = userData['name']?.toString().trim() ?? 'Usuario';
    final String userHandle = userData['handle']?.toString() ?? '@usuario';
    final String? fallbackPhotoUrl = userData['photoUrl']?.toString();
    final String? backgroundImage = plan.backgroundImage;
    final String caption = plan.description.isNotEmpty
        ? plan.description
        : 'Descripción breve o #hashtags';
    const String sharesCount = '227'; // Hardcodeado por ahora

    // Plan especial
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

    // Plan normal
    else {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('plans')
            .doc(plan.id)
            .snapshots(),
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
          final List<dynamic> updatedParticipants =
              updatedData['participants'] as List<dynamic>? ?? [];
          final int participantes = updatedParticipants.length;
          final int maxPart =
              updatedData['maxParticipants'] ?? plan.maxParticipants ?? 0;
          final int commentsCount = updatedData['commentsCount'] ?? 0;
          final int likesCount = updatedData['likes'] ?? plan.likes;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showFrostedPlanDialog(context, plan),
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
                      child: (backgroundImage != null &&
                              backgroundImage.isNotEmpty)
                          ? Image.network(
                              backgroundImage,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),

                    // Avatar + nombre (esquina sup izq)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            color:
                                const Color.fromARGB(255, 14, 14, 14).withOpacity(0.2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
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
                                          fontSize: 12, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Botones (esquina sup der): compartir y abandonar
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Row(
                        children: [
                          // Icono compartir
                          _buildThreeDotsMenu(context, userData, plan),
                          const SizedBox(width: 16),
                          // Botón "Abandonar"
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
                                    Icons.exit_to_app,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Parte inferior: contadores
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
                                horizontal: 10, vertical: 8),
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
                                      label: likesCount.toString(),
                                    ),
                                    const SizedBox(width: 25),
                                    _buildIconText(
                                      icon: Icons.chat_bubble_outline,
                                      label: commentsCount.toString(),
                                    ),
                                    const SizedBox(width: 25),
                                    _buildIconText(
                                      icon: Icons.share,
                                      label: sharesCount,
                                    ),
                                    const Spacer(),
                                    // Participantes / máx
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
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.white),
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

  // --------------------------------------------------------------------------
  // Menú / icono para "compartir"
  // --------------------------------------------------------------------------
  Widget _buildThreeDotsMenu(
    BuildContext context,
    Map<String, dynamic> userData,
    PlanModel plan,
  ) {
    return Row(
      children: [
        // Icono compartir (SVG)
        _buildFrostedIcon(
          'assets/compartir.svg',
          size: 40,
          onTap: () {
            _openCustomShareModal(context, plan);
          },
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Abre el BottomSheet para compartir
  // --------------------------------------------------------------------------
  void _openCustomShareModal(BuildContext context, PlanModel plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 35, 57, 80),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Handle para arrastrar
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white54,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Botón "Compartir con otras apps"
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Text(
                          "Compartir con otras apps",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.white),
                          onPressed: () {
                            final String shareUrl =
                                'https://plan-social-app.web.app/plan?planId=${plan.id}';
                            final shareText =
                                '¡Mira este plan!\n\nTítulo: ${plan.type}\nDescripción: ${plan.description}\n$shareUrl';
                            Share.share(shareText);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Sección para compartir dentro de la app
                  Expanded(
                    child: _CustomShareDialogContent(
                      plan: plan,
                      scrollController: scrollController,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Widget icónico con blur (para iconos en la esquina)
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Confirmación para "abandonar" plan
  // --------------------------------------------------------------------------
  void _confirmDeletePlan(BuildContext context, PlanModel plan) {
    final String currentUserId = userId;
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
  // Placeholder de imagen
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
  // Icono + Texto (likes, comentarios, etc.)
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

  // --------------------------------------------------------------------------
  // Construye el avatar (si hay fotoUrl)
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Build principal: muestra la lista de planes a los que estoy suscrito
  // (lee los IDs desde 'subscriptions' -> planId, y luego obtiene su info)
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
              // Mostramos cada plan
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
                      // Construimos la tarjeta final del plan
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

// ---------------------------------------------------------------------------
// Contenido del BottomSheet para compartir el plan dentro de la app
// ---------------------------------------------------------------------------
class _CustomShareDialogContent extends StatefulWidget {
  final PlanModel plan;
  final ScrollController scrollController;

  const _CustomShareDialogContent({
    Key? key,
    required this.plan,
    required this.scrollController,
  }) : super(key: key);

  @override
  State<_CustomShareDialogContent> createState() =>
      _CustomShareDialogContentState();
}

class _CustomShareDialogContentState extends State<_CustomShareDialogContent> {
  final TextEditingController _searchController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Listas de usuarios (followers / following)
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];

  // Conjunto de UIDs seleccionados
  final Set<String> _selectedUsers = {};

  @override
  void initState() {
    super.initState();
    _fetchFollowersAndFollowing();
  }

  /// Carga "followers" y "followed" desde Firestore.
  Future<void> _fetchFollowersAndFollowing() async {
    if (_currentUser == null) return;
    try {
      // 1) Followers => docs donde userId = mi UID
      final snapFollowers = await FirebaseFirestore.instance
          .collection('followers')
          .where('userId', isEqualTo: _currentUser!.uid)
          .get();

      final followerUids = <String>[];
      for (var doc in snapFollowers.docs) {
        final data = doc.data();
        final fid = data['followerId'] as String?;
        if (fid != null) followerUids.add(fid);
      }

      // 2) Following => docs donde userId = mi UID
      final snapFollowing = await FirebaseFirestore.instance
          .collection('followed')
          .where('userId', isEqualTo: _currentUser!.uid)
          .get();

      final followedUids = <String>[];
      for (var doc in snapFollowing.docs) {
        final data = doc.data();
        final fid = data['followedId'] as String?;
        if (fid != null) followedUids.add(fid);
      }

      // 3) Cargar info de cada uno
      _followers = await _fetchUsersData(followerUids);
      _following = await _fetchUsersData(followedUids);

      setState(() {});
    } catch (e) {
      debugPrint("Error al cargar followers/following: $e");
    }
  }

  /// Retorna la info de cada UID en 'users'
  Future<List<Map<String, dynamic>>> _fetchUsersData(List<String> uids) async {
    if (uids.isEmpty) return [];
    final List<Map<String, dynamic>> usersData = [];
    for (String uid in uids) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        usersData.add({
          'uid': uid,
          'name': data['name'] ?? 'Usuario',
          'age': data['age']?.toString() ?? '',
          'photoUrl': data['photoUrl'] ?? '',
        });
      }
    }
    return usersData;
  }

  /// Envía el plan a los usuarios seleccionados (creando docs en "messages", por ejemplo)
  Future<void> _sendPlanToSelectedUsers() async {
    if (_currentUser == null || _selectedUsers.isEmpty) {
      Navigator.pop(context); // No hay nada que enviar
      return;
    }

    final String shareUrl =
        'https://plan-social-app.web.app/plan?planId=${widget.plan.id}';
    final String planId = widget.plan.id;
    final String planTitle = widget.plan.type;
    final String planDesc = widget.plan.description;
    final String? planImage = widget.plan.backgroundImage;

    // Guardar un doc en 'messages' para cada usuario seleccionado
    for (String uidDestino in _selectedUsers) {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': _currentUser!.uid,
        'receiverId': uidDestino,
        'participants': [_currentUser!.uid, uidDestino],
        'type': 'shared_plan',
        'planId': planId,
        'planTitle': planTitle,
        'planDescription': planDesc,
        'planImage': planImage ?? '',
        'planLink': shareUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }

    Navigator.pop(context); // Cerrar bottom sheet
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra sup: "Cancelar" - "Enviar"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  "Cancelar",
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _sendPlanToSelectedUsers,
                child: const Text(
                  "Enviar",
                  style: TextStyle(color: Colors.green, fontSize: 16),
                ),
              ),
            ],
          ),
        ),

        // Cuadro de búsqueda
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Buscar usuario...",
              hintStyle: const TextStyle(color: Colors.white60),
              prefixIcon: const Icon(Icons.search, color: Colors.white60),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) {
              setState(() {}); // refresca el filtrado
            },
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Mis seguidores"
                const SizedBox(height: 6),
                const Text(
                  "Mis seguidores",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                _buildUserList(_filterUsers(_followers)),

                const SizedBox(height: 12),

                // "A quienes sigo"
                const Text(
                  "A quienes sigo",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                _buildUserList(_filterUsers(_following)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Filtra por texto
  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> users) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return users;
    return users.where((u) {
      final name = (u['name'] ?? '').toLowerCase();
      return name.contains(query);
    }).toList();
  }

  // Lista con "checkbox" circular
  Widget _buildUserList(List<Map<String, dynamic>> userList) {
    if (userList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "No hay usuarios en esta sección.",
          style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Column(
      children: userList.map((user) {
        final uid = user['uid'] ?? '';
        final name = user['name'] ?? 'Usuario';
        final age = user['age'] ?? '';
        final photo = user['photoUrl'] ?? '';
        final isSelected = _selectedUsers.contains(uid);

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blueGrey,
              backgroundImage: (photo.isNotEmpty) ? NetworkImage(photo) : null,
            ),
            title: Text(
              "$name, $age",
              style: const TextStyle(color: Colors.white),
            ),
            trailing: GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedUsers.remove(uid);
                  } else {
                    _selectedUsers.add(uid);
                  }
                });
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.green : Colors.white54,
                    width: 2,
                  ),
                  color: isSelected ? Colors.green : Colors.transparent,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
