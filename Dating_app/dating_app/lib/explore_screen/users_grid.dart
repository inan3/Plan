import 'dart:ui'; // Para BackdropFilter, ImageFilter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../main/colors.dart';
import '../../models/plan_model.dart';

// Ajusta según tu proyecto
import 'users_managing/user_info_inside_chat.dart';
import 'users_managing/user_info_check.dart'; // Contiene FrostedPlanDialog, etc.
import 'options_for_plans.dart'; // Para el menú de 3 puntos (si lo usas)

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
      padding: EdgeInsets.zero,
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
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return PlanModel.fromMap(data);
    }).toList();
  }

  /// Devuelve la lista con SOLO el creador, en caso de que no haya participantes.
  Future<List<Map<String, dynamic>>> _fetchCreatorOnly(String creatorUid) async {
    if (creatorUid.isEmpty) return [];

    final creatorDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(creatorUid)
        .get();

    if (!creatorDoc.exists) return [];

    final userData = creatorDoc.data() as Map<String, dynamic>;
    return [
      {
        'isCreator': true,
        'photoUrl': userData['photoUrl'] ?? '',
        'name': userData['name'] ?? 'Usuario',
        'age': (userData['age'] ?? '').toString(),
      }
    ];
  }

  /// Busca el doc del plan y construye la lista: primero el creador, luego los participantes.
  Future<List<Map<String, dynamic>>> _fetchPlanParticipants(PlanModel plan) async {
    final docSnap = await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .get();

    if (!docSnap.exists) return [];

    final data = docSnap.data() as Map<String, dynamic>;

    // Suponiendo que en Firestore guardas un array con los UIDs de participantes.
    final rawParticipants = data['participants'];

    // 1) Si NO existe el array o no es List, mostramos sólo al creador.
    if (rawParticipants == null || rawParticipants is! List) {
      return _fetchCreatorOnly(plan.createdBy ?? '');
    }

    // 2) Primero añadimos el creador (si existe) a la lista final
    final List<Map<String, dynamic>> result = [];
    final String? creatorUid = plan.createdBy;
    if (creatorUid != null && creatorUid.isNotEmpty) {
      final creatorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(creatorUid)
          .get();
      if (creatorDoc.exists) {
        final creatorData = creatorDoc.data() as Map<String, dynamic>;
        result.add({
          'isCreator': true,
          'photoUrl': creatorData['photoUrl'] ?? '',
          'name': creatorData['name'] ?? 'Usuario',
          'age': (creatorData['age'] ?? '').toString(),
        });
      }
    }

    // 3) Ahora añadimos cada participante distinto del creador
    for (final participantUid in rawParticipants) {
      if (participantUid is! String) continue;
      if (participantUid == creatorUid) continue;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(participantUid)
          .get();

      if (!userDoc.exists) continue;

      final userData = userDoc.data() as Map<String, dynamic>;

      result.add({
        'isCreator': false,
        'photoUrl': userData['photoUrl'] ?? '',
        'name': userData['name'] ?? 'Usuario',
        'age': (userData['age'] ?? '').toString(),
      });
    }

    return result;
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

    // Aquí obtenemos TODOS los planes del usuario
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

        // Si NO tiene planes → tarjeta "sin plan"
        if (plans.isEmpty) {
          return _buildNoPlanLayout(context, userData);
        }

        // Si SÍ tiene planes, mostramos una tarjeta POR CADA plan
        return Column(
          children: plans.map((plan) {
            return _buildPlanLayout(context, userData, plan);
          }).toList(),
        );
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
            // Fondo con la foto de perfil
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
            // Avatar + nombre (tap -> abre perfil)
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
                      color: const Color.fromARGB(255, 14, 14, 14)
                          .withOpacity(0.2),
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
            // Texto + icono + botones
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
                      // Botones: Invitar y Mensaje
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

    // Si tienes un campo "planBackground" en Firestore, lo usarías aquí:
    final String? backgroundImage = null; // Ajusta según tu caso.

    // Usamos la descripción del plan como "caption"
    final String caption = plan.description.isNotEmpty
        ? plan.description
        : 'Descripción breve o #hashtags';

    // Contadores de ejemplo (ficticios)
    final String likesCount = '1245';
    final String commentsCount = '173';
    final String sharesCount = '227';

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: 330,
        margin: const EdgeInsets.only(bottom: 15),
        child: Stack(
          children: [
            // Imagen de fondo (planBackground o la del usuario)
            GestureDetector(
              onTap: () {
                // Definimos safeUserId a partir de uid
                final String safeUserId = uid ?? '';
                // Al tocar, abrimos el FrostedPlanDialog con ESTE plan,
                // y pasamos la función que carga participantes
                showGeneralDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: 'Cerrar',
                  barrierColor: Colors.black.withOpacity(0.4),
                  transitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (_, __, ___) => const SizedBox(),
                  transitionBuilder: (ctx, anim1, anim2, child) {
                    return FadeTransition(
                      opacity: CurvedAnimation(
                          parent: anim1, curve: Curves.easeOut),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.blue[900]!.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              // Se le asigna una key única basada en safeUserId
                              child: UserInfoInsideChat(
                                key: ValueKey(safeUserId),
                                chatPartnerId: safeUserId,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              child: ClipRRect(
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
            ),
            // Avatar + nombre (tap -> abre perfil)
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
                      color: const Color.fromARGB(255, 14, 14, 14)
                          .withOpacity(0.2),
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
            // Menú (3 puntos)
            Positioned(
              top: 16,
              right: 16,
              child: _buildThreeDotsMenu(userData),
            ),
            // Parte inferior: contadores + caption
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
                              label: likesCount,
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
                            Row(
                              children: [
                                Text(
                                  '7/10',
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

  // -----------------------------------------------------------------------
  // Botones de acción (Invitar / Chat) en la tarjeta de un usuario SIN plan
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
            // Tu lógica para invitar
          },
        ),
        const SizedBox(width: 16),
        _buildActionButton(
          context: context,
          iconPath: 'assets/mensaje.svg',
          label: null,
          onTap: () {
            // Al abrir el chat, se le asigna una key única
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

  // Helper para el botón con blur
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
  // Helpers
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

  Widget _buildPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.grey[200],
        height: 350,
        width: double.infinity,
        child: const Center(
          child: Icon(Icons.person, size: 40, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildThreeDotsMenu(Map<String, dynamic> userData) {
    final GlobalKey iconKey = GlobalKey();
    return InkWell(
      key: iconKey,
      onTap: () {
        final renderBox =
            iconKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final offset = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;

        showPlanOptions(
          iconKey.currentContext!,
          userData,
          offset,
          size,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: const Color.fromARGB(255, 14, 14, 14).withOpacity(0.1),
            padding: const EdgeInsets.all(10),
            child: const Icon(
              Icons.more_vert,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

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
