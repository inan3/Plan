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
import '../../user_data/user_info_screen.dart';

// (Opcional) Si luego quieres navegar a Followers/FollowedScreen, importarías:
// import '../follow/followers_screen.dart';
// import '../follow/followed_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String placeholderImageUrl = "https://via.placeholder.com/150";

  // Campos para avatar y portada:
  String? profileImageUrl; // Foto de perfil
  String? coverImageUrl;   // Foto de portada

  List<String> additionalPhotos = [];
  bool _isLoading = false;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchProfileImage();
    _fetchCoverImage();
    _fetchAdditionalPhotos();
  }

  //======================//
  //   OBTENER DATOS      //
  //======================//

  /// Lee la foto de perfil (photoUrl) del usuario actual.
  Future<void> _fetchProfileImage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

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

  /// Lee la foto de portada (coverPhotoUrl) del usuario actual.
  Future<void> _fetchCoverImage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

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

  /// Lee la lista de fotos adicionales (additionalPhotos) del usuario actual.
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
      setState(() {
        additionalPhotos = photos?.cast<String>() ?? [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar las fotos adicionales: $e')),
      );
    }
  }

  //=================================================//
  //   LÓGICA DE NIVEL DE PRIVILEGIO DESDE FOLLOWERS  //
  //=================================================//

  /// Dado un número de seguidores, calcula y guarda en Firestore el nivel
  /// de privilegio correspondiente: 0=basic, 1=premium, 2=diamond, 3=vip.
  Future<void> _setUserPrivilegeLevel(int followersCount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      int newLevel;
      if (followersCount < 1000) {
        newLevel = 0; // Basic
      } else if (followersCount < 10000) {
        newLevel = 1; // Premium
      } else if (followersCount < 100000) {
        newLevel = 2; // Diamond
      } else {
        newLevel = 3; // VIP
      }

      // Actualizamos el documento de usuario con el nuevo nivel
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'privilegeLevel': newLevel});
    } catch (e) {
      print('Error al actualizar privilegeLevel: $e');
    }
  }

  /// Devuelve la ruta del icono según el nivel de privilegio.
  String _getPrivilegeIconPath(int level) {
    switch (level) {
      case 1:
        return 'assets/icono-usuario-premium.png';
      case 2:
        return 'assets/icono-usuario-golden.png';
      case 3:
        return 'assets/icono-usuario-vip.png';
      default:
        return 'assets/icono-usuario-basico.png';
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

  //========================================//
  //   CAMBIAR FOTO DE PERFIL (AVATAR)      //
  //========================================//

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
                  final pickedFile =
                      await _imagePicker.pickImage(source: ImageSource.gallery);
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
                  final pickedFile =
                      await _imagePicker.pickImage(source: ImageSource.camera);
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

  /// Sube la imagen de perfil y actualiza `photoUrl` en Firestore.
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

  //=====================================//
  //   CAMBIAR FOTO DE PORTADA (COVER)   //
  //=====================================//

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
                  final pickedFile =
                      await _imagePicker.pickImage(source: ImageSource.gallery);
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
                  final pickedFile =
                      await _imagePicker.pickImage(source: ImageSource.camera);
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

  /// Sube la nueva foto de portada y actualiza `coverPhotoUrl` en Firestore.
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

  //======================================================//
  //   MANEJO DE FOTOS ADICIONALES (ADDITIONAL PHOTOS)    //
  //======================================================//

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
      final pickedFile =
          await _imagePicker.pickImage(source: ImageSource.camera);
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

  //==================================//
  //   WIDGETS DE LA PANTALLA PERFIL  //
  //==================================//

  /// Construye el contenedor de la portada con placeholder o imagen.
  Widget _buildCoverImage() {
    final bool hasCover = coverImageUrl != null &&
        coverImageUrl!.isNotEmpty &&
        coverImageUrl! != placeholderImageUrl;

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

  /// Construye el avatar (foto de perfil) y el nombre, usando datos de Firestore.
  Widget _buildUserAvatarAndName() {
    final user = FirebaseAuth.instance.currentUser;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildAvatarPlaceholder("Cargando...");
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return _buildAvatarPlaceholder(user?.uid ?? "");
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final userName = userData?['name'] ?? 'Usuario';
        final int privilegeLevel = userData?['privilegeLevel'] ?? 0;

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
                              profileImageUrl!.isNotEmpty &&
                              profileImageUrl != placeholderImageUrl)
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
            const SizedBox(height: 8),
            _buildPrivilegeIcon(privilegeLevel),
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
                  backgroundImage: NetworkImage(profileImageUrl ?? placeholderImageUrl),
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

  /// Devuelve cuántos usuarios siguen al actual (followers).
  Future<int> _getFollowersCount(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('followers')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  /// Devuelve cuántos usuarios sigue el actual (followed).
  Future<int> _getFollowedCount(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('followed')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  /// Devuelve la cantidad de planes activos del usuario.
  Future<int> _getActivePlanCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    final snapshot = await FirebaseFirestore.instance
        .collection('plans')
        .where('createdBy', isEqualTo: user.uid)
        .get();
    return snapshot.docs.length;
  }

  /// Sección con la Bio y las estadísticas (planes activos, seguidores, seguidos).
  Widget _buildBioAndStats() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, userDocSnap) {
        if (userDocSnap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Cargando...', style: TextStyle(color: Colors.black)),
          );
        }
        if (userDocSnap.hasError || !userDocSnap.hasData || !userDocSnap.data!.exists) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Error al cargar', style: TextStyle(color: Colors.black)),
          );
        }

        final userData = userDocSnap.data!.data() as Map<String, dynamic>;
        final bio = userData['bio'] ?? 'Esta es mi bio. ¡Bienvenido a mi perfil!';
        // Verificamos si es el dueño para recalcular su nivel
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
                    // Si cualquiera está cargando, mostramos "..."
                    if (snapshotPlans.connectionState == ConnectionState.waiting ||
                        snapshotFollowers.connectionState == ConnectionState.waiting ||
                        snapshotFollowed.connectionState == ConnectionState.waiting) {
                      return _buildStatsRow('...', '...', '...');
                    }

                    // Si error o no hay data:
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

                    // Si es el propietario, recalculamos privilegeLevel
                    if (isOwner) {
                      _setUserPrivilegeLevel(followersCount);
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

  /// Construye la fila con (planes activos, seguidores, seguidos)
  Widget _buildStatsRow(String plans, String followers, String followed) {
    return Column(
      children: [
        const SizedBox(height: 30),
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

  /// Helper genérico para mostrar un stat con su icono.
  Widget _buildStatItem(String label, String count) {
    final isPlans = label == 'planes activos';
    final isFollowers = label == 'seguidores';
    final isFollowed = label == 'seguidos';

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

  /// Abre visor de fotos (PageView) para las imágenes de la galería personal.
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
                        style: const TextStyle(fontSize: 32, color: Colors.black),
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

  //===================================//
  //   CONSTRUCCIÓN DE LA INTERFAZ     //
  //===================================//

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Imagen de portada
                _buildCoverImage(),
                // Ícono en la esquina superior derecha para cambiar la portada
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
                // Avatar e información del usuario
                Positioned(
                  bottom: -100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _buildUserAvatarAndName(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 90), // Espacio para el avatar solapado

            // Bio + Stats
            _buildBioAndStats(),
            const SizedBox(height: 20),

            // Línea separadora de menor longitud
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: Container(
                  width: 200.0,
                  child: const Divider(
                    color: Colors.grey,
                    thickness: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Tu información
            ListTile(
              leading: const Icon(Icons.info, color: Colors.black),
              title: const Text(
                'Tu información',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black),
              onTap: () async {
                final isUpdated = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserInfoScreen()),
                );
                if (isUpdated == true) {
                  // Si se actualizó, recargamos
                  setState(() {
                    _fetchProfileImage();
                    _fetchCoverImage();
                  });
                }
              },
            ),
            const SizedBox(height: 10),

            // Cerrar sesión
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
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
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
