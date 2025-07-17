// lib/explore_screen/profile/user_images_managing.dart

import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../users_grid/users_grid_helpers.dart';
import '../../l10n/app_localizations.dart';

class UserImagesManaging {
  static final ImagePicker _imagePicker = ImagePicker();
  static const placeholderImageUrl = 'assets/usuario.svg';

  static Future<bool> checkExplicit(File image) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final bytes = await image.readAsBytes();
      final result = await functions
          .httpsCallable('detectExplicitContent')
          .call({'image': base64Encode(bytes)});
      return result.data['explicit'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> showExplicitDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text(
            'Esta imagen de contenido explícito incumple la Norma sobre Contenido Sexual. Visita: Condiciones de uso'),
        actions: [
          TextButton(
            onPressed: () {
              launchUrl(
                Uri.parse(
                    'https://plansocialapp.es/terms_and_conditions.html'),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('Condiciones de uso'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // ---------------
  // Foto de perfil
  // ---------------
  static Future<String?> fetchProfileImage(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return doc.data()?['photoUrl'] ?? "";
    } catch (e) {
      return null;
    }
  }

  // Cambiar (subir) nueva imagen de perfil
  static Future<void> changeProfileImage(
    BuildContext context, {
    required Function(String) onProfileUpdated,
    required Function(bool) onLoading,
  }) async {
    // Hoja con opciones: galería o cámara
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.2),
      builder: (_) {
        final t = AppLocalizations.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library, color: Colors.blue),
                    title: Text(t.pickFromGallery),
                    onTap: () async {
                      Navigator.pop(context);
                      final pickedFile =
                          await _imagePicker.pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        onLoading(true);
                        await _uploadAvatarImage(
                          context,
                          File(pickedFile.path),
                          onProfileUpdated: onProfileUpdated,
                        );
                        onLoading(false);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: Colors.blue),
                    title: Text(t.takePhoto),
                    onTap: () async {
                      Navigator.pop(context);
                      final pickedFile =
                          await _imagePicker.pickImage(source: ImageSource.camera);
                      if (pickedFile != null) {
                        onLoading(true);
                        await _uploadAvatarImage(
                          context,
                          File(pickedFile.path),
                          onProfileUpdated: onProfileUpdated,
                        );
                        onLoading(false);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Sube al storage la foto de perfil y actualiza Firestore
  static Future<void> _uploadAvatarImage(
    BuildContext context,
    File image, {
    required Function(String) onProfileUpdated,
  }) async {
    try {
      if (await checkExplicit(image)) {
        await showExplicitDialog(context);
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final ref = FirebaseStorage.instance
          .ref()
          .child('avatar_photos')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(image);
      final imageUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'photoUrl': imageUrl});

      onProfileUpdated(imageUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la imagen: $e')),
      );
    }
  }

  // Abre la foto de perfil a pantalla completa
  static void openProfileImageFullScreen(
    BuildContext context,
    String imageUrl, {
    required Function() onProfileDeleted,
    required Function(String) onProfileChanged,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImagePage(
          initialIndex: 0,
          images: [imageUrl],
          titleAppBar: AppLocalizations.of(context).yourProfilePhoto,
          isProfile: true,
          onProfileDeleted: onProfileDeleted,
          onProfileChanged: onProfileChanged,
        ),
      ),
    );
  }

  // ---------------
  // Fotos de portada (múltiples)
  // ---------------
  static Future<List<String>> fetchCoverImages(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final covers = doc.data()?['coverPhotos'] as List<dynamic>?;
      return (covers != null) ? List<String>.from(covers) : [];
    } catch (e) {
      return [];
    }
  }

  // Agrega una nueva imagen de portada (hasta 5)
  static Future<void> addNewCoverImage(
    BuildContext context,
    List<String> currentCoverImages, {
    required Function(List<String>) onImagesUpdated,
    required Function(bool) onLoading,
  }) async {
    if (currentCoverImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por ahora puedes subir solo 5 imágenes."),
        ),
      );
      return;
    }
    // Hoja con opciones: galería o cámara
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.2),
      builder: (_) {
        final t = AppLocalizations.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library, color: Colors.blue),
                    title: Text(t.pickFromGallery),
                    onTap: () async {
                      Navigator.pop(context);
                      final pickedFile =
                          await _imagePicker.pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        onLoading(true);
                        await _uploadCoverImage(
                          context,
                          File(pickedFile.path),
                          currentCoverImages,
                          onImagesUpdated: onImagesUpdated,
                        );
                        onLoading(false);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: Colors.blue),
                    title: Text(t.takePhoto),
                    onTap: () async {
                      Navigator.pop(context);
                      final pickedFile =
                          await _imagePicker.pickImage(source: ImageSource.camera);
                      if (pickedFile != null) {
                        onLoading(true);
                        await _uploadCoverImage(
                          context,
                          File(pickedFile.path),
                          currentCoverImages,
                          onImagesUpdated: onImagesUpdated,
                        );
                        onLoading(false);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> _uploadCoverImage(
    BuildContext context,
    File image,
    List<String> currentCoverImages, {
    required Function(List<String>) onImagesUpdated,
  }) async {
    try {
      if (await checkExplicit(image)) {
        await showExplicitDialog(context);
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ref = FirebaseStorage.instance
          .ref()
          .child('cover_photos')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(image);
      final imageUrl = await ref.getDownloadURL();

      final updatedList = List<String>.from(currentCoverImages);
      updatedList.add(imageUrl);

      final Map<String, dynamic> updateData = {'coverPhotos': updatedList};
      if (updatedList.length == 1) {
        updateData['coverPhotoUrl'] = updatedList.first;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updateData);

      onImagesUpdated(updatedList);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen de fondo subida con éxito')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar el fondo: $e')),
      );
    }
  }

  // Abre las imágenes de portada a pantalla completa
  static void openCoverImagesFullScreen(
    BuildContext context,
    List<String> coverImages,
    int initialIndex, {
    required Function(List<String>) onImagesUpdated,
    required Function(String) onProfileUpdated,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImagePage(
          initialIndex: initialIndex,
          images: coverImages,
          titleAppBar: AppLocalizations.of(context).photoCollection,
          isProfile: false,
          onCoverImagesUpdated: onImagesUpdated,
          onProfileChanged: onProfileUpdated,
        ),
      ),
    );
  }

  // ---------------
  // Fotos adicionales
  // ---------------
  static Future<List<String>> fetchAdditionalPhotos(
      BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final photos = doc.data()?['additionalPhotos'] as List<dynamic>?;
      return (photos != null) ? List<String>.from(photos) : [];
    } catch (e) {
      return [];
    }
  }

