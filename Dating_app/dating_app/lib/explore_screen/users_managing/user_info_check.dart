// user_info_check.dart

import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../main/colors.dart';
import '../../models/plan_model.dart';
import '../plans_managing/frosted_plan_dialog_state.dart' as new_frosted;
import '../special_plans/invite_users_to_plan_screen.dart';
import 'user_info_inside_chat.dart';
import 'privilege_level_details.dart';
import '../profile/memories_calendar.dart';
import '../follow/following_screen.dart';
import '../future_plans/future_plans.dart';

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
  String _privilegeLevel = 'Básico';
  bool _isPrivate = false;

  @override
  void initState() {
    super.initState();
    _loadUserData().then((_) => _updateStatsBasedOnAllPlans());
    _checkIfFollowing();
  }

  /// IMPORTANTE:
  /// En vez de usar participants.length, usaremos checkedInUsers.length
  /// para actualizar total_participants_until_now y max_participants_in_one_plan.
  /// Además, sumaremos un plan a total_created_plans sólo si checkedInUsers > 0.
  Future<void> _updateStatsBasedOnAllPlans() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('plans')
          .where('createdBy', isEqualTo: widget.userId)
          .where('special_plan', isEqualTo: 0)
          .get();

      int total = 0;           // Suma de todos los checkedInUsers
      int maxInOne = 0;        // Máx. en un solo plan (contando checkedInUsers)
      int countCreated = 0;    // Cantidad de planes (solo si al menos 1 checkedInUser)

      for (var d in snap.docs) {
        final data = d.data();
        final List<dynamic> checked = data['checkedInUsers'] ?? [];
        final c = checked.length;
        total += c;
        if (c > maxInOne) {
          maxInOne = c;
        }
        // Solo contamos el plan si c>0
        if (c > 0) {
          countCreated++;
        }
      }

      // Hacemos la operación en una transacción
      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDocRef);
        if (!snapshot.exists) return;
        transaction.update(userDocRef, {
          'total_participants_until_now': total,
          'max_participants_in_one_plan': maxInOne,
          'total_created_plans': countCreated,
        });
      });
    } catch (e) {
      print('[updateStatsBasedOnAllPlans] $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (!doc.exists) return;
      final data = doc.data()!;
      setState(() {
        _profileImageUrl = data['photoUrl'] ?? '';
        _coverImageUrl = data['coverPhotoUrl'] ?? '';
        _privilegeLevel = (data['privilegeLevel'] ?? 'Básico').toString();
        _isPrivate = (data['profile_privacy'] ?? 0) == 1;
      });
    } catch (e) {
      print('[loadUserData] $e');
    }
  }

  Future<void> _checkIfFollowing() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('followed')
        .where('userId', isEqualTo: user.uid)
        .where('followedId', isEqualTo: widget.userId)
        .get();
    setState(() => isFollowing = snap.docs.isNotEmpty);
  }

  Future<int> _getFuturePlanCount(String userId) async {
    final now = DateTime.now();
    final snap = await FirebaseFirestore.instance
        .collection('plans')
        .where('createdBy', isEqualTo: userId)
        .where('special_plan', isEqualTo: 0)
        .get();
    int counter = 0;
    for (final d in snap.docs) {
      final data = d.data();
      final ts = data['start_timestamp'];
      if (ts is Timestamp && ts.toDate().isAfter(now)) {
        counter++;
      }
    }
    return counter;
  }

  Future<List<PlanModel>> _fetchFuturePlans() async {
    final now = DateTime.now();
    final snap = await FirebaseFirestore.instance
        .collection('plans')
        .where('createdBy', isEqualTo: widget.userId)
        .where('special_plan', isEqualTo: 0)
        .get();
    final List<PlanModel> list = [];
    for (final d in snap.docs) {
      final data = d.data();
      final ts = data['start_timestamp'];
      if (ts is Timestamp && ts.toDate().isAfter(now)) {
        data['id'] = d.id;
        list.add(PlanModel.fromMap(data));
      }
    }
    list.sort((a, b) => a.startTimestamp!.compareTo(b.startTimestamp!));
    return list;
  }

  /// Cambiamos de seguir / dejar de seguir
  Future<void> _toggleFollow() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || me.uid == widget.userId) return;
    try {
      if (isFollowing) {
        // Dejar de seguir
        final f1 = await FirebaseFirestore.instance
            .collection('followed')
            .where('userId', isEqualTo: me.uid)
            .where('followedId', isEqualTo: widget.userId)
            .get();
        for (final d in f1.docs) {
          await d.reference.delete();
        }
        final f2 = await FirebaseFirestore.instance
            .collection('followers')
            .where('userId', isEqualTo: widget.userId)
            .where('followerId', isEqualTo: me.uid)
            .get();
        for (final d in f2.docs) {
          await d.reference.delete();
        }
        setState(() => isFollowing = false);
      } else {
        // Empezar a seguir
        if (!_isPrivate) {
          await FirebaseFirestore.instance.collection('followers').add({
            'userId': widget.userId,
            'followerId': me.uid,
          });
          await FirebaseFirestore.instance.collection('followed').add({
            'userId': me.uid,
            'followedId': widget.userId,
          });
          setState(() => isFollowing = true);
        } else {
          // Perfil privado
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este usuario es privado. Debes enviar solicitud.'),
            ),
          );
        }
      }
    } catch (e) {
      print('[toggleFollow] $e');
    }
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
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Usuario no encontrado'));
          }
          final data = snap.data!.data() as Map<String, dynamic>;
          final name = data['name'] ?? 'Usuario';
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(name),
                const SizedBox(height: 70),
                _buildPrivilegeButton(),
                const SizedBox(height: 20),
                _buildActionButtons(widget.userId),
                const SizedBox(height: 20),
                _buildBioAndStats(),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: Colors.grey[400], thickness: .5),
                ),
                const SizedBox(height: 20),
                _buildMemoriesOrLock(),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildCoverImage(),
        Positioned(
          top: 40,
          left: 16,
          child: ClipOval(
            child: Container(
              color: Colors.black.withOpacity(.4),
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
          child: Center(child: _buildAvatarAndName(name)),
        ),
      ],
    );
  }

  Widget _buildCoverImage() {
    final has = _coverImageUrl != null && _coverImageUrl!.isNotEmpty;
    return Container(
      height: 300,
      width: double.infinity,
      color: Colors.grey[300],
      child: has
          ? Image.network(_coverImageUrl!, fit: BoxFit.cover)
          : Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.image, size: 30, color: Colors.black54),
                  SizedBox(width: 8),
                  Text('Sin portada', style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarAndName(String userName) {
    final avatarUrl = (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
        ? _profileImageUrl!
        : 'https://via.placeholder.com/150';
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

  Widget _buildPrivilegeButton() {
    return GestureDetector(
      onTap: _showPrivilegeLevelDetailsPopup,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(_getPrivilegeIcon(_privilegeLevel), width: 52, height: 52),
              const SizedBox(height: 0),
              Text(
                _mapPrivilegeLevelToTitle(_privilegeLevel),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivilegeLevelDetailsPopup() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: anim,
          child: SafeArea(
            child: Align(
              alignment: Alignment.center,
              child: Material(
                color: Colors.transparent,
                child: PrivilegeLevelDetails(userId: widget.userId),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(String otherUserId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          iconPath: 'assets/union.svg',
          label: 'Invítale a un Plan',
          onTap: (_isPrivate && !isFollowing)
              ? () => _showPrivateToast()
              : () => InviteUsersToPlanScreen.showPopup(context, otherUserId),
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          iconPath: 'assets/mensaje.svg',
          label: 'Enviar Mensaje',
          onTap: (_isPrivate && !isFollowing)
              ? () => _showPrivateToast()
              : () => _openChat(otherUserId),
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          iconPath: isFollowing ? 'assets/icono-tick.svg' : 'assets/agregar-usuario.svg',
          label: isFollowing ? 'Siguiendo' : 'Seguir',
          onTap: _toggleFollow,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String iconPath,
    required VoidCallback onTap,
    String? label,
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

  void _showPrivateToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Este usuario es privado. Debes seguirle y ser aceptado.'),
      ),
    );
  }

  void _openChat(String otherId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (_, anim1, __, ___) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: UserInfoInsideChat(key: ValueKey(otherId), chatPartnerId: otherId),
        );
      },
    );
  }

  Widget _buildBioAndStats() {
    return FutureBuilder<int>(
      future: _getFuturePlanCount(widget.userId),
      builder: (_, pSnap) {
        return FutureBuilder<int>(
          future: _getFollowersCount(widget.userId),
          builder: (_, foSnap) {
            return FutureBuilder<int>(
              future: _getFollowedCount(widget.userId),
              builder: (_, fiSnap) {
                if (pSnap.connectionState == ConnectionState.waiting ||
                    foSnap.connectionState == ConnectionState.waiting ||
                    fiSnap.connectionState == ConnectionState.waiting) {
                  return _buildStatsRow('...', '...', '...');
                }
                final planes = pSnap.data ?? 0;
                final followers = foSnap.data ?? 0;
                final followed = fiSnap.data ?? 0;
                return _buildStatsRow(
                  planes.toString(),
                  followers.toString(),
                  followed.toString(),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatsRow(String planes, String followers, String followed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem('planes futuros', planes),
        const SizedBox(width: 20),
        _buildStatItem('seguidores', followers),
        const SizedBox(width: 20),
        _buildStatItem('seguidos', followed),
      ],
    );
  }

  Widget _buildStatItem(String label, String count) {
    final isFuture = label == 'planes futuros';
    final isFollowers = label == 'seguidores';
    final iconPath =
        isFuture ? 'assets/icono-calendario.svg' : 'assets/icono-seguidores.svg';

    final iconColor = isFuture
        ? const Color.fromARGB(255, 13, 32, 53)
        : (isFollowers
            ? AppColors.blue
            : const Color.fromARGB(235, 84, 87, 228));

    return GestureDetector(
      onTap: () {
        if (isFuture) {
          FuturePlansScreen.show(
            context: context,
            userId: widget.userId,
            isFollowing: isFollowing,
            onPlanSelected: (plan) => _showFrostedPlanDialog(plan),
          );
        } else {
          FollowingScreen.show(
            context: context,
            userId: widget.userId,
            showFollowersFirst: isFollowers,
          );
        }
      },
      child: SizedBox(
        width: 100,
        child: Column(
          children: [
            SvgPicture.asset(iconPath, width: 24, height: 24, color: iconColor),
            const SizedBox(height: 4),
            Text(
              count,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<int> _getFollowersCount(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('followers')
        .where('userId', isEqualTo: userId)
        .get();
    return snap.size;
  }

  Future<int> _getFollowedCount(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('followed')
        .where('userId', isEqualTo: userId)
        .get();
    return snap.size;
  }

  Widget _buildMemoriesOrLock() {
    if (_isPrivate && !isFollowing) {
      return Column(
        children: [
          SvgPicture.asset('assets/icono-candado.svg', width: 40, height: 40),
          const SizedBox(height: 8),
          const Text(
            'Este perfil es privado. Debes seguirle y ser aceptado para ver sus memorias.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      );
    }
    return MemoriesCalendar(
      userId: widget.userId,
      onPlanSelected: (plan) => _showFrostedPlanDialog(plan),
    );
  }

  void _showFrostedPlanDialog(PlanModel plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => new_frosted.FrostedPlanDialog(
          plan: plan,
          fetchParticipants: _fetchAllPlanParticipants,
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(
      PlanModel plan) async {
    final List<Map<String, dynamic>> res = [];
    final uds = plan.participants ?? [];
    for (final uid in uds) {
      final uDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (uDoc.exists) {
        final d = uDoc.data()!;
        res.add({
          'uid': uid,
          'name': d['name'] ?? 'Usuario',
          'age': d['age']?.toString() ?? '',
          'photoUrl': d['photoUrl'] ?? '',
          'isCreator': uid == plan.createdBy,
        });
      }
    }
    return res;
  }

  String _mapPrivilegeLevelToTitle(String level) {
    final normalized = level.toLowerCase().replaceAll('á', 'a');
    switch (normalized) {
      case 'premium':
        return 'Premium';
      case 'golden':
        return 'Golden';
      case 'vip':
        return 'VIP';
      default:
        return 'Básico';
    }
  }

  String _getPrivilegeIcon(String level) {
    final normalized = level.toLowerCase().replaceAll('á', 'a');
    switch (normalized) {
      case 'premium':
        return 'assets/icono-usuario-premium.png';
      case 'golden':
        return 'assets/icono-usuario-golden.png';
      case 'vip':
        return 'assets/icono-usuario-vip.png';
      default:
        return 'assets/icono-usuario-basico.png';
    }
  }
}
