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

  /// Lee la foto de perfil (photoUrl) del usuario.
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

  /// Lee la foto de portada (coverPhotoUrl) del usuario.
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

  /// Lee la lista de fotos adicionales (additionalPhotos).
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

  //========================================//
  //   CAMBIAR FOTO DE PERFIL (AVATAR)      //
  //========================================//

  /// Abre un modal para escoger la fuente de la nueva foto de perfil.
  Future<void> _showAvatarSourceActionSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.2),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: Colors.blue),
                title: Text('Seleccionar de la galería'),
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
                leading: Icon(Icons.camera_alt, color: Colors.blue),
                title: Text('Tomar una foto'),
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

      // Actualizamos el state y la base de datos
      setState(() {
        profileImageUrl = imageUrl;
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'photoUrl': imageUrl});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foto de perfil actualizada')),
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

  /// Muestra un modal para escoger la fuente de la nueva foto de portada.
  Future<void> _changeBackgroundImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.2),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: Colors.blue),
                title: Text('Seleccionar de la galería'),
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
                leading: Icon(Icons.camera_alt, color: Colors.blue),
                title: Text('Tomar una foto'),
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
        SnackBar(content: Text('Fondo actualizado con éxito')),
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

  /// Muestra un modal para escoger varias imágenes desde galería o cámara.
  Future<void> _showImageSourceActionSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.2),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: Colors.blue),
                title: Text('Seleccionar imágenes'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMultipleImages();
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.blue),
                title: Text('Tomar una foto'),
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

  /// Establece una foto dentro de `additionalPhotos` como avatar principal.
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
        SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar la foto de perfil: $e')),
      );
    }
  }

  /// Elimina una foto de `additionalPhotos` y la borra de Firebase Storage.
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
        SnackBar(content: Text('Imagen eliminada')),
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
      onTap: _changeBackgroundImage, // Al tocar, cambiamos la portada
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
                  children: [
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
          // Cargando...
          return _buildAvatarPlaceholder("Cargando...");
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          // Error o no hay datos
          return _buildAvatarPlaceholder(user?.uid ?? "");
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final userName = userData?['name'] ?? 'Usuario';

        return Column(
          children: [
            // Stack para avatar + ícono cámara
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Avatar en sí
                GestureDetector(
                  onTap: _showAvatarSourceActionSheet, // <-- Al tocar el avatar
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

                // Ícono de cámara en la esquina inferior derecha
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: _avatarCameraIcon(),
                ),
              ],
            ),

            // Espacio debajo
            const SizedBox(height: 8),

            // Nombre e ícono verificado
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
                const Icon(
                  Icons.verified,
                  color: Colors.blue,
                  size: 20,
                ),
              ],
            ),

            // UID debajo
            const SizedBox(height: 4),
            Text(
              user?.uid ?? '',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Muestra un avatar de carga o error con el texto provisto.
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

  /// Pequeño ícono de cámara para cambiar el avatar.
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

  Future<void> _showEditBioDialog(String currentBio) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    TextEditingController bioController =
        TextEditingController(text: currentBio);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Bio'),
          content: TextField(
            controller: bioController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Escribe tu nueva bio aquí',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                String newBio = bioController.text.trim();
                if (newBio.isNotEmpty) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'bio': newBio});
                    setState(() {});
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Bio actualizada con éxito')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error al actualizar la bio: $e')),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  /// Método para obtener el número real de planes activos del usuario.
  Future<int> _getActivePlanCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    final snapshot = await FirebaseFirestore.instance
        .collection('plans')
        .where('createdBy', isEqualTo: user.uid)
        .get();
    return snapshot.docs.length;
  }

  Widget _buildBioAndStats() {
  final user = FirebaseAuth.instance.currentUser;
  return FutureBuilder<DocumentSnapshot>(
    future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Cargando...',
            style: TextStyle(color: Colors.black),
          ),
        );
      }
      if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Error al cargar',
            style: TextStyle(color: Colors.black),
          ),
        );
      }
      final userData = snapshot.data?.data() as Map<String, dynamic>?;
      final bio = userData?['bio'] ?? 'Esta es mi bio. ¡Bienvenido a mi perfil!';
      final isOwner = user?.uid == FirebaseAuth.instance.currentUser?.uid;

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20.0, bottom: 10.0, left: 16.0, right: 16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 10.0,
                  sigmaY: 10.0,
                ),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        const Color.fromARGB(255, 116, 101, 150).withOpacity(0.6),
                        const Color.fromARGB(255, 0, 0, 0).withOpacity(0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Descríbete brevemente...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                          if (isOwner)
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                size: 20,
                                color: Color.fromARGB(255, 255, 255, 255),
                              ),
                              onPressed: () => _showEditBioDialog(bio),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        bio,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(255, 255, 255, 255),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActivePlanStat(),
              const SizedBox(width: 20),
              _buildStatItem('seguidores', '200'), // Valor estático
              const SizedBox(width: 20),
              _buildStatItem('seguidos', '150'), // Valor estático
            ],
          ),
        ],
      );
    },
  );
}

