// lib/explore_screen/users_managing/user_info_check.dart

import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../main/colors.dart';
import '../../models/plan_model.dart';
// Importamos el diálogo frosted para ver detalles de un plan:
import 'frosted_plan_dialog_state.dart' as new_frosted;

class UserInfoCheck extends StatefulWidget {
  final String userId;

  const UserInfoCheck({Key? key, required this.userId}) : super(key: key);

  @override
  State<UserInfoCheck> createState() => _UserInfoCheckState();
}

class _UserInfoCheckState extends State<UserInfoCheck> {
  // Atributos para portada y fotos adicionales
  String? _profileImageUrl;
  String? _coverImageUrl;
  List<String> _additionalPhotos = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // --------------------------------------------------------------------------
  // Carga datos del usuario (photoUrl, coverPhotoUrl, additionalPhotos)
  // --------------------------------------------------------------------------
  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (!doc.exists) return;
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
      });
    } catch (e) {
      print('Error al cargar datos de usuario: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Obtiene el número de planes activos (NO ESPECIALES) creados por userId
  // --------------------------------------------------------------------------
  Future<int> _getActivePlanCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('plans')
        .where('createdBy', isEqualTo: widget.userId)
        .where('special_plan', isEqualTo: 0)
        .get();
    return snapshot.docs.length;
  }

  // --------------------------------------------------------------------------
  // Obtiene la lista de planes activos (NO ESPECIALES) creados por userId
  // --------------------------------------------------------------------------
  Future<List<PlanModel>> _fetchActivePlans() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('plans')
        .where('createdBy', isEqualTo: widget.userId)
        .where('special_plan', isEqualTo: 0)
        .get();
    if (snapshot.docs.isEmpty) return [];
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return PlanModel.fromMap(data);
    }).toList();
  }

  // --------------------------------------------------------------------------
  // Obtiene los participantes de un plan. (solo el creador, expandir si quieres)
  // --------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];

    // Buscamos el creador
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

    // Podrías expandir lógica para participants en array o suscripciones...

    return participants;
  }

  /// Devuelve la ruta del icono según el nivel de privilegio.
  String _getPrivilegeIconPath(int level) {
    switch (level) {
      case 1:
        return 'assets/icono-usuario-premium.svg';
      case 2:
        return 'assets/icono-usuario-diamond.svg';
      case 3:
        return 'assets/icono-usuario-vip.svg';
      default:
        return 'assets/icono-usuario-basico.svg';
    }
  }

  /// Construye el widget con el icono de privilegio.
  Widget _buildPrivilegeIcon(int level) {
    return SvgPicture.asset(
      _getPrivilegeIconPath(level),
      width: 24,
      height: 24,
    );
  }

  /// Devuelve la cantidad de seguidores (followers) de [userId].
  Future<int> _getFollowersCount(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('followers')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  /// Devuelve la cantidad de seguidos (followed) de [userId].
  Future<int> _getFollowedCount(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('followed')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

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
          final int privilegeLevel = userData['privilegeLevel'] ?? 0;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Portada + Avatar
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
                        child: _buildAvatarAndName(name, privilegeLevel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 100),

                // Stats
                _buildBioAndStats(),
                const SizedBox(height: 20),

                // Separador
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Divider(color: Colors.grey[400], thickness: 0.5),
                ),
                const SizedBox(height: 20),

                // Fotos adicionales
                _buildAdditionalPhotosSection(),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoverImage() {
    final bool hasCover = (_coverImageUrl != null && _coverImageUrl!.isNotEmpty);
    return Container(
      height: 300,
      width: double.infinity,
      color: Colors.grey[300],
      child: hasCover
          ? Image.network(
              _coverImageUrl!,
              fit: BoxFit.cover,
            )
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

  Widget _buildAvatarAndName(String userName, int privilegeLevel) {
    final fallbackAvatar = "https://via.placeholder.com/150";
    final avatarUrl = (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
        ? _profileImageUrl!
        : fallbackAvatar;

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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              userName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.verified, color: Colors.blue, size: 20),
          ],
        ),
        const SizedBox(height: 8),
        _buildPrivilegeIcon(privilegeLevel),
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
                      _buildStatItem("planes activos", "...", iconoCalendario: true),
                      const SizedBox(width: 20),
                      _buildStatItem("seguidores", "..."),
                      const SizedBox(width: 20),
                      _buildStatItem("seguidos", "..."),
                    ],
                  );
                }
                if (snapshotPlans.hasError ||
                    snapshotFol.hasError ||
                    snapshotFing.hasError ||
                    !snapshotPlans.hasData ||
                    !snapshotFol.hasData ||
                    !snapshotFing.hasData) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatItem("planes activos", "0", iconoCalendario: true),
                      const SizedBox(width: 20),
                      _buildStatItem("seguidores", "0"),
                      const SizedBox(width: 20),
                      _buildStatItem("seguidos", "0"),
                    ],
                  );
                }

                final planeCount = snapshotPlans.data ?? 0;
                final followersCount = snapshotFol.data ?? 0;
                final followedCount = snapshotFing.data ?? 0;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatItem("planes activos", planeCount.toString(),
                        iconoCalendario: true),
                    const SizedBox(width: 20),
                    _buildStatItem("seguidores", followersCount.toString()),
                    const SizedBox(width: 20),
                    _buildStatItem("seguidos", followedCount.toString()),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(String label, String count, {bool iconoCalendario = false}) {
    final bool isPlanesActivos = label.contains("planes activos");
    String iconPath = isPlanesActivos
        ? 'assets/icono-calendario.svg'
        : 'assets/icono-seguidores.svg';
    Color iconColor = isPlanesActivos ? AppColors.blue : Colors.blueGrey;

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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  void _showActivePlansPopup() {
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

  void _showFrostedPlanDialog(PlanModel plan) {
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
        ],
      ),
    );
  }

  Widget _buildAdditionalPhotosSection() {
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
                onTap: () => _openPhotoViewer(index),
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
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
