import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/plan_model.dart';
import '../users_managing/privilege_level_details.dart';
import 'memories_calendar.dart';
import '../../main/colors.dart';
import '../../start/login_screen.dart';
import '../plans_managing/frosted_plan_dialog_state.dart';
import 'plan_memories_screen.dart';
import '../follow/following_screen.dart';
import '../future_plans/future_plans.dart';

// Manejo de imágenes
import 'user_images_managing.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final String placeholderImageUrl = "https://via.placeholder.com/150";

  // Foto de perfil
  String? profileImageUrl;

  // Fotos de portada
  List<String> coverImages = [];

  // Fotos adicionales
  List<String> additionalPhotos = [];

  // Nivel de privilegio
  String _privilegeLevel = "Básico";

  // Cargando
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileImage();
    _fetchCoverImages();
    _fetchAdditionalPhotos();
    _fetchPrivilegeLevel();
    _listenPrivilegeLevelUpdates();
  }

  // ---------------------- FIRESTORE LISTENERS ----------------------

  void _listenPrivilegeLevelUpdates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!mounted || !doc.exists) return;
      final raw = doc.data()?['privilegeLevel'];
      final newLevel = (raw ?? "Básico").toString();
      if (newLevel != _privilegeLevel) {
        setState(() => _privilegeLevel = newLevel);
      }
    });
  }

  Future<void> _fetchProfileImage() async {
    final url = await UserImagesManaging.fetchProfileImage(context);
    if (!mounted) return;
    setState(() => profileImageUrl = url);
  }

  Future<void> _fetchCoverImages() async {
    final covers = await UserImagesManaging.fetchCoverImages(context);
    if (!mounted) return;
    setState(() => coverImages = covers);
  }

  Future<void> _fetchAdditionalPhotos() async {
    final photos = await UserImagesManaging.fetchAdditionalPhotos(context);
    if (!mounted) return;
    setState(() => additionalPhotos = photos);
  }

  Future<void> _fetchPrivilegeLevel() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final raw = doc.data()?['privilegeLevel'];
        final newLevel = (raw ?? "Básico").toString();
        setState(() => _privilegeLevel = newLevel);
      }
    } catch (e) {
      debugPrint("[_fetchPrivilegeLevel] Error: $e");
    }
  }

  // ---------------------- PLANES ----------------------

  Future<List<Map<String, dynamic>>> _fetchParticipants(PlanModel p) async {
    final List<Map<String, dynamic>> participants = [];
    final subsSnap = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('id', isEqualTo: p.id)
        .get();
    for (var sDoc in subsSnap.docs) {
      final uid = sDoc.data()['userId'];
      final uDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final uData = uDoc.data();
      if (uData != null) {
        participants.add({
          'uid': uid,
          'name': uData['name'] ?? 'Sin nombre',
          'age': uData['age']?.toString() ?? '',
          'photoUrl': uData['photoUrl'] ?? uData['profilePic'] ?? '',
          'isCreator': (p.createdBy == uid),
        });
      }
    }
    return participants;
  }

  void _showPlanDialog(PlanModel plan) {
    showDialog(
      context: context,
      barrierDismissible: true,
      useSafeArea: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: SizedBox(
          width: MediaQuery.of(ctx).size.width,
          height: MediaQuery.of(ctx).size.height,
          child: FrostedPlanDialog(
            plan: plan,
            fetchParticipants: _fetchParticipants,
          ),
        ),
      ),
    );
  }

  // ---------------------- COVER IMAGES ----------------------

  Widget _buildCoverImagesWidget() {
    if (coverImages.isEmpty) {
      return GestureDetector(
        onTap: () => UserImagesManaging.addNewCoverImage(
          context,
          coverImages,
          onImagesUpdated: (newList) => setState(() => coverImages = newList),
          onLoading: (val) => setState(() => _isLoading = val),
        ),
        child: Container(
          height: 300,
          width: double.infinity,
          color: Colors.grey[300],
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.add, size: 30, color: Colors.black54),
                SizedBox(width: 8),
                Text("Añade una imagen de portada",
                    style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: coverImages.length,
            itemBuilder: (ctx, index) => GestureDetector(
              onTap: () => UserImagesManaging.openCoverImagesFullScreen(
                context,
                coverImages,
                index,
                onImagesUpdated: (updatedList) =>
                    setState(() => coverImages = updatedList),
                onProfileUpdated: (url) =>
                    setState(() => profileImageUrl = url),
              ),
              child: Image.network(
                coverImages[index],
                fit: BoxFit.cover,
                width: double.infinity,
                height: 300,
              ),
            ),
          ),
          // Puntos indicador
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  coverImages.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------- AVATAR ----------------------

  Widget _buildUserAvatarAndName() {
    final user = FirebaseAuth.instance.currentUser;
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildAvatarPlaceholder("Cargando...");
        }
        final data = snap.data?.data() as Map<String, dynamic>?;
        final userName = data?['name'] ?? 'Usuario';

        return Column(
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  InkWell(
                    onTap: () => UserImagesManaging.openProfileImageFullScreen(
                      context,
                      profileImageUrl ?? placeholderImageUrl,
                      onProfileDeleted: () =>
                          setState(() => profileImageUrl = ''),
                      onProfileChanged: (newUrl) =>
                          setState(() => profileImageUrl = newUrl),
                    ),
                    customBorder: const CircleBorder(),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 42,
                        backgroundImage: NetworkImage(
                          (profileImageUrl != null &&
                                  profileImageUrl!.isNotEmpty)
                              ? profileImageUrl!
                              : placeholderImageUrl,
                        ),
                      ),
                    ),
                  ),
                  Positioned(bottom: 0, right: 0, child: _avatarCameraIcon()),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(userName,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(width: 4),
                const Icon(Icons.verified, color: Colors.blue, size: 20),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvatarPlaceholder(String label) {
    return Column(
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                onTap: () => UserImagesManaging.openProfileImageFullScreen(
                  context,
                  profileImageUrl ?? placeholderImageUrl,
                  onProfileDeleted: () =>
                      setState(() => profileImageUrl = ''),
                  onProfileChanged: (newUrl) =>
                      setState(() => profileImageUrl = newUrl),
                ),
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 42,
                    backgroundImage:
                        NetworkImage(profileImageUrl ?? placeholderImageUrl),
                  ),
                ),
              ),
              Positioned(bottom: 0, right: 0, child: _avatarCameraIcon()),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
      ],
    );
  }

  Widget _avatarCameraIcon() => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => UserImagesManaging.changeProfileImage(
          context,
          onProfileUpdated: (newUrl) =>
              setState(() => profileImageUrl = newUrl),
          onLoading: (val) => setState(() => _isLoading = val),
        ),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color.fromARGB(255, 0, 0, 0),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
        ),
      );

  // ---------------------- PRIVILEGIO ----------------------

  Widget _buildPrivilegeButton(BuildContext context) => GestureDetector(
        onTap: _showPrivilegeLevelDetailsPopup,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(_getPrivilegeIcon(_privilegeLevel),
                    width: 52, height: 52),
                const SizedBox(height: 0),
                Text(_mapPrivilegeLevelToTitle(_privilegeLevel),
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      );

  String _mapPrivilegeLevelToTitle(String level) {
    final normalized = level.toLowerCase().replaceAll('á', 'a');
    switch (normalized) {
      case 'premium':
        return "Premium";
      case 'golden':
        return "Golden";
      case 'vip':
        return "VIP";
      default:
        return "Básico";
    }
  }

  String _getPrivilegeIcon(String level) {
    final normalized = level.toLowerCase().replaceAll('á', 'a');
    switch (normalized) {
      case 'premium':
        return "assets/icono-usuario-premium.png";
      case 'golden':
        return "assets/icono-usuario-golden.png";
      case 'vip':
        return "assets/icono-usuario-vip.png";
      default:
        return "assets/icono-usuario-basico.png";
    }
  }

  void _showPrivilegeLevelDetailsPopup() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      barrierLabel: 'Cerrar',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: Material(
                color: Colors.transparent,
                child: PrivilegeLevelDetails(userId: user.uid)),
          ),
        ),
      ),
    );
  }

  // ---------------------- STATS ----------------------

  Future<int> _getFollowersCount(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('followers')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  Future<int> _getFollowingCount(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('followed')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  Future<int> _getFuturePlanCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    final snap = await FirebaseFirestore.instance
        .collection('plans')
        .where('createdBy', isEqualTo: user.uid)
        .where('special_plan', isEqualTo: 0)
        .get();
    int counter = 0;
    final now = DateTime.now();
    for (final doc in snap.docs) {
      final data = doc.data();
      final ts = data['start_timestamp'];
      if (ts is Timestamp && ts.toDate().isAfter(now)) counter++;
    }
    return counter;
  }

  Widget _buildBioAndStats() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return FutureBuilder<int>(
      future: _getFuturePlanCount(),
      builder: (ctx1, snapPlanes) => FutureBuilder<int>(
        future: _getFollowersCount(user.uid),
        builder: (ctx2, snapFol) => FutureBuilder<int>(
          future: _getFollowingCount(user.uid),
          builder: (ctx3, snapIng) {
            if (snapPlanes.connectionState == ConnectionState.waiting ||
                snapFol.connectionState == ConnectionState.waiting ||
                snapIng.connectionState == ConnectionState.waiting) {
              return _buildStatsRow('...', '...', '...');
            }
            return _buildStatsRow(
              (snapPlanes.data ?? 0).toString(),
              (snapFol.data ?? 0).toString(),
              (snapIng.data ?? 0).toString(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsRow(String plans, String followers, String following) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStatItem('planes futuros', plans),
          const SizedBox(width: 20),
          _buildStatItem('seguidores', followers),
          const SizedBox(width: 20),
          _buildStatItem('seguidos', following),
        ],
      );

  Widget _buildStatItem(String label, String count) {
    final isPlans = label == 'planes futuros';
    final isFollowers = label == 'seguidores';
    final iconPath =
        isPlans ? 'assets/icono-calendario.svg' : 'assets/icono-seguidores.svg';
    final iconColor = isPlans
        ? AppColors.blue
        : (isFollowers
            ? AppColors.blue
            : const Color.fromARGB(235, 84, 87, 228));

    final content = Column(
      children: [
        SvgPicture.asset(iconPath, width: 24, height: 24, color: iconColor),
        const SizedBox(height: 4),
        Text(count,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF868686))),
      ],
    );

    return GestureDetector(
      onTap: () {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        if (isPlans) {
          FuturePlansScreen.show(
            context: context,
            userId: user.uid,
            isFollowing: true,
            onPlanSelected: (plan) => _showPlanDialog(plan),
          );
        } else {
          FollowingScreen.show(
            context: context,
            userId: user.uid,
            showFollowersFirst: isFollowers,
          );
        }
      },
      child: SizedBox(width: 100, child: content),
    );
  }

  // ---------------------- BUILD ----------------------

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Portada + Avatar (ahora avatar totalmente dentro del Stack)
            SizedBox(
              height: 380, // 300 portada + 80 avatar
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildCoverImagesWidget(),
                  // Botón añadir portada
                  Positioned(
                    top: 40,
                    right: 16,
                    child: ClipOval(
                      child: Container(
                        width: 40,
                        height: 40,
                        color: Colors.white.withOpacity(0.6),
                        child: IconButton(
                          icon: SvgPicture.asset('assets/anadir.svg',
                              width: 24, height: 24, color: AppColors.blue),
                          onPressed: () => UserImagesManaging.addNewCoverImage(
                            context,
                            coverImages,
                            onImagesUpdated: (newList) =>
                                setState(() => coverImages = newList),
                            onLoading: (val) =>
                                setState(() => _isLoading = val),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Avatar (bottom: 0 para estar dentro del área de hit-test)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Center(child: _buildUserAvatarAndName()),
                  ),
                ],
              ),
            ),

            // Privilegio
            const SizedBox(height: 16),
            _buildPrivilegeButton(context),
            const SizedBox(height: 16),

            // Stats
            _buildBioAndStats(),
            const SizedBox(height: 20),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 200,
                  child:
                      const Divider(color: Colors.grey, thickness: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Calendario de memorias
            if (user != null)
              MemoriesCalendar(
                userId: user.uid,
                onPlanSelected: (plan) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlanMemoriesScreen(
                      plan: plan,
                      fetchParticipants: _fetchParticipants,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Logout
            Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()));
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text('Cerrar sesión',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
