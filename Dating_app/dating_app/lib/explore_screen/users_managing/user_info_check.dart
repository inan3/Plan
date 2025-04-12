// lib/explore_screen/users_managing/user_info_check.dart

import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// Asegúrate de que tienes este import para usar SvgPicture:
import 'package:flutter_svg/flutter_svg.dart';

import '../../main/colors.dart';
import '../../models/plan_model.dart';
// Importamos el FrostedPlanDialog con alias 'new_frosted'
import 'frosted_plan_dialog_state.dart' as new_frosted;
import '../special_plans/invite_users_to_plan_screen.dart';
import 'user_info_inside_chat.dart';
import 'privilege_level_details.dart';

// IMPORTA TU WIDGET DE CALENDARIO
// Ajusta la ruta según dónde tengas el archivo memories_calendar.dart
import '../profile/memories_calendar.dart';

class UserInfoCheck extends StatefulWidget {
  final String userId;
  const UserInfoCheck({Key? key, required this.userId}) : super(key: key);

  @override
  State<UserInfoCheck> createState() => _UserInfoCheckState();
}

class _UserInfoCheckState extends State<UserInfoCheck> {
  String? _profileImageUrl;
  String? _coverImageUrl;
  bool isFollowing = false;

  // Para mostrar el ícono según privilegeLevel
  String _privilegeLevel = "basico";

  // Para saber si el perfil del usuario es privado (1) o público (0)
  bool _isPrivate = false;

  @override
  void initState() {
    super.initState();
    _loadUserData().then((_) {
      // Después de cargar los datos del usuario, refrescamos estadísticas
      _updateStatsBasedOnAllPlans();
    });
    _checkIfFollowing();
  }