  // (Lo puedes usar donde tú quieras para añadir fotos extras.)
  static Future<void> showAdditionalPhotosSheet(
    BuildContext context, {
    required Function(List<String>) onNewPhotoUrls,
    required List<String> currentPhotos,
    required Function(bool) onLoading,
  }) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.2),
      builder: (_) {
        final t = AppLocalizations.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library, color: Colors.blue),
                    title: Text(t.pickFromGallery),
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        allowMultiple: true,
                      );
                      if (result != null) {
                        onLoading(true);
                        for (var file in result.files) {
                          if (file.path != null) {
                            await _uploadAdditionalImage(
                              context,
                              File(file.path!),
                              currentPhotos,
                              onNewPhotoUrls: onNewPhotoUrls,
                            );
                          }
                        }
                        onLoading(false);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: Colors.blue),
                    title: Text(t.takePhoto),
                    onTap: () async {
                      Navigator.pop(context);
                      final pickedFile = await _imagePicker.pickImage(source: ImageSource.camera);
                      if (pickedFile != null) {
                        onLoading(true);
                        await _uploadAdditionalImage(
                          context,
                          File(pickedFile.path),
                          currentPhotos,
                          onNewPhotoUrls: onNewPhotoUrls,
                        );
                        onLoading(false);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> _uploadAdditionalImage(
    BuildContext context,
    File image,
    List<String> currentPhotos, {
    required Function(List<String>) onNewPhotoUrls,
  }) async {
    try {
      if (await checkExplicit(image)) {
        await showExplicitDialog(context);
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ref = FirebaseStorage.instance
          .ref()
          .child('user_photos')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(image);
      final imageUrl = await ref.getDownloadURL();

      final updatedList = List<String>.from(currentPhotos);
      updatedList.add(imageUrl);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'additionalPhotos': updatedList});

      onNewPhotoUrls(updatedList);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la imagen: $e')),
      );
    }
  }

  static void openAdditionalPhotosFullScreen(
    BuildContext context,
    List<String> photos,
    int initialIndex, {
    required Function(List<String>) onNewList,
    required Function(String) onProfileUpdated,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImagePage(
          images: photos,
          initialIndex: initialIndex,
          titleAppBar: AppLocalizations.of(context).photoCollection,
          isAdditional: true,
          onAdditionalUpdated: onNewList,
          onProfileChanged: onProfileUpdated,
        ),
      ),
    );
  }
}