Widget _buildStatItem(String label, String count) {
  // Dividimos el label en partes si contiene un espacio
  List<String> labelParts = label.split(' ');
  String firstPart = labelParts[0]; // "planes", "seguidores", "seguidos"
  String secondPart = labelParts.length > 1 ? labelParts[1] : ''; // "activos"

  // Convertimos el count a entero para las condiciones de color
  int countValue = int.tryParse(count) ?? 0;

  // Determinar qué icono usar y su color
  String iconPath;
  Color iconColor;

  if (label == 'planes activos') {
    iconPath = 'assets/icono-calendario.svg';
    iconColor = countValue > 0 ? AppColors.blue : Colors.grey; // AppColors.blue o gris
  } else {
    iconPath = 'assets/icono-seguidores.svg';
    if (label == 'seguidores') {
      iconColor = countValue > 0 ? AppColors.blue : Colors.grey; // AppColors.blue o gris
    } else {
      iconColor = countValue > 0 ? const Color.fromARGB(235, 84, 87, 228) : Colors.grey; // Lila o gris
    }
  }

  return SizedBox(
    width: 100, // Ancho suficiente para el texto en una línea
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(
          iconPath,
          width: 24, // Tamaño del icono
          height: 24,
          color: iconColor, // Usamos 'color' en lugar de 'colorFilter'
        ),
        const SizedBox(height: 4), // Espacio entre el icono y el número
        Text(
          count,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4), // Espacio entre el número y el texto
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              firstPart,
              style: const TextStyle(
                fontSize: 12,
                color: Color.fromARGB(255, 134, 134, 134),
              ),
            ),
            if (secondPart.isNotEmpty) ...[
              const SizedBox(width: 2), // Espacio entre "planes" y "activos"
              Text(
                secondPart,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color.fromARGB(255, 134, 134, 134),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

Widget _buildActivePlanStat() {
  return FutureBuilder<int>(
    future: _getActivePlanCount(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildStatItem('planes activos', '...');
      }
      if (snapshot.hasError) {
        return _buildStatItem('planes activos', '0');
      }
      final count = snapshot.data ?? 0;
      return _buildStatItem('planes activos', count.toString());
    },
  );
}
  /// Abre visor de fotos para las imágenes de la galería personal.
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
                        style:
                            const TextStyle(fontSize: 32, color: Colors.black),
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
                    filter: ImageFilter.blur(
                      sigmaX: 10.0,
                      sigmaY: 10.0,
                    ),
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
                bottom: -100, // Ajustamos para que el avatar se superponga
                left: 0,
                right: 0,
                child: Center(
                  child: _buildUserAvatarAndName(),
                ),
              ),
            ],
          ),
          // Espacio para que quepa el avatar solapado
          const SizedBox(height: 90), // Ajustado para coincidir con el bottom del avatar

          // Bio y estadísticas
          _buildBioAndStats(),
          const SizedBox(height: 20),

          // Línea separadora de menor longitud
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Container(
                width: 200.0, // Ancho reducido de la línea separadora
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
            trailing: const Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.black),
            onTap: () async {
              final isUpdated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserInfoScreen()),
              );
              if (isUpdated == true) {
                // Si se actualizó, recargamos datos
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

          const SizedBox(height: 100), // Más espacio al final para permitir desplazamiento
        ],
      ),
    ),
  );
}
}
