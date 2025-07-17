import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../main/colors.dart';
import '../../models/plan_model.dart';
import '../plans_managing/frosted_plan_dialog_state.dart' as new_frosted;
import '../special_plans/invite_users_to_plan_screen.dart';
import '../chats/chat_screen.dart'; // <-- Importamos ChatScreen
import 'privilege_level_details.dart';
import '../profile/memories_calendar.dart';
import '../follow/following_screen.dart';
import '../future_plans/future_plans.dart';
import 'report_and_block_user.dart'; // Import para Reportar/Bloquear
import '../../l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../users_grid/users_grid_helpers.dart';

class UserInfoCheck extends StatefulWidget {
  final String userId;
  final String? initialPlanId;

  const UserInfoCheck({Key? key, required this.userId, this.initialPlanId})
      : super(key: key);

  /// Método estático para abrir el perfil de [userId].
  /// Primero comprueba si el usuario actual está bloqueado.
  /// Si está bloqueado, no navega y muestra un SnackBar.
  static Future<void> open(BuildContext context, String userId,
      {String? planId}) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final docId = '${userId}_${me.uid}';
    final doc = await FirebaseFirestore.instance
        .collection('blocked_users')
        .doc(docId)
        .get();

    if (doc.exists) {
      // El userId me ha bloqueado a mí => No entro
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes acceder al perfil porque te ha bloqueado.'),
        ),
      );
      return;
    }

    // Si NO hay bloqueo, abrimos la pantalla
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => UserInfoCheck(userId: userId, initialPlanId: planId)),
    );
  }

  @override
  State<UserInfoCheck> createState() => _UserInfoCheckState();
}

class _UserInfoCheckState extends State<UserInfoCheck> {
  // DocumentSnapshot del usuario
  DocumentSnapshot? _userDocSnap;

  // Variables de perfil
  String? _profileImageUrl;
  String? _coverImageUrl;
  String _privilegeLevel = 'Básico';
  bool _isPrivate = false;

  /// Indica si YO he bloqueado a este usuario (importante para nuestro menú)
  bool _isUserBlocked = false;

  // Otras banderas
  bool isFollowing = false;
  // Por defecto las notificaciones individuales están activadas
  bool _notificationsEnabled = true;
  bool _isRequestPending = false;

  // Future para cargar todo
  late Future<void> _futureInit;

