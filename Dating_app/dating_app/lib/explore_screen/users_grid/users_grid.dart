//user_grid.dart
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/plan_model.dart';
import '../../main/colors.dart';
import '../plans_managing/firebase_services.dart';
import 'users_grid_helpers.dart';
import '../plans_managing/plan_card.dart';
import '../special_plans/invite_users_to_plan_screen.dart';
import '../users_managing/user_info_check.dart';
import '../chats/chat_screen.dart';

// Importa nuestro widget que usa RTDB:
import '../users_managing/user_activity_status.dart';

class UsersGrid extends StatelessWidget {
  final void Function(dynamic userDoc)? onUserTap;
  final List<dynamic> users;

  const UsersGrid({
    Key? key,
    required this.users,
    this.onUserTap,
  }) : super(key: key);

  // ──────────────────────────────────────────────────────────────────────────
  //  HELPERS DE BLOQUEO
  // ──────────────────────────────────────────────────────────────────────────
  Future<bool> _isBlocked(String otherId) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return false;

    // Documento “blockerId_blockedId”
    final docId = '${otherId}_${me.uid}';
    final doc = await FirebaseFirestore.instance
        .collection('blocked_users')
        .doc(docId)
        .get();

    return doc.exists;
  }

  void _showBlockedSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('No puedes interactuar con este perfil porque te ha bloqueado.'),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  INVITAR / MENSAJE (con bloqueo)
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _handleInvite(BuildContext ctx, String userId) async {
    if (await _isBlocked(userId)) {
      _showBlockedSnack(ctx);
      return;
    }
    InviteUsersToPlanScreen.showPopup(ctx, userId);
  }

  /// Lógica para abrir chat con validación de privacidad y si le sigues, etc.
  Future<void> _handleMessage(BuildContext ctx, String userId) async {
    // 1) Verificamos si te ha bloqueado
    if (await _isBlocked(userId)) {
      _showBlockedSnack(ctx);
      return;
    }

    // 2) Obtenemos doc del receptor
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (!userDoc.exists) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text("El usuario no existe o fue borrado."),
      ));
      return;
    }

    final userData = userDoc.data()!;
    final isPrivate = (userData['profile_privacy'] ?? 0) == 1;

    // 3) Si es privado, comprueba si le sigo
    if (isPrivate) {
      final me = FirebaseAuth.instance.currentUser;
      if (me == null) return;

      final q = await FirebaseFirestore.instance
          .collection('followed')
          .where('userId', isEqualTo: me.uid)
          .where('followedId', isEqualTo: userId)
          .limit(1)
          .get();

      final amIFollowing = q.docs.isNotEmpty;
      if (!amIFollowing) {
        showDialog(
          context: ctx,
          builder: (_) => AlertDialog(
            title: const Text("Perfil privado"),
            content: const Text("Debes seguir a este usuario para interactuar."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cerrar"),
              ),
            ],
          ),
        );
        return;
      }
    }

    // 4) Abrimos ChatScreen
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatPartnerId: userId,
          chatPartnerName: userData['name'] ?? 'Usuario',
          chatPartnerPhoto: userData['photoUrl'] ?? '',
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────────────────────────────────
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

  // ──────────────────────────────────────────────────────────────────────────
  //  Tarjeta por usuario
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildUserCard(Map<String, dynamic> userData, BuildContext context) {
    final String? uid = userData['uid']?.toString();
    if (uid == null) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: Text('Usuario inválido', style: TextStyle(color: Colors.red)),
        ),
      );
    }

    return FutureBuilder<List<PlanModel>>(
      future: fetchUserPlans(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
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
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            ),
          );
        }

        final plans = snapshot.data ?? [];
        if (plans.isEmpty) {
          return _buildNoPlanLayout(context, userData);
        } else {
          return Column(
            children: plans
                .map((plan) => PlanCard(
                      plan: plan,
                      userData: userData,
                      fetchParticipants: fetchPlanParticipants,
                    ))
                .toList(),
          );
        }
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Layout usuario SIN planes
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildNoPlanLayout(
      BuildContext context, Map<String, dynamic> userData) {
    final String name = userData['name']?.toString().trim() ?? 'Usuario';
    final String? uid = userData['uid']?.toString();
    final String? fallbackPhotoUrl = userData['photoUrl']?.toString();

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
              child: (fallbackPhotoUrl != null && fallbackPhotoUrl.isNotEmpty)
                  ? Image.network(
                      fallbackPhotoUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => buildPlaceholder(),
                    )
                  : buildPlaceholder(),
            ),

            // Bloque superior con avatar + nombre + estado de actividad
            Positioned(
              top: 10,
              left: 10,
              child: GestureDetector(
                onTap: () {
                  if (uid != null) UserInfoCheck.open(context, uid);
                },
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
                          buildProfileAvatar(fallbackPhotoUrl),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nombre y verificado
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
                              // AQUI LLAMAMOS AL WIDGET DE PRESENCIA
                              if (uid != null)
                                UserActivityStatus(
                                  userId: uid,
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

            // Mensaje central y botones
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  margin: const EdgeInsets.only(top: 100),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            color: const Color.fromARGB(255, 84, 78, 78)
                                .withOpacity(0.3),
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

  // ──────────────────────────────────────────────────────────────────────────
  //  Botones (invitar / mensaje) con verificación de bloqueo
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildActionButtons(BuildContext context, String? userId) {
    if (userId == null || userId.isEmpty) return const SizedBox();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          context: context,
          iconPath: 'assets/agregar-usuario.svg',
          label: 'Invítale a un Plan',
          onTap: () => _handleInvite(context, userId),
        ),
        const SizedBox(width: 16),
        _buildActionButton(
          context: context,
          iconPath: 'assets/mensaje.svg',
          label: null,
          onTap: () => _handleMessage(context, userId),
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
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
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
}
