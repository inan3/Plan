//user_grid.dart
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/plan_model.dart';
import '../../main/colors.dart';
import '../plans_managing/firebase_services.dart';
import '../../l10n/app_localizations.dart';
import 'users_grid_helpers.dart';
import '../plans_managing/plan_card.dart';
import '../special_plans/invite_users_to_plan_screen.dart';
import '../users_managing/user_info_check.dart';
import '../chats/chat_screen.dart';

// Importa nuestro widget que usa RTDB:
import '../users_managing/user_activity_status.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UsersGrid extends StatefulWidget {
  final void Function(dynamic userDoc)? onUserTap;
  final List<dynamic> users;

  const UsersGrid({
    Key? key,
    required this.users,
    this.onUserTap,
  }) : super(key: key);

  @override
  State<UsersGrid> createState() => _UsersGridState();
}

class _UsersGridState extends State<UsersGrid> {
  bool _loading = true;
  final List<Map<String, dynamic>> _processedUsers = [];
  final Map<String, List<PlanModel>> _plansData = {};

  final ScrollController _scrollController = ScrollController();
  int _currentIndex = 0;
  final int _batchSize = 10;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNextBatch();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNextBatch() async {
    if (_currentIndex >= widget.users.length) {
      setState(() => _loadingMore = false);
      return;
    }

    final end =
        (_currentIndex + _batchSize) > widget.users.length
            ? widget.users.length
            : _currentIndex + _batchSize;
    final batch = widget.users.sublist(_currentIndex, end);
    _currentIndex = end;

    final List<Map<String, dynamic>> tempUsers = [];
    final Map<String, List<PlanModel>> tempPlans = {};

    final futures = batch.map((u) async {
      final baseData = u is QueryDocumentSnapshot
          ? (u.data() as Map<String, dynamic>)
          : u as Map<String, dynamic>;
      final uid = baseData['uid']?.toString();
      if (uid == null) return null;

      final userDocFuture =
          FirebaseFirestore.instance.collection('users').doc(uid).get();
      final plansFuture = fetchUserPlans(uid);

      final userDoc = await userDocFuture;
      final liveData = userDoc.data() as Map<String, dynamic>? ?? {};
      final plans = await plansFuture;

      return {
        'user': {...baseData, ...liveData},
        'uid': uid,
        'plans': plans,
      };
    });

    final results = await Future.wait(futures);
    for (final r in results) {
      if (r == null) continue;
      tempUsers.add(r['user'] as Map<String, dynamic>);
      tempPlans[r['uid'] as String] = (r['plans'] as List<PlanModel>);
    }

    if (!mounted) return;
    setState(() {
      _processedUsers.addAll(tempUsers);
      _plansData.addAll(tempPlans);
      _loading = false;
      _loadingMore = false;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _currentIndex < widget.users.length) {
      setState(() {
        _loadingMore = true;
      });
      _loadNextBatch();
    }
  }
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
        content: Text(
            'No puedes interactuar con este perfil porque te ha bloqueado.'),
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
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

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
            content:
                const Text("Debes seguir a este usuario para interactuar."),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 120),
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: _processedUsers.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _processedUsers.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final userData = _processedUsers[index];
        final uid = userData['uid']?.toString();
        final plans = (uid != null) ? _plansData[uid] ?? [] : <PlanModel>[];
        return _buildUserCard(userData, plans, context);
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Tarjeta por usuario
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildUserCard(
      Map<String, dynamic> userData, List<PlanModel> plans, BuildContext context) {
    final String? uid = userData['uid']?.toString();
    if (uid == null) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: Text('Usuario inválido', style: TextStyle(color: Colors.red)),
        ),
      );
    }

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
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Layout usuario SIN planes
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildNoPlanLayout(
      BuildContext context, Map<String, dynamic> userData) {
    final String name = userData['name']?.toString().trim() ?? 'Usuario';
    final String? uid = userData['uid']?.toString();
    final String? fallbackPhotoUrl = userData['photoUrl']?.toString();
    final String? coverPhotoUrl = userData['coverPhotoUrl']?.toString();
    final bool showActivity = userData['activityStatusPublic'] != false;

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
              child: (coverPhotoUrl != null && coverPhotoUrl.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: coverPhotoUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (_, __) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (_, __, ___) => buildPlaceholder(),
                    )
                  : (fallbackPhotoUrl != null && fallbackPhotoUrl.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: fallbackPhotoUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (_, __) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (_, __, ___) => buildPlaceholder(),
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
                      color: const Color.fromARGB(255, 14, 14, 14)
                          .withOpacity(0.2),
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
                                  Image.asset(
                                    _getPrivilegeIcon(
                                        userData['privilegeLevel']?.toString() ??
                                            'Básico'),
                                    width: 14,
                                    height: 14,
                                  ),
                                ],
                              ),
                              // AQUI LLAMAMOS AL WIDGET DE PRESENCIA
                              if (uid != null && showActivity)
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
                            child: Text(
                              AppLocalizations.of(context).userNoPlans,
                              style: const TextStyle(color: Colors.white),
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
          label: AppLocalizations.of(context).inviteToPlan,
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
