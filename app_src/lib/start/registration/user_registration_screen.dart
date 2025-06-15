import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
// Importación para "reverse geocoding"
import 'package:geocoding/geocoding.dart' show placemarkFromCoordinates, Placemark;

// Importa tus colores desde tu archivo principal (ajusta el import si lo requieres)
import 'package:dating_app/main/colors.dart' as MyColors;

// Pantalla final (la que verás tras completar registro):
import 'package:dating_app/explore_screen/main_screen/explore_screen.dart';

// Enum de proveedor (google/password)
import 'verification_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'auth_service.dart';
import 'local_registration_service.dart';
import '../../services/fcm_token_service.dart';
import 'register_screen.dart';
import '../../utils/plans_list.dart';

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({
    Key? key,
    this.email,
    this.password,
    required this.provider,
    this.firebaseUser,
  }) : super(key: key);

  /// Si viene de registro con email+pass
  final String? email;
  final String? password;

  /// Proveedor (google/password)
  final VerificationProvider provider;

  /// Usuario que ya está logueado en Firebase (pero sin doc completo en Firestore)
  final User? firebaseUser;

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  Timer? _usernameDebounce;
  bool? _isUsernameAvailable;
  bool _isCheckingUsername = false;
  List<String> _usernameSuggestions = [];

  /// Para escribir manualmente la ciudad/municipio
  final TextEditingController _cityController = TextEditingController();

  /// Texto que mostramos en el "botón" de Ubicación actual
  String _locationLabel = "Ubicación actual";

  /// Fecha de nacimiento
  DateTime? _birthDate;

  /// Fotos de portada
  final List<File> _coverImages = [];
  late PageController _coverPageController;
  int _currentCoverIndex = 0;

  /// Foto de perfil
  File? _profileImage;

  /// Ubicación habilitada (inicialmente false)
  bool _locationEnabled = false;

  /// Indicador de guardando
  bool _isSaving = false;

  /// Checkbox de aceptación de términos
  bool _termsAccepted = false;

  List<String> _selectedInterests = [];
  String? _customInterest;
  final TextEditingController _interestController = TextEditingController();

  int _calculateAge(DateTime date) {
    final now = DateTime.now();
    int age = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return age;
  }

  bool get _isFormValid {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    if (name.isEmpty || username.isEmpty || _birthDate == null) return false;
    if (_isCheckingUsername || _isUsernameAvailable != true) return false;
    return _calculateAge(_birthDate!) >= 18;
  }

  void _onUsernameChanged() {
    final text = _usernameController.text.trim();
    _usernameDebounce?.cancel();
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () {
      _checkUsernameAvailability(text);
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.isEmpty) {
      setState(() {
        _isUsernameAvailable = null;
        _usernameSuggestions = [];
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('user_name', isEqualTo: username)
        .get();

    final available = snap.docs.isEmpty;
    List<String> suggestions = [];
    if (!available) {
      for (int i = 0; i < 3; i++) {
        suggestions.add('$username${Random().nextInt(1000)}');
      }
    }

    if (mounted) {
      setState(() {
        _isUsernameAvailable = available;
        _usernameSuggestions = suggestions;
        _isCheckingUsername = false;
      });
    }
  }

  void _toggleInterest(String name, {bool isCustom = false}) {
    setState(() {
      if (_selectedInterests.contains(name)) {
        _selectedInterests.remove(name);
        if (isCustom) _customInterest = null;
      } else {
        if (_selectedInterests.length >= 3) return;
        _selectedInterests.add(name);
        if (isCustom) _customInterest = name;
      }
    });
  }

  void _addCustomInterest() {
    final text = _interestController.text.trim();
    if (text.isEmpty) return;
    if (_selectedInterests.length >= 3 && _customInterest == null) return;
    setState(() {
      if (_customInterest != null) {
        _selectedInterests.remove(_customInterest);
      }
      _customInterest = text;
      if (!_selectedInterests.contains(text)) {
        _selectedInterests.add(text);
      }
      _interestController.clear();
    });
  }

  Widget _buildInterestChip(String name, bool isCustom) {
    final selected = _selectedInterests.contains(name);
    return InkWell(
      onTap: () => _toggleInterest(name, isCustom: isCustom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? MyColors.AppColors.planColor : MyColors.AppColors.lightLilac,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MyColors.AppColors.greyBorder),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _coverPageController = PageController();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _coverPageController.dispose();
    _nameController.dispose();
    _usernameDebounce?.cancel();
    _usernameController.dispose();
    _cityController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  /// Muestra un pop-up de error
  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          "Atención",
          style: TextStyle(color: MyColors.AppColors.blue),
        ),
        content: Text(
          message,
          style: TextStyle(color: MyColors.AppColors.blue),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "OK",
              style: TextStyle(color: MyColors.AppColors.blue),
            ),
          )
        ],
      ),
    );
  }

  /// Sube un archivo a Firebase Storage y devuelve la URL
  Future<String?> _uploadFileToFirebase(File file, String fileName) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (error) {
      return null;
    }
  }

  /// Obtiene la posición actual (solo si _locationEnabled está en true)
  Future<Position?> _determinePosition() async {
    if (!_locationEnabled) return null;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Servicio de ubicación desactivado
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


  /// Botón "Completar registro" sin modal de términos
  Future<void> _onAcceptTermsAndRegister() async {
    await _onCompleteRegistration();
  }

  Future<void> _onCompleteRegistration() async {
    setState(() => _isSaving = true);

    User? user;
    try {
      if (widget.firebaseUser != null) {
        // Usuario ya creado (por ejemplo tras verificar correo)
        user = widget.firebaseUser;
      } else if (widget.provider == VerificationProvider.password &&
          widget.email != null &&
          widget.password != null) {
        final cred = await AuthService.createUserWithEmail(
          email: widget.email!.trim(),
          password: widget.password!.trim(),
        );
        user = cred.user;
      } else if (widget.provider == VerificationProvider.google) {
        final cred = await AuthService.signInWithGoogle();
        user = cred.user;
      }

      if (user == null) throw Exception('No user');

      if (widget.provider == VerificationProvider.google &&
          widget.password != null &&
          widget.password!.isNotEmpty) {
        try {
          final cred = EmailAuthProvider.credential(
            email: user.email ?? '',
            password: widget.password!.trim(),
          );
          await user.linkWithCredential(cred);
        } catch (_) {}
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorPopup('Error al crear usuario: $e');
      return;
    }

    // Revisar campos obligatorios
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    if (name.isEmpty) {
      setState(() => _isSaving = false);
      _showErrorPopup('Por favor, ingresa un nombre.');
      return;
    }
    if (username.isEmpty || _isUsernameAvailable != true) {
      setState(() => _isSaving = false);
      _showErrorPopup('Por favor, ingresa un nombre de usuario válido.');
      return;
    }
    if (_birthDate == null) {
      setState(() => _isSaving = false);
      _showErrorPopup('Por favor, selecciona tu fecha de nacimiento.');
      return;
    }
    final age = _calculateAge(_birthDate!);
    if (age < 18) {
      setState(() => _isSaving = false);
      _showErrorPopup('Debes ser mayor de 18 años para registrarte.');
      return;
    }

    try {
      // Ubicación (opcional)
      double latitude = 0.0;
      double longitude = 0.0;
      if (_locationEnabled) {
        final position = await _determinePosition();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
        }
      }

      // Subimos fotos de portada (si las hay)
      final List<String> coverPhotoUrls = [];
      if (_coverImages.isNotEmpty) {
        for (int i = 0; i < _coverImages.length; i++) {
          final file = _coverImages[i];
          final fileName =
              'users/${user.uid}/coverPhotos/${DateTime.now().millisecondsSinceEpoch}_$i.png';
          final downloadUrl = await _uploadFileToFirebase(file, fileName);
          if (downloadUrl != null) {
            coverPhotoUrls.add(downloadUrl);
          }
        }
      }

      // Subimos foto de perfil (si existe)
      String? profilePhotoUrl;
      if (_profileImage != null) {
        final fileName =
            'users/${user.uid}/profilePhoto/${DateTime.now().millisecondsSinceEpoch}.png';
        final url = await _uploadFileToFirebase(_profileImage!, fileName);
        profilePhotoUrl = url;
      }

      // Creamos o actualizamos doc en Firestore
      final userData = <String, dynamic>{
        'uid': user.uid,
        'name': name,
        'nameLowercase': name.toLowerCase(),
        'user_name': username,
        'user_name_lowercase': username.toLowerCase(),
        'age': age,
        'photoUrl': profilePhotoUrl ?? '',
        'coverPhotoUrl': coverPhotoUrls.isNotEmpty ? coverPhotoUrls.first : '',
        'coverPhotos': coverPhotoUrls,
        'latitude': latitude,
        'longitude': longitude,
        'privilegeLevel': 'Básico',
        'profile_privacy': 0,
        'total_created_plans': 0,
        'total_participants_until_now': 0,
        'max_participants_in_one_plan': 0,
        'favourites': [],
        'deletedChats': [],
        'dateCreatedData': FieldValue.serverTimestamp(),

        'interests': _selectedInterests,

        // NUEVOS CAMPOS DE PRESENCIA:
        'online': true,
        'lastActive': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData);

      // Guardamos token de notificaciones
      await FcmTokenService.register(user);


      await LocalRegistrationService.clear();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const ExploreScreen(showQuickStart: true),
        ),
        (_) => false,
      );
    } catch (e) {
      _showErrorPopup('Error al crear usuario: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// Muestra pop-up para escoger entre cámara o galería
  void _showImagePickerPopup({
    required bool isForProfilePhoto,
    required bool isForCover,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      barrierLabel: "Seleccionar imagen",
      pageBuilder: (context, _, __) {
        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MyColors.AppColors.lightLilac,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImage(
                        fromCamera: false,
                        isForProfilePhoto: isForProfilePhoto,
                        isForCover: isForCover,
                      );
                    },
                    child: Text(
                      "Seleccionar de la galeria",
                      style: TextStyle(
                        color: MyColors.AppColors.blue,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImage(
                        fromCamera: true,
                        isForProfilePhoto: isForProfilePhoto,
                        isForCover: isForCover,
                      );
                    },
                    child: Text(
                      "Tomar una foto",
                      style: TextStyle(
                        color: MyColors.AppColors.blue,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Toma la foto desde galería o cámara y la asigna
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
          // Límite de 5 fotos de portada
          if (_coverImages.length >= 5) {
            _showErrorPopup("Máximo 5 imágenes de portada.");
            return;
          }
          _coverImages.add(file);
          _currentCoverIndex = _coverImages.length - 1;
          // Forzamos el rebuild inmediato
          _coverPageController.jumpToPage(_currentCoverIndex);
        }
      });
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 18, now.month, now.day);
    final first = DateTime(now.year - 100);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  /// Abre la imagen de perfil en pantalla completa
  void _showFullScreenImage(File imageFile) {
    showDialog(
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.black.withOpacity(0.9),
            child: Center(
              child: Image.file(imageFile),
            ),
          ),
        );
      },
    );
  }

  /// Carrusel de fotos de portada (sin borde doble)
  Widget _buildCoverPhotosCarousel() {
    return Container(
      // Borde fino, interior blanco
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: MyColors.AppColors.greyBorder, width: 1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: SizedBox(
        height: 240,
        child: _coverImages.isEmpty
            ? Stack(
                children: [
                  // Placeholder
                  GestureDetector(
                    onTap: () => _showImagePickerPopup(
                      isForProfilePhoto: false,
                      isForCover: true,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey, // Placeholder gris para portada
                        borderRadius: BorderRadius.circular(30),
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
                        borderRadius: BorderRadius.circular(29),
                        child: Image.file(
                          _coverImages[index],
                          fit: BoxFit.cover,
                          key: ValueKey(_coverImages[index].path),
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
                              color: isActive
                                  ? MyColors.AppColors.blue
                                  : MyColors.AppColors.blue.withOpacity(0.3),
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
    );
  }

  /// Botoncito "+" para agregar más fotos de portada
  Widget _buildAddCoverPhotoButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: MyColors.AppColors.blue.withOpacity(0.7),
        shape: BoxShape.circle,
      ),
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
    );
  }

  /// Avatar de perfil con icono de cámara
  Widget _buildProfilePhotoPicker() {
    final double avatarSize = 110;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // GestureDetector para mostrar la imagen en grande si existe
            GestureDetector(
              onTap: () {
                if (_profileImage != null) {
                  _showFullScreenImage(_profileImage!);
                }
              },
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MyColors.AppColors.greyBorder,
                    width: 2,
                  ),
                  image: _profileImage != null
                      ? DecorationImage(
                          image: FileImage(_profileImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: Colors.white,
                ),
                child: _profileImage == null
                    ? Icon(
                        Icons.person,
                        color: MyColors.AppColors.black,
                        size: 60,
                      )
                    : null,
              ),
            ),
            // Icono de cámara en esquina inferior derecha
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _showImagePickerPopup(
                  isForProfilePhoto: true,
                  isForCover: false,
                ),
                child: CircleAvatar(
                  backgroundColor: MyColors.AppColors.blue,
                  radius: 18,
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          "Tu foto de perfil",
          style: TextStyle(
            color: MyColors.AppColors.black,
            fontSize: 16,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  /// Cuando se pulsa "Ubicación actual":
  /// - Se pone _locationEnabled en true
  /// - Se llama a _determinePosition() (pidiendo permiso de ubicación)
  /// - Si se obtiene la posición, se realiza reverse geocoding para mostrar
  ///   "Leganés, Madrid, España" en vez de lat/long.
  Future<void> _onTapCurrentLocation() async {
    setState(() => _locationEnabled = true);
    final position = await _determinePosition();

    if (position != null) {
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final Placemark place = placemarks.first;

          final String city = place.locality ?? "";
          final String region = place.administrativeArea ?? "";
          final String country = place.country ?? "";

          setState(() {
            _locationLabel = "$city, $region, $country";
          });
        }
      } catch (e) {
      }
    } else {
      // Si falla (usuario deniega permisos o no obtiene ubicación)
      setState(() {
        _locationEnabled = false;
        _locationLabel = "Ubicación actual (permiso denegado)";
      });
      // _showErrorPopup("No se pudo obtener tu ubicación actual");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
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

                  Center(
                    child: Image.asset(
                      'assets/plan-sin-fondo.png',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Foto de perfil
                  _buildProfilePhotoPicker(),
                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Elige planes afines a tus intereses",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: MyColors.AppColors.black,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (_customInterest != null)
                        _buildInterestChip(_customInterest!, true),
                      ...plans.map((p) => _buildInterestChip(p['name'], false)).toList(),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _interestController,
                          decoration: const InputDecoration(
                            hintText: 'Escribe tu plan...',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addCustomInterest,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Nombre real",
                        style: TextStyle(
                          fontSize: 16,
                          color: MyColors.AppColors.black,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const Text(
                        '*',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Campo nombre
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: MyColors.AppColors.greyBorder,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.grey),
                      decoration: InputDecoration(
                        hintText: "Introduzca su nombre...",
                        hintStyle: TextStyle(
                          color: Colors.grey,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Nombre de usuario",
                        style: TextStyle(
                          fontSize: 16,
                          color: MyColors.AppColors.black,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const Text('*', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: MyColors.AppColors.greyBorder,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.grey),
                      decoration: InputDecoration(
                        hintText: "Introduzca su id...",
                        hintStyle: TextStyle(
                          color: Colors.grey,
                        ),
                        border: InputBorder.none,
                        suffixIconConstraints:
                            const BoxConstraints.tightFor(width: 24, height: 24),
                        suffixIcon: _isCheckingUsername
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : _isUsernameAvailable == null
                                ? null
                                : Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: _isUsernameAvailable!
                                          ? Colors.green
                                          : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      _isUsernameAvailable!
                                          ? Icons.check
                                          : Icons.close,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                      ),
                    ),
                  ),
                  if (_usernameSuggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        children: _usernameSuggestions.map((s) {
                          return InkWell(
                            onTap: () {
                              _usernameController.text = s;
                              _usernameController.selection = TextSelection.collapsed(offset: s.length);
                              _checkUsernameAvailability(s);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: MyColors.AppColors.lightLilac,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: MyColors.AppColors.greyBorder),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(color: Colors.black),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Fecha de nacimiento",
                        style: TextStyle(
                          fontSize: 16,
                          color: MyColors.AppColors.black,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const Text('*', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _pickBirthDate,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: MyColors.AppColors.greyBorder,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _birthDate != null
                                ? DateFormat('dd/MM/yyyy').format(_birthDate!)
                                : 'Seleccione su fecha...',
                            style:
                                const TextStyle(color: Colors.grey),
                          ),
                          Icon(Icons.calendar_today,
                              color: MyColors.AppColors.greyBorder),
                        ],
                      ),
                    ),
                  ),
                  if (_birthDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Tienes ${_calculateAge(_birthDate!)} años',
                        style: TextStyle(
                          color: MyColors.AppColors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  Text(
                    "Imágenes de portada",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: MyColors.AppColors.black,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Carrusel de fotos
                  _buildCoverPhotosCarousel(),
                  const SizedBox(height: 20),

                  // -----------------------------
                  //   UBICACIÓN (opcional)
                  // -----------------------------
                  Text(
                    "Ubicación",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 16,
                      color: MyColors.AppColors.black,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Campo manual (ciudad)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: MyColors.AppColors.greyBorder,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _cityController,
                      style: const TextStyle(color: Colors.grey),
                      decoration: InputDecoration(
                        hintText: "Introduce tu ciudad o municipio...",
                        hintStyle: TextStyle(
                          color: Colors.grey,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  GestureDetector(
                    onTap: _onTapCurrentLocation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: MyColors.AppColors.greyBorder,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _locationLabel,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          Icon(
                            Icons.near_me,
                            color: MyColors.AppColors.blue,
                          ),
                        ],
                      ),
                  ),
                ),

                  const SizedBox(height: 20),

                  // Checkbox de aceptación de términos
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _termsAccepted,
                        onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        side: BorderSide(color: MyColors.AppColors.planColor),
                        checkColor: Colors.white,
                        activeColor: MyColors.AppColors.planColor,
                      ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              decoration: TextDecoration.none,
                            ),
                            children: [
                              const TextSpan(text: 'He leído y acepto los '),
                              TextSpan(
                                text: 'Términos y Condiciones',
                                style: const TextStyle(color: Colors.blue),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => launchUrl(
                                        Uri.parse('https://plansocialapp.es/terms_and_conditions.html'),
                                        mode: LaunchMode.externalApplication,
                                      ),
                              ),
                              const TextSpan(text: ', la '),
                              TextSpan(
                                text: 'Política de Privacidad',
                                style: const TextStyle(color: Colors.blue),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => launchUrl(
                                        Uri.parse('https://plansocialapp.es/privacy_policy.html'),
                                        mode: LaunchMode.externalApplication,
                                      ),
                              ),
                              const TextSpan(text: ' y de '),
                              TextSpan(
                                text: 'Cookies',
                                style: const TextStyle(color: Colors.blue),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => launchUrl(
                                        Uri.parse('https://plansocialapp.es/cookies.html'),
                                        mode: LaunchMode.externalApplication,
                                      ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Botón "Completar registro"
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving || !_isFormValid || !_termsAccepted
                          ? null
                          : _onAcceptTermsAndRegister,
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.resolveWith(
                          (states) => states.contains(MaterialState.disabled)
                              ? Colors.grey
                              : MyColors.AppColors.blue,
                        ),
                        padding: MaterialStateProperty.all(
                          const EdgeInsets.symmetric(vertical: 14),
                        ),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                      child: const Text(
                        "Completar registro",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '*Campos obligatorios',
                    style: TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),

            Positioned(
              top: 40,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                color: MyColors.AppColors.planColor,
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
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
}
