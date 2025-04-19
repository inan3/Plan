// lib/explore_screen/profile/profile_screen.dart

import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final String placeholderImageUrl = "https://via.placeholder.com/150";

  // Avatar, portada y privilegio
  String? profileImageUrl;
  String? coverImageUrl;
  String _privilegeLevel = "Básico";

  // Fotos adicionales
  List<String> additionalPhotos = [];
  bool _isLoading = false;

  // ImagePicker
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchProfileImage();
    _fetchCoverImage();
    _fetchAdditionalPhotos();
    _fetchPrivilegeLevel();
    _listenPrivilegeLevelUpdates();
  }

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

  Future<void> _fetchPrivilegeLevel() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final raw = doc.data()?['privilegeLevel'];
        final newLevel = (raw ?? "Básico").toString();
        setState(() => _privilegeLevel = newLevel);
      }
    } catch (e) {
      debugPrint("[_fetchPrivilegeLevel] Error: $e");
    }
  }

  Future<void> _fetchProfileImage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      setState(() {
        profileImageUrl = doc.data()?['photoUrl'] ?? "";
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar la foto de perfil: $e')),
      );
    }
  }

  Future<void> _fetchCoverImage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      setState(() {
        coverImageUrl = doc.data()?['coverPhotoUrl'] ?? "";
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar la foto de portada: $e')),
      );
    }
  }

  Future<void> _fetchAdditionalPhotos() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final photos = doc.data()?['additionalPhotos'] as List<dynamic>?;
      if (!mounted) return;
      setState(() {
        additionalPhotos = photos?.cast<String>() ?? [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar las fotos adicionales: $e')),
      );
    }
  }

  /// IMPORTANTE: Al mostrar un plan, pedimos la lista de participantes
  /// (aunque en la nueva lógica solemos usar `checkedInUsers` para confirmar).
  Future<List<Map<String, dynamic>>> _fetchParticipants(PlanModel p) async {
    final List<Map<String, dynamic>> participants = [];
    final subsSnap = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('id', isEqualTo: p.id)
        .get();
    for (var sDoc in subsSnap.docs) {
      final uid = sDoc.data()['userId'];
      final uDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
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

  Future<void> _showAvatarSourceActionSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.2),
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Seleccionar de la galería'),
              onTap: () async {
                Navigator.pop(context);
                final pickedFile = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                );
                if (pickedFile != null) {
                  setState(() => _isLoading = true);
                  await _uploadAvatarImage(File(pickedFile.path));
                  setState(() => _isLoading = false);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Tomar una foto'),
              onTap: () async {
                Navigator.pop(context);
                final pickedFile = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                );
                if (pickedFile != null) {
                  setState(() => _isLoading = true);
                  await _uploadAvatarImage(File(pickedFile.path));
                  setState(() => _isLoading = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadAvatarImage(File image) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final ref = FirebaseStorage.instance
          .ref()
          .child('avatar_photos')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(image);
      final imageUrl = await ref.getDownloadURL();
      if (!mounted) return;
      setState(() => profileImageUrl = imageUrl);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'photoUrl': imageUrl});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la imagen: $e')),
      );
    }
  }

  Future<void> _changeBackgroundImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.2),
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Seleccionar de la galería'),
              onTap: () async {
                Navigator.pop(context);
                final pickedFile = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                );
                if (pickedFile != null) {
                  setState(() => _isLoading = true);
                  await _uploadBackgroundImage(File(pickedFile.path));
                  setState(() => _isLoading = false);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Tomar una foto'),
              onTap: () async {
                Navigator.pop(context);
                final pickedFile = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                );
                if (pickedFile != null) {
                  setState(() => _isLoading = true);
                  await _uploadBackgroundImage(File(pickedFile.path));
                  setState(() => _isLoading = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadBackgroundImage(File image) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final ref = FirebaseStorage.instance
          .ref()
          .child('cover_photos')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(image);
      final imageUrl = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'coverPhotoUrl': imageUrl});
      if (!mounted) return;
      setState(() => coverImageUrl = imageUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fondo actualizado con éxito')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar el fondo: $e')),
      );
    }
  }

  Future<void> _showImageSourceActionSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.2),
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Seleccionar imágenes'),
              onTap: () {
                Navigator.pop(context);
                _pickMultipleImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Tomar una foto'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMultipleImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null) {
        setState(() => _isLoading = true);
        for (var file in result.files) {
          if (file.path != null) {
            await _uploadAndAddImage(File(file.path!));
          }
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imágenes: $e')),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      if (pickedFile != null) {
        setState(() => _isLoading = true);
        await _uploadAndAddImage(File(pickedFile.path));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al tomar la foto: $e')),
      );
    }
  }

  Future<void> _uploadAndAddImage(File image) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final ref = FirebaseStorage.instance
          .ref()
          .child('user_photos')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(image);
      final imageUrl = await ref.getDownloadURL();
      if (!mounted) return;
      setState(() => additionalPhotos.add(imageUrl));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'additionalPhotos': additionalPhotos});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la imagen: $e')),
      );
    }
  }

  Future<void> _setAsProfilePhoto(String imageUrl) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'photoUrl': imageUrl});
      if (!mounted) return;
      setState(() => profileImageUrl = imageUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar la foto de perfil: $e')),
      );
    }
  }

  Future<void> _deletePhoto(String imageUrl) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      await ref.delete();
      if (!mounted) return;
      setState(() => additionalPhotos.remove(imageUrl));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'additionalPhotos': additionalPhotos});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen eliminada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar la foto: $e')),
      );
    }
  }

  Widget _buildCoverImage() {
    final hasCover = (coverImageUrl != null &&
        coverImageUrl!.isNotEmpty &&
        coverImageUrl! != placeholderImageUrl);
    return GestureDetector(
      onTap: _changeBackgroundImage,
      child: Container(
        height: 300,
        width: double.infinity,
        color: Colors.grey[300],
        child: hasCover
            ? Image.network(coverImageUrl!, fit: BoxFit.cover)
            : Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add, size: 30, color: Colors.black54),
                    SizedBox(width: 8),
                    Text(
                      "Añade una imagen de portada",
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildUserAvatarAndName() {
    final user = FirebaseAuth.instance.currentUser;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildAvatarPlaceholder("Cargando...");
        }
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final userName = data?['name'] ?? 'Usuario';
        return Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: _showAvatarSourceActionSheet,
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 42,
                      backgroundImage: NetworkImage(
                        (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                            ? profileImageUrl!
                            : placeholderImageUrl,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: _avatarCameraIcon(),
                ),
              ],
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
          ],
        );
      },
    );
  }

  Widget _buildAvatarPlaceholder(String label) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: _showAvatarSourceActionSheet,
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
            Positioned(
              bottom: 0,
              right: 0,
              child: _avatarCameraIcon(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _avatarCameraIcon() => GestureDetector(
        onTap: _showAvatarSourceActionSheet,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.shade400,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
        ),
      );

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
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                child: PrivilegeLevelDetails(userId: user.uid),
              ),
            ),
          ),
        );
      },
    );
  }

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

  /// Devuelve la cantidad de planes (futuros) creados por el user
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
      if (ts is Timestamp && ts.toDate().isAfter(now)) {
        counter++;
      }
    }
    return counter;
  }

  Widget _buildBioAndStats() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<int>(
      future: _getFuturePlanCount(),
      builder: (ctx1, snapPlanes) {
        return FutureBuilder<int>(
          future: _getFollowersCount(user.uid),
          builder: (ctx2, snapFol) {
            return FutureBuilder<int>(
              future: _getFollowingCount(user.uid),
              builder: (ctx3, snapIng) {
                if (snapPlanes.connectionState == ConnectionState.waiting ||
                    snapFol.connectionState == ConnectionState.waiting ||
                    snapIng.connectionState == ConnectionState.waiting) {
                  return _buildStatsRow('...', '...', '...');
                }
                final plans = snapPlanes.data ?? 0;
                final followers = snapFol.data ?? 0;
                final following = snapIng.data ?? 0;
                return _buildStatsRow(
                  plans.toString(),
                  followers.toString(),
                  following.toString(),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatsRow(String plans, String followers, String following) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem('planes futuros', plans),
        const SizedBox(width: 20),
        _buildStatItem('seguidores', followers),
        const SizedBox(width: 20),
        _buildStatItem('seguidos', following),
      ],
    );
  }

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
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF868686)),
        ),
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

  void _openPhotoViewer(int initialIndex) {
    PageController controller = PageController(initialPage: initialIndex);
    int currentPage = initialIndex;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) {
          return Dialog(
            backgroundColor: Colors.white,
            child: Stack(
              children: [
                PageView.builder(
                  controller: controller,
                  onPageChanged: (i) => setState(() => currentPage = i),
                  itemCount: additionalPhotos.length,
                  itemBuilder: (_, i) {
                    return Container(
                      color: Colors.white,
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            additionalPhotos[i],
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: PopupMenuButton<String>(
                    onSelected: (value) async {
                      final url = additionalPhotos[currentPage];
                      if (value == 'set_as_profile') {
                        await _setAsProfilePhoto(url);
                      } else if (value == 'delete') {
                        await _deletePhoto(url);
                        Navigator.of(context).pop();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'set_as_profile',
                        child: Text('Establecer como foto de perfil'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar imagen'),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      '${currentPage + 1}/${additionalPhotos.length}',
                      style: const TextStyle(fontSize: 32, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildCoverImage(),
                Positioned(
                  top: 40,
                  right: 16,
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.2),
                              Colors.white.withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.more_vert, color: AppColors.blue),
                          onPressed: _changeBackgroundImage,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildUserAvatarAndName()),
                ),
              ],
            ),
            const SizedBox(height: 70),
            _buildPrivilegeButton(context),
            const SizedBox(height: 16),
            _buildBioAndStats(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 200,
                  child: const Divider(
                    color: Colors.grey,
                    thickness: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (user != null)
              MemoriesCalendar(
                userId: user.uid,
                onPlanSelected: (plan) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlanMemoriesScreen(
                        plan: plan,
                        fetchParticipants: _fetchParticipants,
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
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
