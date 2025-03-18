// users_grid.dart
import 'dart:ui'; // Para BackdropFilter, ImageFilter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../main/colors.dart';
import '../../models/plan_model.dart';

// Revisado: usaremos el nuevo user_info_check.dart
import 'users_managing/user_info_check.dart';
import 'users_managing/user_info_inside_chat.dart';
import 'special_plans/invite_users_to_plan_screen.dart';
import 'users_managing/frosted_plan_dialog_state.dart';

class UsersGrid extends StatelessWidget {
  final void Function(dynamic userDoc)? onUserTap;
  final List<dynamic> users;

  const UsersGrid({
    Key? key,
    required this.users,
    this.onUserTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final userDoc = users[index];
        final Map<String, dynamic> userData = userDoc is QueryDocumentSnapshot
            ? (userDoc.data() as Map<String, dynamic>)
            : userDoc as Map<String, dynamic>;
        return _buildUserCard(userData, context);
      },
    );
  }

  /// Obtiene todos los planes creados por [userId].
  Future<List<PlanModel>> _fetchUserPlans(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('plans')
        .where('createdBy', isEqualTo: userId)
        .where('special_plan', isEqualTo: 0)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return PlanModel.fromMap(data);
    }).toList();
  }

  /// Función auxiliar para obtener todos los participantes de un plan.
  /// Se obtiene primero el creador y luego los suscriptores registrados.
  Future<List<Map<String, dynamic>>> _fetchPlanParticipants(PlanModel plan) async {
    List<Map<String, dynamic>> participants = [];
    final planDoc = await FirebaseFirestore.instance.collection('plans').doc(plan.id).get();
    if (planDoc.exists) {
      final planData = planDoc.data();
      final creatorId = planData?['createdBy'];
      if (creatorId != null) {
        final creatorUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(creatorId)
            .get();
        if (creatorUserDoc.exists && creatorUserDoc.data() != null) {
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
      final userId = sData['userId'];
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
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

  Widget _buildUserCard(Map<String, dynamic> userData, BuildContext context) {
    final String? uid = userData['uid']?.toString();
    if (uid == null) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: Text(
            'Usuario inválido',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return FutureBuilder<List<PlanModel>>(
      future: _fetchUserPlans(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 330,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            height: 330,
            child: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final plans = snapshot.data ?? [];
        if (plans.isEmpty) {
          // Sin planes
          return _buildNoPlanLayout(context, userData);
        } else {
          // Con planes: cada tarjeta se envuelve en GestureDetector para abrir el diálogo de detalles
          return Column(
            children: plans.map((plan) {
              return GestureDetector(
                onTap: () => _openPlanDetails(context, plan, userData),
                child: _buildPlanLayout(context, userData, plan),
              );
            }).toList(),
          );
        }
      },
    );
  }

  // -----------------------------------------------------------------------
  // Layout cuando NO tiene plan
  // -----------------------------------------------------------------------
  Widget _buildNoPlanLayout(BuildContext context, Map<String, dynamic> userData) {
    final String name = userData['name']?.toString().trim() ?? 'Usuario';
    final String userHandle = userData['handle']?.toString() ?? '@usuario';
    final String? uid = userData['uid']?.toString();
    final String? fallbackPhotoUrl = userData['photoUrl']?.toString();

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: 330,
        margin: const EdgeInsets.only(bottom: 15),
        child: Stack(
          children: [
            // Fondo (foto de perfil)
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: (fallbackPhotoUrl != null && fallbackPhotoUrl.isNotEmpty)
                  ? Image.network(
                      fallbackPhotoUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
            // Avatar + nombre (tap -> abre NUEVO user_info_check.dart)
            Positioned(
              top: 10,
              left: 10,
              child: GestureDetector(
                onTap: () {
                  if (uid != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserInfoCheck(userId: uid),
                      ),
                    );
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
            // Texto + icon + botones
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Container(
                  margin: const EdgeInsets.only(top: 100),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Texto con fondo frosted
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            color: const Color.fromARGB(255, 84, 78, 78).withOpacity(0.3),
                            child: const Text(
                              'Este usuario no ha creado planes aún...',
                              style: TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SvgPicture.asset(
                        'assets/sin-plan.svg',
                        width: 80,
                        height: 80,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 20),
                      // Botones: Invitar / Mensaje
                      _buildActionButtons(context, uid),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Layout cuando SÍ tiene plan
  // -----------------------------------------------------------------------
  Widget _buildPlanLayout(
    BuildContext context,
    Map<String, dynamic> userData,
    PlanModel plan,
  ) {
    final String name = userData['name']?.toString().trim() ?? 'Usuario';
    final String userHandle = userData['handle']?.toString() ?? '@usuario';
    final String? uid = userData['uid']?.toString();
    final String? fallbackPhotoUrl = userData['photoUrl']?.toString();
    final String? backgroundImage = plan.backgroundImage;
    final String caption = plan.description.isNotEmpty
        ? plan.description
        : 'Descripción breve o #hashtags';
    const String commentsCount = '173';
    const String sharesCount = '227';

    return Center(
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
            // Avatar + nombre (tap -> abre NUEVO user_info_check.dart)
            Positioned(
              top: 10,
              left: 10,
              child: GestureDetector(
                onTap: () {
                  if (uid != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserInfoCheck(userId: uid),
                      ),
                    );
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
            // Menú de opciones (compartir, like, unirse)
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFrostedIcon(
                    'assets/compartir.svg',
                    size: 40,
                    onTap: () {
                      final String shareUrl =
                          'https://plan-social-app.web.app/plan?planId=${plan.id}';
                      final String shareText = '¡Mira este plan!\n'
                          'Título: ${plan.type}\n'
                          'Descripción: $caption\n'
                          '¡Únete y participa!\n\n'
                          '$shareUrl';
                      Share.share(shareText);
                    },
                  ),
                  const SizedBox(width: 16),
                  LikeButton(plan: plan),
                  const SizedBox(width: 16),
                  _buildFrostedIcon(
                    'assets/union.svg',
                    size: 40,
                    onTap: () async {
                      // Unirse a un plan (código existente)
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;

                      if (plan.createdBy == user.uid) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No puedes unirte a tu propio plan')),
                        );
                        return;
                      }

                      if (plan.participants?.contains(user.uid) ?? false) {
                        _showCustomDialog(
                          context,
                          '¡Ya estás suscrito a este plan!',
                          durationSeconds: 2,
                        );
                        return;
                      }

                      final int participantes = plan.participants?.length ?? 0;
                      final int maxPart = plan.maxParticipants ?? 0;
                      if (participantes >= maxPart) {
                        _showCustomDialog(
                          context,
                          'El cupo máximo de participantes para este plan está cubierto',
                          durationSeconds: 3,
                        );
                        return;
                      }

                      final String planType =
                          plan.type.isNotEmpty ? plan.type : 'Plan';
                      await FirebaseFirestore.instance
                          .collection('notifications')
                          .add({
                        'type': 'join_request',
                        'receiverId': plan.createdBy,
                        'senderId': user.uid,
                        'planId': plan.id,
                        'planType': planType,
                        'timestamp': FieldValue.serverTimestamp(),
                        'read': false,
                      });
                      _showCustomDialog(
                        context,
                        '¡Tu solicitud de unión se ha enviado correctamente!',
                        durationSeconds: 3,
                      );
                    },
                  ),
                ],
              ),
            ),
            // Parte inferior: likes, comentarios, shares, etc.
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
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                            _buildIconText(
                              icon: Icons.favorite_border,
                              label: plan.likes.toString(),
                            ),
                            const SizedBox(width: 25),
                            _buildIconText(
                              icon: Icons.chat_bubble_outline,
                              label: commentsCount,
                            ),
                            const SizedBox(width: 25),
                            _buildIconText(
                              icon: Icons.share,
                              label: sharesCount,
                            ),
                            const Spacer(),
                            // Participantes: contador dinámico
                            Row(
                              children: [
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('plans')
                                      .doc(plan.id)
                                      .snapshots(),
                                  builder: (context, snap) {
                                    if (!snap.hasData || !snap.data!.exists) {
                                      return const Text('0/0',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ));
                                    }
                                    final data = snap.data!.data() as Map<String, dynamic>;
                                    final updatedList = data['participants'] as List<dynamic>? ?? [];
                                    final updatedCount = updatedList.length;
                                    final updatedMax = data['maxParticipants'] ?? 0;
                                    return Text(
                                      '$updatedCount/$updatedMax',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    );
                                  },
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
    );
  }

  /// Función para abrir los detalles del plan usando el diálogo FrostedPlanDialog.
  void _openPlanDetails(BuildContext context, PlanModel plan, Map<String, dynamic> userData) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FrostedPlanDialog(
          plan: plan,
          fetchParticipants: _fetchPlanParticipants,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // Botones de acción (Invitar / Chat)
  // -----------------------------------------------------------------------
  Widget _buildActionButtons(BuildContext context, String? userId) {
    final String safeUserId = userId ?? '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          context: context,
          iconPath: 'assets/agregar-usuario.svg',
          label: 'Invítale a un Plan',
          onTap: () {
            if (userId != null && userId.isNotEmpty) {
              InviteUsersToPlanScreen.showPopup(context, userId);
            }
          },
        ),
        const SizedBox(width: 16),
        _buildActionButton(
          context: context,
          iconPath: 'assets/mensaje.svg',
          label: null,
          onTap: () {
            showGeneralDialog(
              context: context,
              barrierDismissible: true,
              barrierLabel: 'Cerrar',
              barrierColor: Colors.transparent,
              transitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (_, __, ___) => const SizedBox(),
              transitionBuilder: (ctx, anim1, anim2, child) {
                return FadeTransition(
                  opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
                  child: UserInfoInsideChat(
                    key: ValueKey(safeUserId),
                    chatPartnerId: safeUserId,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String iconPath,
    String? label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color.fromARGB(255, 84, 78, 78).withOpacity(0.3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  iconPath,
                  width: 32,
                  height: 32,
                  color: Colors.white,
                ),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Helper: iconos frost
  // -----------------------------------------------------------------------
  Widget _buildFrostedIcon(String assetPath,
      {double size = 40, Color iconColor = Colors.white, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
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

  // -----------------------------------------------------------------------
  // Helper para el avatar
  // -----------------------------------------------------------------------
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

  // -----------------------------------------------------------------------
  // Placeholder
  // -----------------------------------------------------------------------
  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.person, size: 40, color: Colors.grey),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Icon + texto (likes, comentarios, etc.)
  // -----------------------------------------------------------------------
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

  // -----------------------------------------------------------------------
  // Pequeña función para mostrar un diálogo centrado
  // -----------------------------------------------------------------------
  void _showCustomDialog(BuildContext context, String message, {int durationSeconds = 2}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
                fontFamily: 'Inter',
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
    Future.delayed(Duration(seconds: durationSeconds), () {
      Navigator.of(context).pop();
    });
  }
}

/// LikeButton (se queda igual)
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
          filter: ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
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
