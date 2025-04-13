import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/plan_model.dart';
import '../../main/colors.dart';

// Importamos funciones y widgets que hemos movido a otros archivos:
import 'firebase_services.dart';
import 'users_grid_helpers.dart';
import 'plan_card.dart';
import '../special_plans/invite_users_to_plan_screen.dart';
import '../users_managing/user_info_check.dart';
import '../users_managing/user_info_inside_chat.dart';

/// Este Widget muestra una lista de usuarios (y cada uno puede tener 0 o varios planes).
/// Si un usuario no tiene planes, se renderiza `_buildNoPlanLayout`.
/// De lo contrario, cada plan se muestra con un `_PlanCard`.
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

  //--------------------------------------------------------------------------
  // Construye la “tarjeta” de cada usuario, chequeando primero sus planes.
  //--------------------------------------------------------------------------
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
      future: fetchUserPlans(uid), // Llamamos a la función en firebase_services.dart
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
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final plans = snapshot.data ?? [];
        if (plans.isEmpty) {
          return _buildNoPlanLayout(context, userData);
        } else {
          return Column(
            children: plans.map((plan) {
              return PlanCard(
                plan: plan,
                userData: userData,
                fetchParticipants: fetchPlanParticipants, 
              );
            }).toList(),
          );
        }
      },
    );
  }

  //--------------------------------------------------------------------------
  // Si el usuario no tiene planes creados, se muestra este layout.
  //--------------------------------------------------------------------------
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
            // Imagen de fondo (o placeholder)
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

            // Info del usuario (arriba a la izquierda)
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
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: const Color.fromARGB(255, 14, 14, 14).withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          buildProfileAvatar(fallbackPhotoUrl),
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

            // Mensaje central indicando que no hay planes...
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
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

  //--------------------------------------------------------------------------
  // Botones que se muestran cuando el usuario no tiene planes (Invitar / Mensaje)
  //--------------------------------------------------------------------------
  Widget _buildActionButtons(BuildContext context, String? userId) {
    final String safeUserId = userId ?? '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Invitar a un plan
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
        // Mensaje
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

  //--------------------------------------------------------------------------
  // Helper para cada botón redondeado
  //--------------------------------------------------------------------------
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
