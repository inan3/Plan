import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../main/colors.dart';
import '../../start/login_screen.dart';
import '../users_managing/privilege_level_details.dart';
import 'memories_calendar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final String placeholderImageUrl = "https://via.placeholder.com/150";

  // ================================
  // Campos para avatar y portada
  // ================================
  String? profileImageUrl; // Foto de perfil
  String? coverImageUrl;   // Foto de portada

  // Privilegio actual en formato String ("basico", "premium", "vip", etc.)
  String _privilegeLevel = "basico";

  List<String> additionalPhotos = [];
  bool _isLoading = false;

  // Declaramos el ImagePicker solo una vez
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchProfileImage();
    _fetchCoverImage();
    _fetchAdditionalPhotos();
    _fetchPrivilegeLevel();
  }

  // ==================================================
  //  Cargar privilegeLevel (para mostrar su icono)
  // ==================================================
  Future<void> _fetchPrivilegeLevel() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        final raw = data['privilegeLevel'];
        String newLevel;

        if (raw is int) {
          // Mapeamos int -> string
          switch (raw) {
            case 1:
              newLevel = "premium";
              break;
            case 2:
              newLevel = "golden";
              break;
            case 3:
              newLevel = "vip";
              break;
            default:
              newLevel = "basico";
          }
        } else {
          newLevel = (raw ?? "basico").toString().toLowerCase();
        }

        setState(() {
          _privilegeLevel = newLevel;
        });
      }
    } catch (e) {
      print("[_fetchPrivilegeLevel] Error: $e");
    }
  }

  // Función auxiliar para pasar de String a int (mismo criterio de _fetchPrivilegeLevel)
  int _mapPrivilegeStringToInt(String privilege) {
    switch (privilege.toLowerCase()) {
      case "premium":
        return 1;
      case "golden":
        return 2;
      case "vip":
        return 3;
      default:
        return 0; // "basico"
    }
  }

  // =======================================
  //   OBTENER DATOS: Perfil, Portada, etc.
  // =======================================
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
        final data = doc.data() ?? {};
        profileImageUrl = data['photoUrl'] ?? "";
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
        final data = doc.data() ?? {};
        coverImageUrl = data['coverPhotoUrl'] ?? "";
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

      final data = doc.data() ?? {};
      final photos = data['additionalPhotos'] as List<dynamic>?;
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

  // =======================================================
  //   LÓGICA PARA ASIGNAR privilegeLevel (followers-based)
  // =======================================================
  Future<void> _setUserPrivilegeLevel(int followersCount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      int newLevel;
      if (followersCount < 1000) {
        newLevel = 0; // Básico
      } else if (followersCount < 10000) {
        newLevel = 1; // Premium
      } else if (followersCount < 100000) {
        newLevel = 2; // Golden
      } else {
        newLevel = 3; // VIP
      }

      // EVITAR SOBREESCRITURA
      final currentLevelInt = _mapPrivilegeStringToInt(_privilegeLevel);
      if (newLevel != currentLevelInt) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'privilegeLevel': newLevel});

        await _fetchPrivilegeLevel();
      }
    } catch (e) {
      print('Error al actualizar privilegeLevel: $e');
    }
  }

  // =============================
  //   CAMBIAR FOTO DE PERFIL
  // =============================
  Future<void> _showAvatarSourceActionSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.2),
      builder: (context) {
        return Container(
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
        );
      },
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
      setState(() {
        profileImageUrl = imageUrl;
      });

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

  // ================================
  //   CAMBIAR FOTO DE PORTADA
  // ================================
  Future<void> _changeBackgroundImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.2),
      builder: (context) {
        return Container(
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
        );
      },
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
      setState(() {
        coverImageUrl = imageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fondo actualizado con éxito')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar el fondo: $e')),
      );
    }
  }

  // =================================================
  //   MANEJO DE FOTOS ADICIONALES
  // =================================================
  Future<void> _showImageSourceActionSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.2),
      builder: (context) {
        return Container(
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
        );
      },
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
      setState(() {
        additionalPhotos.add(imageUrl);
      });

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
      setState(() {
        profileImageUrl = imageUrl;
      });

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
      setState(() {
        additionalPhotos.remove(imageUrl);
      });

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

  // ===========================
  //   WIDGETS DE LA PANTALLA
  // ===========================
  Widget _buildCoverImage() {
    final bool hasCover = (coverImageUrl != null &&
        coverImageUrl!.isNotEmpty &&
        coverImageUrl! != placeholderImageUrl);

    return GestureDetector(
      onTap: _changeBackgroundImage,
      child: Container(
        height: 300,
        width: double.infinity,
        color: Colors.grey[300],
        child: hasCover
            ? Image.network(
                coverImageUrl!,
                fit: BoxFit.cover,
              )
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
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildAvatarPlaceholder("Cargando...");
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return _buildAvatarPlaceholder(user?.uid ?? "");
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final userName = userData?['name'] ?? 'Usuario';

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
                      backgroundImage: (profileImageUrl != null &&
                              profileImageUrl!.isNotEmpty)
                          ? NetworkImage(profileImageUrl!)
                          : NetworkImage(placeholderImageUrl),
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

  Widget _avatarCameraIcon() {
    return GestureDetector(
      onTap: _showAvatarSourceActionSheet,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.shade400,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(
          Icons.camera_alt,
          color: Colors.white,
          size: 16,
        ),
      ),
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
                  backgroundImage: NetworkImage(
                    profileImageUrl ?? placeholderImageUrl,
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

  // BOTÓN "VER PRIVILEGIOS"
  Widget _buildPrivilegeButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _showPrivilegeLevelDetailsPopup();
      },
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

  String _mapPrivilegeLevelToTitle(String level) {
    switch (level) {
      case "basico":
        return "Básico";
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

  void _showPrivilegeLevelDetailsPopup() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
                  userId: user.uid,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  //   MÉTODOS PARA BIO Y ESTADÍSTICAS
  // =========================================================
  Future<int> _getFollowersCount(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('followers')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  Future<int> _getFollowedCount(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('followed')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  Future<int> _getActivePlanCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    final snapshot = await FirebaseFirestore.instance
        .collection('plans')
        .where('createdBy', isEqualTo: user.uid)
        .get();
    return snapshot.docs.length;
  }

  /// Muestra la bio + las estadísticas (planes activos, seguidores, seguidos).
  /// Evita la llamada directa a `_setUserPrivilegeLevel` en el build.
  Widget _buildBioAndStats() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, userDocSnap) {
        if (userDocSnap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Cargando...', style: TextStyle(color: Colors.black)),
          );
        }
        if (userDocSnap.hasError ||
            !userDocSnap.hasData ||
            !userDocSnap.data!.exists) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Error al cargar', style: TextStyle(color: Colors.black)),
          );
        }

        final isOwner = (user.uid == FirebaseAuth.instance.currentUser?.uid);

        return FutureBuilder<int>(
          future: _getActivePlanCount(),
          builder: (context, snapshotPlans) {
            return FutureBuilder<int>(
              future: _getFollowersCount(user.uid),
              builder: (context, snapshotFollowers) {
                return FutureBuilder<int>(
                  future: _getFollowedCount(user.uid),
                  builder: (context, snapshotFollowed) {
                    if (snapshotPlans.connectionState == ConnectionState.waiting ||
                        snapshotFollowers.connectionState == ConnectionState.waiting ||
                        snapshotFollowed.connectionState == ConnectionState.waiting) {
                      return _buildStatsRow('...', '...', '...');
                    }

                    if (snapshotPlans.hasError ||
                        snapshotFollowers.hasError ||
                        snapshotFollowed.hasError ||
                        !snapshotPlans.hasData ||
                        !snapshotFollowers.hasData ||
                        !snapshotFollowed.hasData) {
                      return _buildStatsRow('0', '0', '0');
                    }

                    final planCount = snapshotPlans.data ?? 0;
                    final followersCount = snapshotFollowers.data ?? 0;
                    final followedCount = snapshotFollowed.data ?? 0;

                    // Actualizar privilegeLevel si eres el dueño
                    if (isOwner) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _setUserPrivilegeLevel(followersCount);
                      });
                    }

                    return _buildStatsRow(
                      planCount.toString(),
                      followersCount.toString(),
                      followedCount.toString(),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatsRow(String plans, String followers, String followed) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatItem('planes activos', plans),
            const SizedBox(width: 20),
            _buildStatItem('seguidores', followers),
            const SizedBox(width: 20),
            _buildStatItem('seguidos', followed),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String count) {
    final isPlans = label == 'planes activos';
    final isFollowers = label == 'seguidores';

    String iconPath;
    Color iconColor;
    if (isPlans) {
      iconPath = 'assets/icono-calendario.svg';
      iconColor = (count != '0' && count != '...') ? AppColors.blue : Colors.grey;
    } else {
      iconPath = 'assets/icono-seguidores.svg';
      if (isFollowers) {
        iconColor = (count != '0' && count != '...') ? AppColors.blue : Colors.grey;
      } else {
        iconColor = (count != '0' && count != '...')
            ? const Color.fromARGB(235, 84, 87, 228)
            : Colors.grey;
      }
    }

    return SizedBox(
      width: 100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color.fromARGB(255, 134, 134, 134),
            ),
          ),
        ],
      ),
    );
  }

  // VISOR DE FOTOS ADICIONALES (PageView + Dialog)
  void _openPhotoViewer(int initialIndex) {
    PageController controller = PageController(initialPage: initialIndex);
    int currentPage = initialIndex;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: controller,
                    onPageChanged: (index) {
                      setState(() {
                        currentPage = index;
                      });
                    },
                    itemCount: additionalPhotos.length,
                    itemBuilder: (context, index) {
                      final imageUrl = additionalPhotos[index];
                      return Container(
                        color: Colors.white,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              imageUrl,
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
                        final currentPhoto = additionalPhotos[currentPage];
                        if (value == 'set_as_profile') {
                          await _setAsProfilePhoto(currentPhoto);
                        } else if (value == 'delete') {
                          await _deletePhoto(currentPhoto);
                          Navigator.of(context).pop();
                        }
                      },
                      itemBuilder: (context) => [
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
                        style: const TextStyle(
                          fontSize: 32,
                          color: Colors.black,
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

  // =========================================
  //   BUILD PRINCIPAL DE LA PANTALLA
  // =========================================
  @override
  Widget build(BuildContext context) {
    // Declara la variable user ANTES de la lista de widgets
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Stack con portada y avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildCoverImage(),
                Positioned(
                  top: 40,
                  right: 16,
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        width: 40.0,
                        height: 40.0,
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
                  child: Center(
                    child: _buildUserAvatarAndName(),
                  ),
                ),
              ],
            ),

            // Espacio para el avatar
            const SizedBox(height: 70),

            // Botón "Ver Privilegios"
            _buildPrivilegeButton(context),

            // Bio + Stats
            _buildBioAndStats(),
            const SizedBox(height: 20),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 200.0,
                  child: const Divider(
                    color: Colors.grey,
                    thickness: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Calendario, solo si user != null
            if (user != null)
              MemoriesCalendar(userId: user.uid),
            const SizedBox(height: 20),

            // Botón de Cerrar sesión
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
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
