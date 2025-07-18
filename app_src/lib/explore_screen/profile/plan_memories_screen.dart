import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'user_images_managing.dart';
import '../../l10n/app_localizations.dart';

import '../plans_managing/plan_card.dart';
import '../../models/plan_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../users_grid/users_grid_helpers.dart';

// Importa nuestra hoja de compartir imágenes (análogo a tu PlanShareSheet)
import 'image_share_sheet.dart';

class PlanMemoriesScreen extends StatefulWidget {
  final PlanModel plan;

  /// Función que obtendrá los participantes de un plan, leyendo el array `participants`
  /// del doc en 'plans'. Se pasa al PlanCard para mostrar avatares, etc.
  final Future<List<Map<String, dynamic>>> Function(PlanModel plan)
      fetchParticipants;

  const PlanMemoriesScreen({
    Key? key,
    required this.plan,
    required this.fetchParticipants,
  }) : super(key: key);

  @override
  _PlanMemoriesScreenState createState() => _PlanMemoriesScreenState();
}

class _PlanMemoriesScreenState extends State<PlanMemoriesScreen> {
  bool _isLoading = false;
  final ImagePicker _imagePicker = ImagePicker();

  /// Controlador del scroll
  final ScrollController _scrollController = ScrollController();

  /// Lista de URLs de las fotos (memorias) guardadas en Firestore
  List<String> _memories = [];

  @override
  void initState() {
    super.initState();
    _loadMemoriesFromPlan();
  }

