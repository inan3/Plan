// lib/start/registration/user_registration_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';

// Importa tus colores de main/colors.dart con ALIAS para evitar colisión
import 'package:dating_app/main/colors.dart' as MyColors;

// Importa la pantalla a la que navegarás al final
import 'package:dating_app/explore_screen/main_screen/explore_screen.dart';

// Importamos la enum desde el archivo único
import 'verification_provider.dart';

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({
    Key? key,
    // Credenciales para email/password
    this.email,
    this.password,
    // Credenciales para Google
    this.googleAccessToken,
    this.googleIdToken,
    // De dónde vino
    required this.provider,
  }) : super(key: key);

  final String? email;
  final String? password;
  final String? googleAccessToken;
  final String? googleIdToken;
  final VerificationProvider provider;

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();

  // Edad (slider)
  double _age = 25;

  // Fotos de portada (coverPhotos)
  final List<File> _coverImages = [];
  late PageController _coverPageController;
  int _currentCoverIndex = 0;

  // Foto de perfil
  File? _profileImage;

  // Switch ubicación
  bool _locationEnabled = false;

  // Para mostrar spinner al guardar
  bool _isSaving = false;

  // Color para contenedores con efecto frosted glass grisáceo
  final Color _frostedGray = Colors.grey.withOpacity(0.2);

  @override
  void initState() {
    super.initState();
    _coverPageController = PageController();
  }

  @override
  void dispose() {
    _coverPageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Subir un archivo a Firebase Storage, retorna la URL
  Future<String?> _uploadFileToFirebase(File file, String fileName) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (error) {
      debugPrint('Error al subir archivo: $error');
      return null;
    }
  }

  /// Popup para elegir cámara o galería
  void _showImagePickerPopup({
    required bool isForProfilePhoto,
    required bool isForCover,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierLabel: "Seleccionar imagen",
      pageBuilder: (context, _, __) {
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _frostedGray,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                  // Borde gris iluminado
                  border: Border.all(color: Colors.grey, width: 2),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "¿Qué deseas subir?",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _pickImage(
                            fromCamera: false,
                            isForProfilePhoto: isForProfilePhoto,
                            isForCover: isForCover,
                          );
                        },
                        child: const Text(
                          "Imagen (galería)",
                          style: TextStyle(
                            color: Colors.black,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _pickImage(
                            fromCamera: true,
                            isForProfilePhoto: isForProfilePhoto,
                            isForCover: isForCover,
                          );
                        },
                        child: const Text(
                          "Imagen (cámara)",
                          style: TextStyle(
                            color: Colors.black,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Elegir imagen con ImagePicker
  Future<void> _pickImage({
    required bool fromCamera,
    required bool isForProfilePhoto,
    required bool isForCover,
  }) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() {
        if (isForProfilePhoto) {
          _profileImage = file;
        } else if (isForCover) {
          if (_coverImages.length >= 5) {
            _showErrorPopup("Máximo 5 imágenes de portada.");
            return;
          }
          _coverImages.add(file);
          _currentCoverIndex = _coverImages.length - 1;
          _coverPageController.jumpToPage(_currentCoverIndex);
        }
      });
    }
  }

  /// Popup de error
  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Atención"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  /// Permisos de ubicación
  Future<Position?> _determinePosition() async {
    if (!_locationEnabled) return null;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Completar registro: aquí es donde REALMENTE se loguea el usuario en Firebase
  /// y se guarda en la colección 'users'.
  Future<void> _onCompleteRegistration() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showErrorPopup("Por favor, ingresa un nombre.");
      return;
    }
    if (_coverImages.isEmpty) {
      _showErrorPopup("Sube al menos una imagen de portada.");
      return;
    }
    if (_profileImage == null) {
      _showErrorPopup("Elige una foto de perfil.");
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Si nadie está logueado, logueamos con las credenciales
      if (FirebaseAuth.instance.currentUser == null) {
        if (widget.provider == VerificationProvider.password &&
            widget.email != null &&
            widget.password != null) {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: widget.email!,
            password: widget.password!,
          );
        } else if (widget.provider == VerificationProvider.google &&
            widget.googleAccessToken != null &&
            widget.googleIdToken != null) {
          final credential = GoogleAuthProvider.credential(
            accessToken: widget.googleAccessToken,
            idToken: widget.googleIdToken,
          );
          await FirebaseAuth.instance.signInWithCredential(credential);
        }
      }

      // 2. Obtenemos el usuario logueado
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorPopup("No hay usuario logueado para completar el registro.");
        setState(() => _isSaving = false);
        return;
      }

      // 3. Localización (opcional)
      double latitude = 0.0;
      double longitude = 0.0;
      if (_locationEnabled) {
        final position = await _determinePosition();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
        }
      }

      // 4. Subir portadas
      final List<String> coverPhotoUrls = [];
      for (int i = 0; i < _coverImages.length; i++) {
        final file = _coverImages[i];
        final fileName =
            'users/${user.uid}/coverPhotos/${DateTime.now().millisecondsSinceEpoch}_$i.png';
        final downloadUrl = await _uploadFileToFirebase(file, fileName);
        if (downloadUrl != null) {
          coverPhotoUrls.add(downloadUrl);
        }
      }

      // 5. Subir foto de perfil
      String? profilePhotoUrl;
      {
        final fileName =
            'users/${user.uid}/profilePhoto/${DateTime.now().millisecondsSinceEpoch}.png';
        final url = await _uploadFileToFirebase(_profileImage!, fileName);
        profilePhotoUrl = url;
      }

      // 6. Guardar datos en Firestore
      final userData = <String, dynamic>{
        "uid": user.uid,
        "name": name,
        "age": _age.toInt(),
        "photoUrl": profilePhotoUrl ?? "",
        "coverPhotoUrl": coverPhotoUrls.isNotEmpty ? coverPhotoUrls.first : "",
        "coverPhotos": coverPhotoUrls,
        "latitude": latitude,
        "longitude": longitude,
        "privilegeLevel": "Básico",
        "profile_privacy": 0,
        "total_created_plans": 0,
        "total_participants_until_now": 0,
        "max_participants_in_one_plan": 0,
        "favourites": [],
        "deletedChats": [],
        "dateCreatedData": FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData);

      // 7. Navegamos a ExploreScreen
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ExploreScreen()),
      );
    } catch (e) {
      debugPrint("Error al crear usuario: $e");
      _showErrorPopup("Error: $e");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      // Fondo de la pantalla en blanco
      color: Colors.white,
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 16,
                right: 16,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Imagen "plan-sin-fondo.png" SIN borde
                  Center(
                    child: Image.asset(
                      'assets/plan-sin-fondo.png',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Avatar (foto de perfil)
                  _buildProfilePhotoPicker(),
                  const SizedBox(height: 20),

                  const Text(
                    "Este será el nombre con el que otros usuarios te conocerán",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFrostedInputContainer(
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        hintText: "Introduzca su nombre...",
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "Introduzca su edad",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildFrostedContainer(
                    child: Column(
                      children: [
                        Text(
                          "${_age.toInt()} años",
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Slider(
                          value: _age,
                          min: 18,
                          max: 100,
                          divisions: 82,
                          label: "${_age.toInt()} años",
                          activeColor: Colors.blue,
                          inactiveColor: Colors.grey,
                          onChanged: (double value) {
                            setState(() => _age = value);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "Estas serán las imágenes de portada de tu perfil",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildCoverPhotosCarousel(),
                  const SizedBox(height: 20),

                  const Text(
                    "Habilita tu ubicación para ver planes cercanos a ti y para que otros puedan verte",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildLocationSwitch(),
                  const SizedBox(height: 30),

                  // Botón "Completar registro"
                  SizedBox(
                    width: double.infinity,
                    child: _buildFrostedContainer(
                      child: ElevatedButton(
                        onPressed: _onCompleteRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          side: const BorderSide(color: Colors.grey, width: 2),
                        ),
                        child: const Text(
                          "Completar registro",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            if (_isSaving)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  /// Contenedor frosted
  Widget _buildFrostedContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            color: _frostedGray,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Contenedor para TextField
  Widget _buildFrostedInputContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            color: _frostedGray,
            child: child,
          ),
        ),
      ),
    );
  }

  /// Switch ubicación
  Widget _buildLocationSwitch() {
    return _buildFrostedContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Switch.adaptive(
          value: _locationEnabled,
          onChanged: (val) {
            setState(() => _locationEnabled = val);
          },
          activeColor: Colors.blue,
          inactiveTrackColor: Colors.grey,
        ),
      ),
    );
  }

  /// Carrusel para las fotos de portada
  Widget _buildCoverPhotosCarousel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey, width: 2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: SizedBox(
          height: 240,
          child: _coverImages.isEmpty
              ? Stack(
                  children: [
                    _buildFrostedContainer(
                      child: GestureDetector(
                        onTap: () => _showImagePickerPopup(
                          isForProfilePhoto: false,
                          isForCover: true,
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/anadir-imagen.svg',
                            width: 40,
                            height: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _buildAddCoverPhotoButton(),
                    ),
                  ],
                )
              : Stack(
                  children: [
                    PageView.builder(
                      controller: _coverPageController,
                      itemCount: _coverImages.length,
                      onPageChanged: (index) {
                        setState(() => _currentCoverIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.file(
                            _coverImages[index],
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                    if (_coverImages.length > 1)
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_coverImages.length, (i) {
                            final isActive = (i == _currentCoverIndex);
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isActive ? Colors.black : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        ),
                      ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _buildAddCoverPhotoButton(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAddCoverPhotoButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 40,
          height: 40,
          color: Colors.grey.withOpacity(0.3),
          child: GestureDetector(
            onTap: () => _showImagePickerPopup(
              isForProfilePhoto: false,
              isForCover: true,
            ),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  /// Picker para la foto de perfil
  Widget _buildProfilePhotoPicker() {
    final double avatarSize = 100;
    return GestureDetector(
      onTap: () => _showImagePickerPopup(
        isForProfilePhoto: true,
        isForCover: false,
      ),
      child: Center(
        child: Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey, width: 2),
            image: _profileImage != null
                ? DecorationImage(
                    image: FileImage(_profileImage!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _profileImage == null
              ? const Icon(
                  Icons.person_add,
                  color: Colors.white,
                  size: 40,
                )
              : null,
        ),
      ),
    );
  }
}
