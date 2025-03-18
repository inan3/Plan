// lib/explore_screen/users_managing/user_info_check.dart

import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../main/colors.dart';
import '../../models/plan_model.dart';
import 'frosted_plan_dialog_state.dart' as new_frosted;
import '../special_plans/invite_users_to_plan_screen.dart';
import 'user_info_inside_chat.dart';

// IMPORTAMOS el fichero de privilegios
import 'privilege_level_details.dart';

class UserInfoCheck extends StatefulWidget {
  final String userId;
  const UserInfoCheck({Key? key, required this.userId}) : super(key: key);

  @override
  State<UserInfoCheck> createState() => _UserInfoCheckState();
}

class _UserInfoCheckState extends State<UserInfoCheck> {
  String? _profileImageUrl;
  String? _coverImageUrl;
  List<String> _additionalPhotos = [];
  bool isFollowing = false;

  // Para mostrar el ícono según privilegeLevel
  String _privilegeLevel = "basico";

  @override
  void initState() {
    super.initState();
    _loadUserData().then((_) {
      // Después de cargar los datos del usuario,
      // refrescamos las estadísticas basadas en todos sus planes
      _updateStatsBasedOnAllPlans();
    });
    _checkIfFollowing();
  }

  //////////////////////////////////////////////////////////////////////////////
  /// NUEVO:
  /// Lee TODOS los planes creados por [widget.userId], suma cuántos participantes
  /// hay en total y encuentra el plan con más participantes. Luego actualiza
  /// 'total_participants_until_now' y 'max_participants_in_one_plan' en 'users/{userId}'.
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