  @override
  void initState() {
    super.initState();
    _futureInit = _initAllData().then((_) {
      if (widget.initialPlanId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isPrivate || isFollowing) {
            FuturePlansScreen.show(
              context: context,
              userId: widget.userId,
              isFollowing: isFollowing,
              highlightPlanId: widget.initialPlanId,
              onPlanSelected: (p) => _showFrostedPlanDialog(p),
            );
          }
        });
      }
    });
  }

  /// Cargamos de Firestore el doc del usuario, más
  /// stats y si está bloqueado, etc.
  Future<void> _initAllData() async {
    // 1. Leo el documento del user
    final docSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    if (!docSnap.exists) {
      // Manejar usuario inexistente (se capturará en el FutureBuilder)
      return;
    }

    // 2. Guardo info en variables de estado
    final data = docSnap.data() as Map<String, dynamic>;
    _userDocSnap = docSnap;

    _profileImageUrl = data['photoUrl'] ?? data['profilePic'] ?? '';
    _coverImageUrl = data['coverPhotoUrl'] ?? '';
    _privilegeLevel = (data['privilegeLevel'] ?? 'Básico').toString();
    _isPrivate = (data['profile_privacy'] ?? 0) == 1;

    // 3. Llamadas extra
    await _updateStatsBasedOnAllPlans();
    await _checkIfFollowing();
    await _checkIfFollowRequestIsPending();
    await _checkIfUserIsBlocked();
  }

  //----------------------------------------------------------------------------
  // Actualiza estadísticas de planes
  //----------------------------------------------------------------------------
  Future<void> _updateStatsBasedOnAllPlans() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('plans')
          .where('createdBy', isEqualTo: widget.userId)
          .where('special_plan', isEqualTo: 0)
          .get();

      int total = 0;
      int maxInOne = 0;
      int countCreated = 0;

      for (final d in snap.docs) {
        final data = d.data();
        final List<dynamic> checked = data['checkedInUsers'] ?? [];
        final c = checked.length;
        total += c;
        if (c > maxInOne) maxInOne = c;
        if (c > 0) countCreated++;
      }

      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userId);

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
    }
  }

  //----------------------------------------------------------------------------
  // Checa si le estoy siguiendo
  //----------------------------------------------------------------------------
  Future<void> _checkIfFollowing() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('followed')
        .where('userId', isEqualTo: me.uid)
        .where('followedId', isEqualTo: widget.userId)
        .get();

    isFollowing = snap.docs.isNotEmpty;
  }

  //----------------------------------------------------------------------------
  // Checa si hay solicitud pendiente (perfiles privados)
  //----------------------------------------------------------------------------
  Future<void> _checkIfFollowRequestIsPending() async {
    if (!_isPrivate) return; // Solo aplica a privados
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    try {
      final q = await FirebaseFirestore.instance
          .collection('follow_requests')
          .where('fromId', isEqualTo: me.uid)
          .where('toId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      _isRequestPending = (q.docs.isNotEmpty && !isFollowing);
    } catch (e) {
    }
  }

  //----------------------------------------------------------------------------
  // Comprueba si YO he bloqueado al otro
  //----------------------------------------------------------------------------
  Future<void> _checkIfUserIsBlocked() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final docId = '${me.uid}_${widget.userId}';
    final doc = await FirebaseFirestore.instance
        .collection('blocked_users')
        .doc(docId)
        .get();

    setState(() {
      _isUserBlocked = doc.exists;
    });
  }

  //----------------------------------------------------------------------------
  // build principal -> FutureBuilder para _initAllData
  //----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _futureInit,
      builder: (context, snapshot) {
        // Mientras se carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Si hubo error
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }
        // Si el doc no existe (por ejemplo, usuario borrado)
        if (_userDocSnap == null || !_userDocSnap!.exists) {
          return const Scaffold(
            body: Center(child: Text('Usuario no encontrado')),
          );
        }

        // YA tenemos toda la data -> Dibujamos la UI final
        return _buildMainContent();
      },
    );
  }

  Widget _buildMainContent() {
    final data = _userDocSnap!.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Usuario';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: true,
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            children: [
              _buildHeader(name),
            const SizedBox(height: 30),
            _buildPrivilegeButton(),
            _buildBioAndStats(),
            const SizedBox(height: 20),
            _buildActionButtons(widget.userId),
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
      ),
    ),
  );
  }

  //----------------------------------------------------------------------------
  // Header (portada + avatar + botones)
  //----------------------------------------------------------------------------
  Widget _buildHeader(String name) {
    return SizedBox(
      height: 420, // 300 de portada + 80 para alojar el avatar
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildCoverImage(),
          Positioned(
            top: 40,
            left: 16,
            child: _buildBackButton(),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: _buildMenuButton(),
          ),
          Positioned(
            bottom: -42,
            left: 0,
            right: 0,
            child: Center(child: _buildAvatarAndName(name)),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return ClipOval(
      child: Container(
        color: Colors.black.withOpacity(.5),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildMenuButton() {
    return ClipOval(
      child: Container(
        color: Colors.black.withOpacity(.5),
        child: IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: _showOptionsMenu,
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    final hasCover = _coverImageUrl != null && _coverImageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: hasCover ? () => _showFullImage(_coverImageUrl!) : null,
      child: Container(
        height: 380,
        width: double.infinity,
        color: Colors.grey[300],
        child: hasCover
            ? CachedNetworkImage(
                imageUrl: _coverImageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) => buildPlaceholder(),
              )
            : Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.image, size: 30, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('Sin portada',
                        style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAvatarAndName(String userName) {
    String? avatarUrl;
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      avatarUrl = _profileImageUrl!;
    } else if (_coverImageUrl != null && _coverImageUrl!.isNotEmpty) {
      avatarUrl = _coverImageUrl!;
    }

    return Column(
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                onTap:
                    avatarUrl == null ? null : () => _showFullImage(avatarUrl!),
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 42,
                    backgroundImage:
                        avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                    backgroundColor: Colors.grey[300],
                    child: avatarUrl == null
                        ? SvgPicture.asset('assets/usuario.svg',
                            width: 42, height: 42)
                        : null,
                  ),
                ),
              ),
            ],
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

  void _showFullImage(String imageUrl) {
    if (imageUrl.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) => const Icon(Icons.error),
                  ),
                ),
              ),
              Positioned(
                top: 50,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    color: Colors.black54,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //----------------------------------------------------------------------------
  // Menú de 3 puntos (notificaciones, reportar, bloquear)
  //----------------------------------------------------------------------------
  void _showOptionsMenu() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final t = AppLocalizations.of(context);
            final blockText =
                _isUserBlocked ? t.unblockProfile : t.blockProfile;

            return Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.transparent,
                    ),
                  ),
                  Positioned(
                    top: 55,
                    right: 16,
                    child: GestureDetector(
                      onTap: () {},
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            color: const Color.fromARGB(255, 114, 114, 114)
                                .withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      _notificationsEnabled =
                                          !_notificationsEnabled;
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      SvgPicture.asset(
                                        _notificationsEnabled
                                            ? 'assets/icono-campana-activada.svg'
                                            : 'assets/icono-campana-desactivada.svg',
                                        width: 24,
                                        height: 24,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _notificationsEnabled
                                            ? t.disableNotifications
                                            : t.enableNotifications,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(color: Colors.white54),
                                InkWell(
                                  onTap: () {
                                    final me =
                                        FirebaseAuth.instance.currentUser;
                                    if (me == null) return;
                                    ReportAndBlockUser.goToReportScreen(
                                      context,
                                      widget.userId,
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      SvgPicture.asset(
                                        'assets/icono-reportar.svg',
                                        width: 24,
                                        height: 24,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        t.reportProfile,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(color: Colors.white54),
                                InkWell(
                                  onTap: () async {
                                    final me =
                                        FirebaseAuth.instance.currentUser;
                                    if (me == null) return;

                                    final oldValue = _isUserBlocked;

                                    setState(() {
                                      _isUserBlocked = !_isUserBlocked;
                                    });
                                    setDialogState(() {});

                                    try {
                                      await ReportAndBlockUser.toggleBlockUser(
                                        context,
                                        me.uid,
                                        widget.userId,
                                        oldValue,
                                      );
                                    } catch (e) {
                                      setState(() {
                                        _isUserBlocked = oldValue;
                                      });
                                      setDialogState(() {});
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      SvgPicture.asset(
                                        'assets/icono-bloquear.svg',
                                        width: 24,
                                        height: 24,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        blockText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  //----------------------------------------------------------------------------
  // Botón de Privilegio (Básico, Premium, etc.)
  //----------------------------------------------------------------------------
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
              Image.asset(
                _getPrivilegeIcon(_privilegeLevel),
                width: 52,
                height: 52,
              ),
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
                child: PrivilegeLevelDetails(
                  userId: widget.userId,
                  showAllInfo: false,
                ),
              ),
            ),
          ),
        );
      },
    );
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
        return Localizations.localeOf(context).languageCode == 'en'
            ? 'Basic'
            : 'Básico';
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

  //----------------------------------------------------------------------------
  // Sección de estadísticas (planes futuros, seguidores, seguidos)
  //----------------------------------------------------------------------------
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
    final t = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem(t.futurePlans, planes),
        const SizedBox(width: 20),
        _buildStatItem(t.followers, followers),
        const SizedBox(width: 20),
        _buildStatItem(t.following, followed),
      ],
    );
  }

  Widget _buildStatItem(String label, String count) {
    final t = AppLocalizations.of(context);
    final isFuture = label == t.futurePlans;
    final isFollowers = label == t.followers;
    final iconPath = isFuture
        ? 'assets/icono-calendario.svg'
        : 'assets/icono-seguidores.svg';

    final iconColor = isFuture
        ? AppColors.planColor
        : (isFollowers
            ? AppColors.planColor
            : AppColors.planColor);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_isPrivate && !isFollowing) {
          _showPrivateToast();
          return;
        }
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
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
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

  Future<int> _getFollowersCount(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('followers')
        .where('userId', isEqualTo: userId)
        .get();

    int counter = 0;
    for (final doc in snap.docs) {
      final followerId = doc.data()['followerId'];
      if (followerId == null) continue;
      final uDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(followerId)
          .get();
      if (uDoc.exists) counter++;
    }

    return counter;
  }

  Future<int> _getFollowedCount(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('followed')
        .where('userId', isEqualTo: userId)
        .get();

    int counter = 0;
    for (final doc in snap.docs) {
      final followedId = doc.data()['followedId'];
      if (followedId == null) continue;
      final uDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(followedId)
          .get();
      if (uDoc.exists) counter++;
    }

    return counter;
  }

  //----------------------------------------------------------------------------
  // Botones principales: Invitar, Mensaje, Seguir
  //----------------------------------------------------------------------------
  Widget _buildActionButtons(String otherUserId) {
    final t = AppLocalizations.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildActionButton(
          iconPath: 'assets/union.svg',
          label: t.inviteToPlan,
          onTap: (_isPrivate && !isFollowing && !_isRequestPending)
              ? _showPrivateToast
              : () => InviteUsersToPlanScreen.showPopup(context, otherUserId),
        ),
        _buildActionButton(
          iconPath: 'assets/mensaje.svg',
          label: t.sendMessage,
          onTap: () {
            if (_isPrivate && !isFollowing) {
              _showPrivateToast();
            } else {
              final data = _userDocSnap!.data() as Map<String, dynamic>;
              final userName = data['name'] ?? 'Usuario';
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    chatPartnerId: widget.userId,
                    chatPartnerName: userName,
                    chatPartnerPhoto: _profileImageUrl ?? '',
                  ),
                ),
              );
            }
          },
        ),
        _buildActionButton(
          iconPath: _getFollowIcon(),
          label: _getFollowLabel(t),
          onTap: _handleFollowTap,
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
                  AppColors.planColor,
                  AppColors.planColor,
                  AppColors.planColor,
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
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getFollowLabel(AppLocalizations t) {
    if (isFollowing) {
      return t.followingStatus;
    } else if (_isRequestPending) {
      return t.requested;
    } else {
      return t.follow;
    }
  }

  String _getFollowIcon() {
    if (isFollowing) {
      return 'assets/icono-tick.svg';
    } else if (_isRequestPending) {
      return 'assets/agregar-usuario.svg';
    } else {
      return 'assets/agregar-usuario.svg';
    }
  }

  /// Al pulsar el botón de Seguir / Dejar de Seguir / Cancelar Solicitud
  void _handleFollowTap() async {
    if (isFollowing) {
      await _unfollowUser();
    } else if (_isRequestPending) {
      await _cancelFollowRequest();
    } else {
      await _followUser();
    }
    setState(() {});
  }

  Future<void> _unfollowUser() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || me.uid == widget.userId) return;

    try {
      // Borrar en "followed"
      final f1 = await FirebaseFirestore.instance
          .collection('followed')
          .where('userId', isEqualTo: me.uid)
          .where('followedId', isEqualTo: widget.userId)
          .get();
      for (final d in f1.docs) {
        await d.reference.delete();
      }

      // Borrar en "followers"
      final f2 = await FirebaseFirestore.instance
          .collection('followers')
          .where('userId', isEqualTo: widget.userId)
          .where('followerId', isEqualTo: me.uid)
          .get();
      for (final d in f2.docs) {
        await d.reference.delete();
      }

      isFollowing = false;
    } catch (e) {
    }
  }

  Future<void> _followUser() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || me.uid == widget.userId) return;

    try {
      if (!_isPrivate) {
        // Perfil público
        await FirebaseFirestore.instance.collection('followers').add({
          'userId': widget.userId,
          'followerId': me.uid,
        });
        await FirebaseFirestore.instance.collection('followed').add({
          'userId': me.uid,
          'followedId': widget.userId,
        });
        isFollowing = true;
      } else {
        // Perfil privado => guardamos en follow_requests + notificación
        await FirebaseFirestore.instance.collection('follow_requests').add({
          'fromId': me.uid,
          'toId': widget.userId,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(me.uid)
            .get();
        final currentUserName =
            userDoc.exists ? (userDoc.data()?['name'] ?? '') : '';
        final currentUserPhotoUrl =
            userDoc.exists ? (userDoc.data()?['photoUrl'] ?? '') : '';

        await FirebaseFirestore.instance.collection('notifications').add({
          'type': 'follow_request',
          'receiverId': widget.userId,
          'senderId': me.uid,
          'senderName': currentUserName,
          'senderProfilePic': currentUserPhotoUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud enviada. Espera a que te responda'),
          ),
        );
        _isRequestPending = true;
      }
    } catch (e) {
    }
  }

  /// Cancela la solicitud de seguimiento pendiente
  Future<void> _cancelFollowRequest() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || me.uid == widget.userId) return;

    try {
      // Eliminar la solicitud de follow_requests
      final q = await FirebaseFirestore.instance
          .collection('follow_requests')
          .where('fromId', isEqualTo: me.uid)
          .where('toId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      for (final doc in q.docs) {
        await doc.reference.delete();
      }

      // Eliminar la notificación de tipo follow_request
      final noti = await FirebaseFirestore.instance
          .collection('notifications')
          .where('type', isEqualTo: 'follow_request')
          .where('receiverId', isEqualTo: widget.userId)
          .where('senderId', isEqualTo: me.uid)
          .limit(1)
          .get();
      for (final doc in noti.docs) {
        await doc.reference.delete();
      }

      _isRequestPending = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud de seguimiento cancelada.')),
      );
    } catch (e) {
    }
  }

  //----------------------------------------------------------------------------
  // Toast si es privado y no puedo invitar/chatear
  //----------------------------------------------------------------------------
  void _showPrivateToast() {
    final t = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.privateUser),
      ),
    );
  }

  //----------------------------------------------------------------------------
  // Memorias o candado
  //----------------------------------------------------------------------------
  Widget _buildMemoriesOrLock() {
    if (_isPrivate && !isFollowing) {
      return Column(
        children: [
          SvgPicture.asset('assets/icono-candado.svg', width: 40, height: 40),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).privateProfileMemories,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
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
    PlanModel plan,
  ) async {
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
          'photoUrl': d['photoUrl'] ?? '',
          'privilegeLevel': (d['privilegeLevel'] ?? 'Básico').toString(),
          'isCreator': uid == plan.createdBy,
        });
      }
    }
    return res;
  }
}