  // --------------------------------------------------
  //   Cargar las memorias existentes del plan
  // --------------------------------------------------
  Future<void> _loadMemoriesFromPlan() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(widget.plan.id)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final List<dynamic>? memList = data['memories'] as List<dynamic>?;
        if (memList != null) {
          setState(() {
            _memories = memList.map((e) => e.toString()).toList();
          });
        }
      }
    } catch (e) {
    }
  }

  // --------------------------------------------------
  //   Bottom sheet para añadir fotos
  // --------------------------------------------------
  Future<void> _showImageSourceActionSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.2),
      builder: (context) {
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
                      await _pickMultipleImages();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: Colors.blue),
                    title: Text(t.takePhoto),
                    onTap: () async {
                      Navigator.pop(context);
                      await _takePhoto();
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

  /// Seleccionar varias imágenes (galería)
  Future<void> _pickMultipleImages() async {
    if (_memories.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo puedes subir 3 fotos.')),
      );
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final remaining = 3 - _memories.length;
        setState(() => _isLoading = true);
        int count = 0;
        for (var file in result.files) {
          if (file.path != null) {
            await _uploadMemory(File(file.path!));
            count++;
            if (count >= remaining) break;
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

  /// Tomar foto con la cámara
  Future<void> _takePhoto() async {
    if (_memories.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo puedes subir 3 fotos.')),
      );
      return;
    }
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      if (pickedFile != null) {
        setState(() => _isLoading = true);
        await _uploadMemory(File(pickedFile.path));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al tomar la foto: $e')),
      );
    }
  }

  /// Subir la imagen al Storage y guardar su URL en Firestore
  Future<void> _uploadMemory(File file) async {
    try {
      if (await UserImagesManaging.checkExplicit(file)) {
        await UserImagesManaging.showExplicitDialog(context);
        return;
      }
      final ref = FirebaseStorage.instance
          .ref()
          .child('plan_memories')
          .child('${widget.plan.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await ref.putFile(file);
      final imageUrl = await ref.getDownloadURL();

      _memories.add(imageUrl);

      await FirebaseFirestore.instance
          .collection('plans')
          .doc(widget.plan.id)
          .update({'memories': _memories});

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la imagen: $e')),
      );
    }
  }

  /// Eliminar una imagen (Storage + Firestore)
  Future<void> _deleteMemory(String imageUrl) async {
    try {
      // 1) Eliminar del Storage
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar de Storage: $e')),
      );
    }

    // 2) Eliminar de la lista local
    setState(() {
      _memories.remove(imageUrl);
    });

    // 3) Actualizar en Firestore
    try {
      await FirebaseFirestore.instance
          .collection('plans')
          .doc(widget.plan.id)
          .update({'memories': _memories});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar Firestore: $e')),
      );
    }
  }

  /// Abrir visor de foto a pantalla completa
  void _openPhotoViewer(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(
          imageUrl: _memories[index],
          onDelete: (url) async {
            // Llamamos la lógica de eliminar en el padre
            await _deleteMemory(url);
            Navigator.of(context).pop(); // Cierra el visor
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(t.planAndMemories),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showImageSourceActionSheet,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        icon: const Icon(Icons.camera_alt),
        label: Text(t.add),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.plan.createdBy)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                !snapshot.data!.exists) {
              // Fallback si hay error o doc no existe
              return Column(
                children: [
                  PlanCard(
                    plan: widget.plan,
                    userData: {
                      'name': 'Usuario',
                      'handle': '@desconocido',
                      'photoUrl': '',
                    },
                    fetchParticipants: widget.fetchParticipants,
                    hideJoinButton: true,
                  ),
                  const SizedBox(height: 16),
                  _buildMemoriesSection(),
                  _buildMemoriesGrid(),
                ],
              );
            }

            // Datos reales del creador
            final creatorData = snapshot.data!.data() as Map<String, dynamic>;
            final name = creatorData['name']?.toString() ?? 'Usuario';
            final handle = creatorData['handle']?.toString() ?? '@usuario';
            final photoUrl = creatorData['photoUrl']?.toString() ?? '';

            return Column(
              children: [
                PlanCard(
                  plan: widget.plan,
                  userData: {
                    'name': name,
                    'handle': handle,
                    'photoUrl': photoUrl,
                  },
                  fetchParticipants: widget.fetchParticipants,
                  hideJoinButton: true,
                ),
                const SizedBox(height: 16),
                _buildMemoriesSection(),
                _buildMemoriesGrid(),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Cabecera "Memorias" centrada
  Widget _buildMemoriesSection() {
    final t = AppLocalizations.of(context);
    return Column(
      children: [
        const SizedBox(height: 12),
        Center(
          child: Text(
            t.memories,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(thickness: 1),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Cuadrícula de imágenes (sin selección múltiple)
  Widget _buildMemoriesGrid() {
    final t = AppLocalizations.of(context);
    if (_memories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          t.addPhotosToRememberPlan,
          style: const TextStyle(color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: _memories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // 3 columnas
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemBuilder: (context, index) {
          final imageUrl = _memories[index];
          return GestureDetector(
            onTap: () => _openPhotoViewer(index),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (_, __, ___) => buildPlaceholder(),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Visor de imagen a pantalla completa con botón de 3 puntos
// ---------------------------------------------------------------------
class _FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final Function(String) onDelete;

  const _FullScreenImageViewer({
    Key? key,
    required this.imageUrl,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showOptionsDialog,
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (_, __, ___) => const Icon(Icons.error),
          ),
        ),
      ),
    );
  }

  /// Dialog con opciones "Compartir" y "Eliminar"
  void _showOptionsDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return SimpleDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          children: [
            // --- Compartir ---
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context); // cierra el diálogo
                _openImageShareSheet(widget.imageUrl);
              },
              child: Row(
                children: [
                  SvgPicture.asset('assets/icono-compartir.svg',
                      width: 24, height: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Compartir',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            // --- Eliminar ---
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context); // cierra el diálogo
                widget.onDelete(widget.imageUrl);
              },
              child: Row(
                children: [
                  SvgPicture.asset('assets/icono-eliminar.svg',
                      width: 24, height: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Eliminar',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Abre un BottomSheet con la misma lógica de compartir que PlanShareSheet,
  /// pero adaptado a imágenes (ImageShareSheet)
  void _openImageShareSheet(String imageUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (BuildContext context, ScrollController scrollController) {
            return ImageShareSheet(
              imageUrl: imageUrl,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }
}