      // Actualizamos en 'users/{userId}' con estos valores.
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);
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
        final dynamic photos = data['additionalPhotos'];
        if (photos is List) {
          _additionalPhotos = photos.map((e) => e.toString()).toList();
        } else {
          _additionalPhotos = [];
        }

        // Leemos el nivel actual para mostrar el ícono correspondiente
        _privilegeLevel = (data['privilegeLevel'] ?? 'basico').toString();
      });

      print("[_loadUserData] Cargado con éxito. "
            "profileImageUrl=$_profileImageUrl, coverImageUrl=$_coverImageUrl, "
            "level=$_privilegeLevel");
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

  /// Busca todos los planes activos (special_plan=0)
  /// y devuelve una lista de PlanModel
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
      data['id'] = doc.id;
      return PlanModel.fromMap(data);
    }).toList();
  }

  /// Carga datos de los participantes del plan (si quisieras mostrarlos).
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(PlanModel plan) async {
    print("[_fetchAllPlanParticipants] Cargando participantes del plan con ID=${plan.id}");
    final List<Map<String, dynamic>> participants = [];

    final creatorDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(plan.createdBy)
        .get();
    if (creatorDoc.exists) {
      final cdata = creatorDoc.data() ?? {};
      participants.add({
        'name': cdata['name'] ?? 'Sin nombre',
        'age': (cdata['age'] ?? '').toString(),
        'photoUrl': cdata['photoUrl'] ?? '',
        'isCreator': true,
      });
    }
    print("[_fetchAllPlanParticipants] Participantes: ${participants.length}");
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
        // Dejar de seguir
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
        // Comenzar a seguir
        print("[_toggleFollow] Procediendo a Follow");
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
      }
    } catch (e) {
      print("[_toggleFollow] Error al actualizar follow: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar follow: $e')),
      );
    }
  }

  // **************************************************************
  // Función opcional para unirse a un plan (ya la tenías).
  // Manténla si también quieres unirte con un botón "add" en la UI.
  // **************************************************************
  Future<void> _joinPlan(PlanModel plan) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final planDocRef = FirebaseFirestore.instance.collection('plans').doc(plan.id);

    // Añadimos el usuario a 'participants' (si no está)
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(planDocRef);
      if (!snapshot.exists) return; // El plan se borró

      final data = snapshot.data() as Map<String, dynamic>;
      final participants = List<String>.from(data['participants'] ?? []);

      if (!participants.contains(currentUser.uid)) {
        participants.add(currentUser.uid);
        transaction.update(planDocRef, {'participants': participants});
      }
    });

    // Leemos cuántos hay ahora
    final updatedSnap = await planDocRef.get();
    final updatedData = updatedSnap.data() ?? {};
    final newParticipants = List<String>.from(updatedData['participants'] ?? []);
    final newCount = newParticipants.length;

    // Actualiza la estadística manual (pero ya no es necesario si
    // _updateStatsBasedOnAllPlans() corre cada vez que abres la pantalla).
    // Aun así, se deja por si lo quieres al instante:
    await PrivilegeLevelDetails.updateSubscriptionStats(plan.createdBy, newCount);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Te uniste al plan ${plan.type}. Participantes ahora: $newCount")),
    );
  }

  //////////////////////////////////////////////////////////////////////////////
  // A PARTIR DE AQUÍ: Construcción de la UI
  //////////////////////////////////////////////////////////////////////////////

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
                            onPressed: () {
                              print("[UserInfoCheck] Botón atrás pulsado, Navigator.pop");
                              Navigator.pop(context);
                            },
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

                const SizedBox(height: 90),

                // Botón: "Ver Privilegios"
                _buildPrivilegeButton(context),

                const SizedBox(height: 20),
                _buildActionButtons(context, widget.userId),
                const SizedBox(height: 20),
                _buildBioAndStats(),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Divider(color: Colors.grey[400], thickness: 0.5),
                ),
                const SizedBox(height: 20),
                _buildAdditionalPhotosSection(),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // Botón: "Ver Privilegios"
  Widget _buildPrivilegeButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        print("[_buildPrivilegeButton] Botón 'Ver Privilegios' pulsado");
        _showPrivilegeLevelDetailsPopup();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFB22222), // Rojo sangre
                Color(0xFF1E90FF), // Azul
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                _getPrivilegeIcon(_privilegeLevel),
                width: 52,
                height: 52,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivilegeLevelDetailsPopup() {
    print("[_showPrivilegeLevelDetailsPopup] Mostrando popup para ver nivel de privilegios");
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return const SizedBox.shrink();
      },
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

  Widget _buildCoverImage() {
    final bool hasCover = (_coverImageUrl != null && _coverImageUrl!.isNotEmpty);
    if (hasCover) {
      print("[_buildCoverImage] Mostrando coverImageUrl=$_coverImageUrl");
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
    final avatarUrl = (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
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

                print("[_buildBioAndStats] planeCount=$planeCount, "
                      "followersCount=$followersCount, followedCount=$followedCount");

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
    final Color iconColor = isActive ? AppColors.blue : Colors.grey;

    return SizedBox(
      width: 100,
      child: Column(
        children: [
          SvgPicture.asset(
            iconPath,
            width: 24,
            height: 24,
            color: iconColor,
          ),
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

  Widget _buildActionButtons(BuildContext context, String otherUserId) {
    print("[_buildActionButtons] userId=$otherUserId, isFollowing=$isFollowing");
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          context: context,
          iconPath: 'assets/agregar-usuario.svg',
          label: 'Invítale a un Plan',
          onTap: () {
            print("[_buildActionButtons] Botón 'Invítale a un Plan' pulsado");
            if (otherUserId.isNotEmpty) {
              InviteUsersToPlanScreen.showPopup(context, otherUserId);
            }
          },
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          context: context,
          iconPath: 'assets/mensaje.svg',
          label: null,
          onTap: () {
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
                  opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
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
        _buildActionButton(
          context: context,
          iconPath: isFollowing ? 'assets/icono-tick.svg' : 'assets/agregar-usuario.svg',
          label: isFollowing ? 'Siguiendo' : 'Seguir',
          onTap: () {
            print("[_buildActionButtons] Botón 'Seguir/Siguiendo' pulsado");
            _toggleFollow();
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
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            color: const ui.Color.fromARGB(255, 12, 11, 11).withOpacity(0.3),
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

  Widget _buildAdditionalPhotosSection() {
    print("[_buildAdditionalPhotosSection] _additionalPhotos.length=${_additionalPhotos.length}");
    if (_additionalPhotos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: Text(
          'No hay fotos adicionales',
          style: TextStyle(color: Colors.black87),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Fotos adicionales:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _additionalPhotos.length,
            itemBuilder: (context, index) {
              final imageUrl = _additionalPhotos[index];
              return GestureDetector(
                onTap: () {
                  print("[_buildAdditionalPhotosSection] Pulsada foto adicional index=$index");
                  _openPhotoViewer(index);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openPhotoViewer(int initialIndex) {
    print("[_openPhotoViewer] Mostrando foto en pantalla completa, index=$initialIndex");
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          child: Container(
            width: double.maxFinite,
            height: double.maxFinite,
            color: Colors.black,
            child: Stack(
              children: [
                PageView.builder(
                  controller: PageController(initialPage: initialIndex),
                  itemCount: _additionalPhotos.length,
                  itemBuilder: (context, index) {
                    final imageUrl = _additionalPhotos[index];
                    return InteractiveViewer(
                      child: Center(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () {
                      print("[_openPhotoViewer] Cerrar el diálogo de fotos");
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Popup para mostrar planes activos del usuario
  void _showActivePlansPopup() {
    print("[_showActivePlansPopup] Mostrando popup con los planes activos del usuario");
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return const SizedBox.shrink();
      },
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
                                  print("[_showActivePlansPopup] Se pulsó un plan con ID=${plan.id}");
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

  /// Muestra un dialog especial con info del plan y la opción de unirse
  void _showFrostedPlanDialog(PlanModel plan) {
    print("[_showFrostedPlanDialog] Mostrando frostedPlanDialog para plan con ID=${plan.id}");
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (ctx, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: SafeArea(
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
                // Al pulsar, nos unimos al plan (opcional)
                _joinPlan(plan);
              },
            ),
          )
        ],
      ),
    );
  }

  // Selecciona el ícono según el nivel de privilegio
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