  //////////////////////////////////////////////////////////////////////////////
  /// Lee TODOS los planes creados por [widget.userId], suma cuántos participantes
  /// hay en total y encuentra el plan con más participantes. Luego actualiza
  /// 'total_participants_until_now' y 'max_participants_in_one_plan'
  /// en 'users/{userId}'.
  //////////////////////////////////////////////////////////////////////////////
  Future<void> _updateStatsBasedOnAllPlans() async {
    try {
      final planSnap = await FirebaseFirestore.instance
          .collection('plans')
          .where('createdBy', isEqualTo: widget.userId)
          .where('special_plan', isEqualTo: 0)
          .get();

      int totalParticipantsAcrossAllPlans = 0;
      int maxParticipantsInAnyPlan = 0;

      for (final doc in planSnap.docs) {
        final data = doc.data();
        final participants = data['participants'] as List<dynamic>? ?? [];
        final count = participants.length;
        totalParticipantsAcrossAllPlans += count;
        if (count > maxParticipantsInAnyPlan) {
          maxParticipantsInAnyPlan = count;
        }
      }

      // Actualizamos en 'users/{userId}'
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userId);
      await userRef.update({
        'total_participants_until_now': totalParticipantsAcrossAllPlans,
        'max_participants_in_one_plan': maxParticipantsInAnyPlan,
      });

      print("[_updateStatsBasedOnAllPlans] Usuario=${widget.userId} -> "
          "total_participants_until_now=$totalParticipantsAcrossAllPlans, "
          "max_participants_in_one_plan=$maxParticipantsInAnyPlan");
    } catch (e) {
      print("[_updateStatsBasedOnAllPlans] Error: $e");
    }
  }

  Future<void> _loadUserData() async {
    print("[_loadUserData] Cargando datos de usuario desde Firestore...");
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (!doc.exists) {
        print("[_loadUserData] El documento no existe en Firestore.");
        return;
      }
      final data = doc.data() ?? {};

      setState(() {
        _profileImageUrl = data['photoUrl'] ?? '';
        _coverImageUrl = data['coverPhotoUrl'] ?? '';

        // Leemos el nivel actual para mostrar el ícono correspondiente
        _privilegeLevel = (data['privilegeLevel'] ?? 'basico').toString();

        // Leemos la privacidad (0 = público, 1 = privado)
        _isPrivate = (data['profile_privacy'] ?? 0) == 1;
      });

      print("[_loadUserData] Cargado con éxito. "
          "profileImageUrl=$_profileImageUrl, coverImageUrl=$_coverImageUrl, "
          "level=$_privilegeLevel, isPrivate=$_isPrivate");
    } catch (e) {
      print("[_loadUserData] Error al cargar datos de usuario: $e");
    }
  }

  Future<void> _checkIfFollowing() async {
    print("[_checkIfFollowing] Revisando si el usuario actual sigue a ${widget.userId}");
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("[_checkIfFollowing] No hay usuario logueado, no se puede seguir.");
      return;
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('followed')
        .where('userId', isEqualTo: user.uid)
        .where('followedId', isEqualTo: widget.userId)
        .get();
    setState(() {
      isFollowing = snapshot.docs.isNotEmpty;
    });
    print("[_checkIfFollowing] isFollowing=$isFollowing");
  }

  /// Devuelve cuántos planes activos ha creado este usuario
  Future<int> _getActivePlanCount() async {
    print("[_getActivePlanCount] Buscando planes activos (special_plan=0) creados por ${widget.userId}");
    final snapshot = await FirebaseFirestore.instance
        .collection('plans')
        .where('createdBy', isEqualTo: widget.userId)
        .where('special_plan', isEqualTo: 0)
        .get();
    return snapshot.docs.length;
  }

  /// Busca todos los planes activos (special_plan=0) y devuelve una lista de PlanModel
  Future<List<PlanModel>> _fetchActivePlans() async {
    print("[_fetchActivePlans] Buscando planes activos creados por ${widget.userId}");
    final snapshot = await FirebaseFirestore.instance
        .collection('plans')
        .where('createdBy', isEqualTo: widget.userId)
        .where('special_plan', isEqualTo: 0)
        .get();
    if (snapshot.docs.isEmpty) {
      print("[_fetchActivePlans] El usuario no tiene planes activos.");
      return [];
    }
    print("[_fetchActivePlans] Se encontraron ${snapshot.docs.length} planes.");
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; // forzamos a inyectar el doc.id en data
      return PlanModel.fromMap(data);
    }).toList();
  }

  /// Carga datos de los participantes del plan
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(PlanModel plan) async {
  //print("[_fetchAllPlanParticipants] Cargando participantes del plan con ID=${plan.id}");
  final List<Map<String, dynamic>> participants = [];

  final participantUids = plan.participants ?? [];
  for (String uid in participantUids) {
    final docUser = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (docUser.exists && docUser.data() != null) {
      final userData = docUser.data()!;
      participants.add({
        'uid': uid,
        'name': userData['name'] ?? 'Usuario',
        'age': userData['age']?.toString() ?? '',
        'photoUrl': userData['photoUrl'] ?? '',
        'isCreator': uid == plan.createdBy,
      });
    }
  }

  //print("[_fetchAllPlanParticipants] Participantes encontrados: ${participants.length}");
  return participants;
}

  Future<int> _getFollowersCount(String userId) async {
    print("[_getFollowersCount] Contando followers de userId=$userId");
    final snapshot = await FirebaseFirestore.instance
        .collection('followers')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  Future<int> _getFollowedCount(String userId) async {
    print("[_getFollowedCount] Contando seguidos por userId=$userId");
    final snapshot = await FirebaseFirestore.instance
        .collection('followed')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  /// Botón para seguir/dejar de seguir a este usuario
  Future<void> _toggleFollow() async {
    print("[_toggleFollow] isFollowing=$isFollowing, userId=${widget.userId}");
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Necesitas iniciar sesión para seguir.')),
      );
      return;
    }
    if (user.uid == widget.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes seguirte a ti mismo.')),
      );
      return;
    }

    try {
      if (isFollowing) {
        // Proceder con Unfollow
        print("[_toggleFollow] Procediendo a Unfollow");
        final followedSnap = await FirebaseFirestore.instance
            .collection('followed')
            .where('userId', isEqualTo: user.uid)
            .where('followedId', isEqualTo: widget.userId)
            .get();
        for (var doc in followedSnap.docs) {
          await doc.reference.delete();
        }
        final followersSnap = await FirebaseFirestore.instance
            .collection('followers')
            .where('userId', isEqualTo: widget.userId)
            .where('followerId', isEqualTo: user.uid)
            .get();
        for (var doc in followersSnap.docs) {
          await doc.reference.delete();
        }
        setState(() {
          isFollowing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Has dejado de seguir a este usuario.')),
        );
      } else {
        // No está siguiendo
        if (!_isPrivate) {
          // Perfil público => Follow directo
          print("[_toggleFollow] Perfil público => Follow");
          await FirebaseFirestore.instance.collection('followers').add({
            'userId': widget.userId,
            'followerId': user.uid,
          });
          await FirebaseFirestore.instance.collection('followed').add({
            'userId': user.uid,
            'followedId': widget.userId,
          });
          setState(() {
            isFollowing = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Has comenzado a seguir a este usuario!')),
          );
        } else {
          // Perfil privado => Solicitud de seguimiento
          print("[_toggleFollow] Perfil privado => Solicitud");
          final senderDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final senderData = senderDoc.data() ?? {};
          final senderName = senderData['name'] ?? 'SinNombre';
          final senderPhoto = senderData['photoUrl'] ?? '';

          // 1) Document en follow_requests
          await FirebaseFirestore.instance.collection('follow_requests').add({
            'requesterId': user.uid,
            'targetId': widget.userId,
            'timestamp': DateTime.now(),
            'status': 'pending',
          });

          // 2) Notificación
          await FirebaseFirestore.instance.collection('notifications').add({
            'type': 'follow_request',
            'receiverId': widget.userId,
            'senderId': user.uid,
            'senderName': senderName,
            'senderProfilePic': senderPhoto,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Solicitud de seguimiento enviada (perfil privado).')),
          );
        }
      }
    } catch (e) {
      print("[_toggleFollow] Error al actualizar follow: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar follow: $e')),
      );
    }
  }

  // **************************************************************
  // Función opcional para unirse a un plan
  // **************************************************************
  Future<void> _joinPlan(PlanModel plan) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final planDocRef =
        FirebaseFirestore.instance.collection('plans').doc(plan.id);

    // Añadimos el usuario a 'participants'
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(planDocRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final participants = List<String>.from(data['participants'] ?? []);

      if (!participants.contains(currentUser.uid)) {
        participants.add(currentUser.uid);
        transaction.update(planDocRef, {'participants': participants});
      }
    });

    // Leer cuántos hay ahora
    final updatedSnap = await planDocRef.get();
    final updatedData = updatedSnap.data() ?? {};
    final newParticipants = List<String>.from(updatedData['participants'] ?? []);
    final newCount = newParticipants.length;

    // Actualizar estadísticas
    await PrivilegeLevelDetails.updateSubscriptionStats(
      plan.createdBy,
      newCount,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Te uniste al plan ${plan.type}. Participantes ahora: $newCount"),
      ),
    );
  }

  // =================================================
  //   MOSTRAR FrostedPlanDialog A PANTALLA COMPLETA
  // =================================================
  void _showFrostedPlanDialog(PlanModel plan) {
    print("[_showFrostedPlanDialog] plan=${plan.id}");
    showDialog(
      context: context,
      barrierDismissible: true,
      useSafeArea: false, // Quita SafeArea => ocupa toda la pantalla
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: new_frosted.FrostedPlanDialog(
              plan: plan,
              fetchParticipants: _fetchAllPlanParticipants,
            ),
          ),
        );
      },
    );
  }

  /// Popup para mostrar planes activos del usuario
  /// (Lo mantenemos con showGeneralDialog para tu diseño. 
  /// Si quieres fullscreen también aquí, podrías cambiar a showDialog
  /// con useSafeArea: false, etc.)
  void _showActivePlansPopup() {
    print("[_showActivePlansPopup] Mostrando popup con los planes activos");
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: SafeArea(
            child: Align(
              alignment: Alignment.center,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      height: 300,
                      color: Colors.black.withOpacity(0.3),
                      padding: const EdgeInsets.all(16),
                      child: FutureBuilder<List<PlanModel>>(
                        future: _fetchActivePlans(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(
                              child: Text(
                                'No hay planes activos',
                                style: TextStyle(color: Colors.white),
                              ),
                            );
                          }
                          final plans = snapshot.data!;
                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: plans.length,
                            itemBuilder: (context, index) {
                              final plan = plans[index];
                              return GestureDetector(
                                onTap: () {
                                  print("[_showActivePlansPopup] Pulsó plan ID=${plan.id}");
                                  Navigator.of(context).pop();
                                  _showFrostedPlanDialog(plan);
                                },
                                child: _buildPlanCard(plan),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanCard(PlanModel plan) {
    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        image: (plan.backgroundImage != null && plan.backgroundImage!.isNotEmpty)
            ? DecorationImage(
                image: NetworkImage(plan.backgroundImage!),
                fit: BoxFit.cover,
              )
            : null,
        color: Colors.grey[300],
      ),
      child: Stack(
        children: [
          // Imagen y título del plan
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
              child: Text(
                plan.type,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Botón para unirse
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                // Al pulsar, nos unimos al plan
                _joinPlan(plan);
              },
            ),
          )
        ],
      ),
    );
  }

  // ========================================================
  //   WIDGETS PRINCIPALES DEL BUILD
  // ========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Usuario no encontrado'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final String name = userData['name'] ?? 'Usuario';

          return SingleChildScrollView(
            child: Column(
              children: [
                // CABECERA CON LA PORTADA + BOTÓN ATRÁS + AVATAR
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildCoverImage(),
                    Positioned(
                      top: 40,
                      left: 16,
                      child: ClipOval(
                        child: Container(
                          color: Colors.black.withOpacity(0.4),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -80,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _buildAvatarAndName(name),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 70),

                // ICONO DE NIVEL DE PRIVILEGIO
                _buildPrivilegeButton(context),

                // BOTONES DE ACCION (Invitar, Mensaje, Seguir)
                _buildActionButtons(context, widget.userId),
                const SizedBox(height: 20),

                // STATS (planes activos, seguidores, seguidos)
                _buildBioAndStats(),
                const SizedBox(height: 20),

                // Divider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Divider(color: Colors.grey[400], thickness: 0.5),
                ),
                const SizedBox(height: 20),

                // Si el perfil es privado y NO seguimos => candado
                // Sino => mostramos su calendario con onPlanSelected
                if (_isPrivate && !isFollowing)
                  Column(
                    children: [
                      SvgPicture.asset(
                        "assets/icono-candado.svg",
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Este perfil es privado. Debes seguirle (y que te acepte) para ver sus memorias.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  )
                else
                  // Calendario con callback
                  MemoriesCalendar(
                    userId: widget.userId,
                    onPlanSelected: (PlanModel plan) {
                      // ¡Abrimos el FrostedPlanDialog a pantalla completa!
                      _showFrostedPlanDialog(plan);
                    },
                  ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoverImage() {
    final bool hasCover =
        (_coverImageUrl != null && _coverImageUrl!.isNotEmpty);
    if (hasCover) {
      print("[_buildCoverImage] coverImageUrl=$_coverImageUrl");
    } else {
      print("[_buildCoverImage] El usuario no tiene coverPhotoUrl");
    }

    return Container(
      height: 300,
      width: double.infinity,
      color: Colors.grey[300],
      child: hasCover
          ? Image.network(_coverImageUrl!, fit: BoxFit.cover)
          : Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.image, size: 30, color: Colors.black54),
                  SizedBox(width: 8),
                  Text("Sin portada", style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarAndName(String userName) {
    final fallbackAvatar = "https://via.placeholder.com/150";
    final avatarUrl =
        (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
            ? _profileImageUrl!
            : fallbackAvatar;

    print("[_buildAvatarAndName] avatarUrl=$avatarUrl, userName=$userName");

    return Column(
      children: [
        CircleAvatar(
          radius: 45,
          backgroundColor: Colors.white,
          child: CircleAvatar(
            radius: 42,
            backgroundImage: NetworkImage(avatarUrl),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          userName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPrivilegeButton(BuildContext context) {
    return GestureDetector(
      onTap: _showPrivilegeLevelDetailsPopup,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                _getPrivilegeIcon(_privilegeLevel),
                width: 52,
                height: 52,
              ),
              const SizedBox(height: 0),
              Text(
                _mapPrivilegeLevelToTitle(_privilegeLevel),
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivilegeLevelDetailsPopup() {
    print("[_showPrivilegeLevelDetailsPopup] Mostrando popup de privilegios");
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: SafeArea(
            child: Align(
              alignment: Alignment.center,
              child: Material(
                color: Colors.transparent,
                child: PrivilegeLevelDetails(
                  userId: widget.userId,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context, String otherUserId) {
    print("[_buildActionButtons] userId=$otherUserId, isFollowing=$isFollowing, isPrivate=$_isPrivate");
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 1) Invitar a un Plan
        _buildActionButton(
          context: context,
          iconPath: 'assets/union.svg',
          label: 'Invítale a un Plan',
          onTap: (_isPrivate && !isFollowing)
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Este usuario es privado. Debes seguirle y ser '
                          'aceptado para invitarle a un plan.'),
                    ),
                  );
                }
              : () {
                  print("[_buildActionButtons] Botón 'Invítale a un Plan'");
                  if (otherUserId.isNotEmpty) {
                    InviteUsersToPlanScreen.showPopup(context, otherUserId);
                  }
                },
        ),
        const SizedBox(width: 12),

        // 2) Enviar Mensaje
        _buildActionButton(
          context: context,
          iconPath: 'assets/mensaje.svg',
          label: 'Enviar Mensaje',
          onTap: (_isPrivate && !isFollowing)
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Este usuario es privado. Debes seguirle y ser '
                          'aceptado para enviarle mensajes.'),
                    ),
                  );
                }
              : () {
                  print("[_buildActionButtons] Botón 'Mensaje' pulsado");
                  showGeneralDialog(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: 'Cerrar',
                    barrierColor: Colors.transparent,
                    transitionDuration: const Duration(milliseconds: 300),
                    pageBuilder: (_, __, ___) => const SizedBox(),
                    transitionBuilder: (ctx, anim1, anim2, child) {
                      return FadeTransition(
                        opacity: CurvedAnimation(
                          parent: anim1,
                          curve: Curves.easeOut,
                        ),
                        child: UserInfoInsideChat(
                          key: ValueKey(otherUserId),
                          chatPartnerId: otherUserId,
                        ),
                      );
                    },
                  );
                },
        ),
        const SizedBox(width: 12),

        // 3) Seguir / Siguiendo
        _buildActionButton(
          context: context,
          iconPath: isFollowing
              ? 'assets/icono-tick.svg'
              : 'assets/agregar-usuario.svg',
          label: isFollowing ? 'Siguiendo' : 'Seguir',
          onTap: _toggleFollow,
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
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 13, 32, 53),
                  Color.fromARGB(255, 72, 38, 38),
                  Color(0xFF12232E),
                ],
              ),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  iconPath,
                  width: 24,
                  height: 24,
                  color: Colors.white,
                ),
                if (label != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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

  Widget _buildBioAndStats() {
    return FutureBuilder<int>(
      future: _getActivePlanCount(),
      builder: (context, snapshotPlans) {
        return FutureBuilder<int>(
          future: _getFollowersCount(widget.userId),
          builder: (context, snapshotFol) {
            return FutureBuilder<int>(
              future: _getFollowedCount(widget.userId),
              builder: (context, snapshotFing) {
                if (snapshotPlans.connectionState == ConnectionState.waiting ||
                    snapshotFol.connectionState == ConnectionState.waiting ||
                    snapshotFing.connectionState == ConnectionState.waiting) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatItem("planes activos", "...", isActive: false),
                      const SizedBox(width: 20),
                      _buildStatItem("seguidores", "...", isActive: false),
                      const SizedBox(width: 20),
                      _buildStatItem("seguidos", "...", isActive: false),
                    ],
                  );
                }
                if (snapshotPlans.hasError ||
                    snapshotFol.hasError ||
                    snapshotFing.hasError ||
                    !snapshotPlans.hasData ||
                    !snapshotFol.hasData ||
                    !snapshotFing.hasData) {
                  print("[_buildBioAndStats] Error o datos faltantes en FutureBuilders.");
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatItem("planes activos", "0", isActive: false),
                      const SizedBox(width: 20),
                      _buildStatItem("seguidores", "0", isActive: false),
                      const SizedBox(width: 20),
                      _buildStatItem("seguidos", "0", isActive: false),
                    ],
                  );
                }

                final planeCount = snapshotPlans.data ?? 0;
                final followersCount = snapshotFol.data ?? 0;
                final followedCount = snapshotFing.data ?? 0;

                print("[_buildBioAndStats] planeCount=$planeCount, followersCount=$followersCount, followedCount=$followedCount");

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatItem(
                      "planes activos",
                      planeCount.toString(),
                      isActive: planeCount >= 1,
                    ),
                    const SizedBox(width: 20),
                    _buildStatItem(
                      "seguidores",
                      followersCount.toString(),
                      isActive: followersCount >= 1,
                    ),
                    const SizedBox(width: 20),
                    _buildStatItem(
                      "seguidos",
                      followedCount.toString(),
                      isActive: followedCount >= 1,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(String label, String count, {required bool isActive}) {
    final String iconPath = (label == "planes activos")
        ? 'assets/icono-calendario.svg'
        : 'assets/icono-seguidores.svg';

    Widget iconWidget = isActive
        ? ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 13, 32, 53),
                  Color.fromARGB(255, 72, 38, 38),
                  Color(0xFF12232E),
                ],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcIn,
            child: SvgPicture.asset(
              iconPath,
              width: 24,
              height: 24,
            ),
          )
        : SvgPicture.asset(
            iconPath,
            width: 24,
            height: 24,
            color: Colors.grey,
          );

    return SizedBox(
      width: 100,
      child: Column(
        children: [
          iconWidget,
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _mapPrivilegeLevelToTitle(String level) {
    switch (level.toLowerCase()) {
      case "premium":
        return "Premium";
      case "golden":
        return "Golden";
      case "vip":
        return "VIP";
      default:
        return "Básico";
    }
  }

  String _getPrivilegeIcon(String level) {
    switch (level.toLowerCase()) {
      case "premium":
        return "assets/icono-usuario-premium.png";
      case "golden":
        return "assets/icono-usuario-golden.png";
      case "vip":
        return "assets/icono-usuario-vip.png";
      default:
        return "assets/icono-usuario-basico.png";
    }
  }
}