// ---------------
// Pantalla completa con PageView + AppBar
// ---------------
class _FullScreenImagePage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String titleAppBar;

  // Para distinguir:
  final bool isProfile;
  final bool isAdditional;

  final Function(List<String>)? onCoverImagesUpdated;
  final Function(List<String>)? onAdditionalUpdated;
  final Function(String)? onProfileChanged;
  final Function()? onProfileDeleted;

  const _FullScreenImagePage({
    Key? key,
    required this.images,
    required this.initialIndex,
    required this.titleAppBar,
    this.isProfile = false,
    this.isAdditional = false,
    this.onCoverImagesUpdated,
    this.onAdditionalUpdated,
    this.onProfileChanged,
    this.onProfileDeleted,
  }) : super(key: key);

  @override
  State<_FullScreenImagePage> createState() => _FullScreenImagePageState();
}

class _FullScreenImagePageState extends State<_FullScreenImagePage> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  Future<void> _deleteCurrentImage() async {
    final url = widget.images[_currentPage];
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
    } catch (_) {}

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (widget.isProfile) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'photoUrl': ''});
      widget.onProfileDeleted?.call();
      Navigator.of(context).pop();
      return;
    }

    if (!widget.isProfile && !widget.isAdditional) {
      // Portada
      final updatedList = List<String>.from(widget.images);
      updatedList.removeAt(_currentPage);
      final Map<String, dynamic> updateData = {'coverPhotos': updatedList};
      if (updatedList.length <= 1) {
        updateData['coverPhotoUrl'] =
            updatedList.isNotEmpty ? updatedList.first : '';
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updateData);
      widget.onCoverImagesUpdated?.call(updatedList);

      if (updatedList.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _currentPage = (_currentPage >= updatedList.length)
            ? updatedList.length - 1
            : _currentPage;
      });
    }

    if (widget.isAdditional) {
      // Fotos adicionales
      final updatedList = List<String>.from(widget.images);
      updatedList.removeAt(_currentPage);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'additionalPhotos': updatedList});
      widget.onAdditionalUpdated?.call(updatedList);

      if (updatedList.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _currentPage = (_currentPage >= updatedList.length)
            ? updatedList.length - 1
            : _currentPage;
      });
    }
  }

  Future<void> _setAsProfile() async {
    final url = widget.images[_currentPage];
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'photoUrl': url});
    widget.onProfileChanged?.call(url);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto de perfil actualizada')),
    );
  }

  Future<void> _setAsCoverBackground() async {
    final url = widget.images[_currentPage];
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1‑ Actualizamos el campo específico de “fondo”
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'coverPhotoUrl': url});

    // 2‑ Reordenamos la lista: quitamos la imagen y la insertamos en la posición 0
    final List<String> updatedList = List<String>.from(widget.images);
    updatedList.remove(url);
    updatedList.insert(0, url);

    // 3‑ Persistimos el nuevo orden en Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'coverPhotos': updatedList});

    // 4‑ Informamos al widget padre para que refresque la UI
    widget.onCoverImagesUpdated?.call(updatedList);

    // 5‑ Nos colocamos en la primera página para que el usuario la vea ya en primer lugar
    setState(() => _currentPage = 0);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Imagen establecida como fondo.')),
    );
  }

  void _showOptionsPopup() {
    if (widget.isProfile) {
      _showProfileImageOptions();
    } else if (!widget.isProfile && !widget.isAdditional) {
      _showCoverImageOptions();
    } else {
      _showAdditionalOptions();
    }
  }

  void _showProfileImageOptions() {
    showDialog(
      context: context,
      builder: (ctx) {
        return _FrostedPopup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: SvgPicture.asset('assets/usuario.svg',
                    width: 24, height: 24),
                title: Text(AppLocalizations.of(context).changeProfileImage),
                onTap: () async {
                  Navigator.pop(ctx);
                  await UserImagesManaging.changeProfileImage(
                    context,
                    onProfileUpdated: (newUrl) {
                      widget.onProfileChanged?.call(newUrl);
                      Navigator.pop(context); // cierra full screen
                    },
                    onLoading: (_) {},
                  );
                },
              ),
              const Divider(height: 1, color: Colors.grey),
              ListTile(
                leading: SvgPicture.asset('assets/icono-eliminar.svg',
                    width: 24, height: 24),
                title: Text(AppLocalizations.of(context).deleteProfileImage),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _deleteCurrentImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCoverImageOptions() {
    showDialog(
      context: context,
      builder: (ctx) {
        return _FrostedPopup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: SvgPicture.asset('assets/icono-fondo.svg',
                    width: 24, height: 24),
                title: Text(AppLocalizations.of(context).setAsBackground),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _setAsCoverBackground();
                },
              ),
              const Divider(height: 1, color: Colors.grey),
              ListTile(
                leading: SvgPicture.asset('assets/usuario.svg',
                    width: 24, height: 24),
                title: Text(AppLocalizations.of(context).setAsProfileImage),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _setAsProfile();
                },
              ),
              const Divider(height: 1, color: Colors.grey),
              ListTile(
                leading: SvgPicture.asset('assets/icono-eliminar.svg',
                    width: 24, height: 24),
                title: Text(AppLocalizations.of(context).delete),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _deleteCurrentImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAdditionalOptions() {
    showDialog(
      context: context,
      builder: (ctx) {
        return _FrostedPopup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: SvgPicture.asset('assets/usuario.svg',
                    width: 24, height: 24),
                title: Text(AppLocalizations.of(context).setAsProfilePhoto),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _setAsProfile();
                },
              ),
              const Divider(height: 1, color: Colors.grey),
              ListTile(
                leading: SvgPicture.asset('assets/icono-eliminar.svg',
                    width: 24, height: 24),
                title: Text(AppLocalizations.of(context).delete),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _deleteCurrentImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titleAppBar),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: images.length,
            itemBuilder: (_, i) {
              return SingleChildScrollView(
                child: Center(
                  child: Container(
                    color: Colors.white,
                    child: InteractiveViewer(
                      child: CachedNetworkImage(
                        imageUrl: images[i],
                        fit: BoxFit.contain,
                        placeholder: (_, __) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, __, ___) => const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: _showOptionsPopup,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.more_vert,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (idx) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          (_currentPage == idx) ? Colors.black : Colors.black26,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Popup con fondo borroso (frosted)
class _FrostedPopup extends StatelessWidget {
  final Widget child;
  const _FrostedPopup({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Fondo borroso
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.black54),
              ),
            ),
            // Cuadro de opciones
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              left: 24,
              right: 24,
              child: GestureDetector(
                onTap: () {},
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
