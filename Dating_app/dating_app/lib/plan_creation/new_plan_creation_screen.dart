import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

import '../main/colors.dart';
import '../models/plan_model.dart';
import 'image_cropper_screen.dart';
import 'meeting_location_screen.dart';
import '../utils/plans_list.dart';

/// Función auxiliar para convertir un SVG en BitmapDescriptor aplicando un color.
Future<BitmapDescriptor> getCustomSvgMarker(
  BuildContext context,
  String assetPath,
  Color color, {
  double width = 48,
  double height = 48,
}) async {
  String svgString = await DefaultAssetBundle.of(context).loadString(assetPath);
  // Reemplaza el atributo fill del SVG por el color deseado.
  final String coloredSvgString = svgString.replaceAll(
    RegExp(r'fill="[^"]*"'),
    'fill="#${color.value.toRadixString(16).padLeft(8, "0")}"',
  );
  final DrawableRoot svgDrawableRoot =
      await svg.fromSvgString(coloredSvgString, assetPath);
  final ui.Picture picture = svgDrawableRoot.toPicture(size: Size(width, height));
  final ui.Image image = await picture.toImage(width.toInt(), height.toInt());
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
}

/// Función para subir imagen (PNG/JPG) a Firebase Storage y obtener la URL de descarga.
/// [fileName] es el path/archivo dentro del Storage (ej: 'plan_backgrounds/...')
Future<String?> uploadImageToFirebase(Uint8List imageData, String fileName) async {
  try {
    final ref = FirebaseStorage.instance.ref().child(fileName);
    await ref.putData(imageData);
    String downloadURL = await ref.getDownloadURL();
    return downloadURL;
  } catch (error) {
    print('Error al subir la imagen: $error');
    return null;
  }
}

/// Función para subir el video a Firebase Storage y obtener la URL.
Future<String?> uploadVideo(Uint8List videoData, String planId) async {
  try {
    final ref = FirebaseStorage.instance.ref().child('plan_backgrounds/$planId.mp4');
    await ref.putData(videoData, SettableMetadata(contentType: 'video/mp4'));
    String downloadURL = await ref.getDownloadURL();
    return downloadURL;
  } catch (error) {
    print('Error al subir el video: $error');
    return null;
  }
}

class NewPlanCreationScreen {
  static void showPopup(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierLabel: "Nuevo Plan",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return Material(
          type: MaterialType.transparency,
          child: Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D253F),
                    Color(0xFF1B3A57),
                    Color(0xFF12232E),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: _NewPlanPopupContent(),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: anim1,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _NewPlanPopupContent extends StatefulWidget {
  @override
  __NewPlanPopupContentState createState() => __NewPlanPopupContentState();
}

class __NewPlanPopupContentState extends State<_NewPlanPopupContent> {
  // Elección del tipo de plan
  String? _selectedPlan;
  String? _customPlan;
  String? _selectedIconAsset;
  IconData? _selectedIconData;
  bool _isDropdownOpen = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  // Fecha y hora
  bool _allDay = false;
  bool _includeEndDate = false;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  // Ubicación
  String? _location;
  double? _latitude;
  double? _longitude;

  // Sección de "fondo del plan": hasta 3 imágenes + 1 video
  // Guardamos DOS listas: la recortada y la original (para permitir recorte posterior).
  final List<Uint8List> _selectedCroppedImages = [];
  final List<Uint8List> _selectedOriginalImages = [];

  Uint8List? _selectedVideo;

  // Para el carrusel de imágenes + video
  late PageController _pageController;
  int _currentPageIndex = 0;

  // Restricción de edad
  RangeValues _ageRange = const RangeValues(18, 60);

  // Máximo número de participantes
  int? _maxParticipants;

  // Breve descripción
  String? _planDescription;

  // Visibilidad
  String? _selectedVisibility;

  double headerHorizontalInset = 0;
  double fieldsHorizontalInset = 20;

  // Marcador en el mapa
  Future<BitmapDescriptor>? _markerIconFuture;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  // Cantidad total de ítems (imágenes + video)
  int get totalMedia =>
      _selectedCroppedImages.length + (_selectedVideo == null ? 0 : 1);

  void _loadMarkerIcon() {
    _markerIconFuture = getCustomSvgMarker(
      context,
      'assets/icono-ubicacion-interno.svg',
      AppColors.blue,
      width: 48,
      height: 48,
    );
    setState(() {});
  }

  void _toggleDropdown() {
    _isDropdownOpen ? _closeDropdown() : _openDropdown();
  }

  void _openDropdown() {
    setState(() => _isDropdownOpen = true);
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context)!.insert(_overlayEntry!);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isDropdownOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeDropdown,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 44),
            child: _buildDropdownMenu(),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownMenu() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withOpacity(0.1),
          child: Container(
            width: 265,
            height: 300,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 165, 159, 159).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // TextField para escribir un plan personalizado
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    onChanged: (value) {
                      _customPlan = value;
                      if (value.isNotEmpty) {
                        _selectedIconData = Icons.lightbulb;
                        _selectedIconAsset = null;
                      }
                    },
                    style: const TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.none,
                      fontFamily: 'Inter-Regular',
                    ),
                    decoration: InputDecoration(
                      hintText: "Escribe tu plan...",
                      hintStyle: const TextStyle(
                        color: Colors.white70,
                        decoration: TextDecoration.none,
                        fontFamily: 'Inter-Regular',
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Center(
                    child: Text(
                      "Si no se te ocurre nada, echa un vistazo a los siguientes:",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                        fontFamily: 'Inter-Regular',
                      ),
                    ),
                  ),
                ),
                const Divider(
                  color: Colors.white30,
                  thickness: 0.3,
                  height: 0,
                ),
                // Lista de planes sugeridos
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: plans.length,
                    itemBuilder: (context, index) => Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white,
                            width: 0.3,
                          ),
                        ),
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        dense: true,
                        leading: SvgPicture.asset(
                          plans[index]['icon'],
                          width: 28,
                          height: 28,
                          color: const Color.fromARGB(235, 229, 229, 252),
                        ),
                        title: Text(
                          plans[index]['name'],
                          style: const TextStyle(
                            color: Color.fromARGB(255, 218, 207, 207),
                            decoration: TextDecoration.none,
                            fontFamily: 'Inter-Regular',
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedPlan = plans[index]['name'];
                            _selectedIconAsset = plans[index]['icon'];
                            _selectedIconData = null;
                            _customPlan = null;
                          });
                          _closeDropdown();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Popup para elegir si subimos imagen/video
  void _showMediaSelectionPopup() {
    showGeneralDialog(
      context: context,
      barrierLabel: "Selecciona medio",
      pageBuilder: (context, anim1, anim2) => Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D253F),
                Color(0xFF1B3A57),
                Color(0xFF12232E),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "¿Qué deseas subir?",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                  fontFamily: 'Inter-Regular',
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
                child: const Text(
                  "Imagen (galería)",
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.none,
                    fontFamily: 'Inter-Regular',
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
                child: const Text(
                  "Imagen (cámara)",
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.none,
                    fontFamily: 'Inter-Regular',
                  ),
                ),
              ),
              const Divider(
                color: Colors.white54,
                height: 20,
                thickness: 0.3,
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _pickVideo(ImageSource.gallery);
                },
                child: const Text(
                  "Video (galería)",
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.none,
                    fontFamily: 'Inter-Regular',
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _pickVideo(ImageSource.camera);
                },
                child: const Text(
                  "Video (cámara)",
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.none,
                    fontFamily: 'Inter-Regular',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Elegir imagen y recortarla (guardando original y recortada).
  Future<void> _pickImage(ImageSource source) async {
    if (_selectedCroppedImages.length >= 3) {
      _showErrorPopup("Solo se permiten máximo 3 imágenes.");
      return;
    }
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      final originalImageData = await pickedFile.readAsBytes();
      // Ir a recortar
      final croppedData = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageCropperScreen(imageData: originalImageData),
        ),
      );
      if (croppedData != null) {
        setState(() {
          // Guardamos ambas versiones: la recortada y la original
          _selectedCroppedImages.add(croppedData);
          _selectedOriginalImages.add(originalImageData);
        });
      }
    }
  }

  /// Elegir video (max 1), revisar duración 15 seg
  Future<void> _pickVideo(ImageSource source) async {
    if (_selectedVideo != null) {
      _showErrorPopup("Ya has seleccionado un video. Máximo 1 video.");
      return;
    }
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: source);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      final duration = controller.value.duration.inSeconds;
      // Máx 15s
      if (duration > 15) {
        controller.dispose();
        _showErrorPopup("El video excede los 15 segundos permitidos.");
        return;
      }
      final videoData = await pickedFile.readAsBytes();
      controller.dispose();
      setState(() {
        _selectedVideo = videoData;
      });
    }
  }

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

  /// Fecha/hora
  Future<void> _showDateSelectionPopup() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DateSelectionDialog(
        initialAllDay: _allDay,
        initialIncludeEndDate: _includeEndDate,
        initialStartDate: _startDate,
        initialStartTime: _startTime,
        initialEndDate: _endDate,
        initialEndTime: _endTime,
      ),
    );
    if (result != null) {
      setState(() {
        _allDay = result['allDay'] as bool;
        _includeEndDate = result['includeEndDate'] as bool;
        _startDate = result['startDate'] as DateTime?;
        _startTime = result['startTime'] as TimeOfDay?;
        _endDate = result['endDate'] as DateTime?;
        _endTime = result['endTime'] as TimeOfDay?;
      });
    }
  }

  /// Ubicación
  void _navigateToMeetingLocation() {
    final plan = PlanModel(
      id: '',
      type: _customPlan ?? _selectedPlan ?? '',
      description: _planDescription ?? '',
      minAge: _ageRange.start.round(),
      maxAge: _ageRange.end.round(),
      location: _location ?? '',
      latitude: _latitude ?? 0.0,
      longitude: _longitude ?? 0.0,
      startTimestamp: null,
      finishTimestamp: null,
      createdBy: '',
    );

    showGeneralDialog(
      context: context,
      barrierLabel: "Ubicación",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.6,
            child: MeetingLocationPopup(plan: plan),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: anim1,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    ).then((updatedPlan) async {
      if (updatedPlan != null && updatedPlan is PlanModel) {
        setState(() {
          _location = updatedPlan.location;
          _latitude = updatedPlan.latitude;
          _longitude = updatedPlan.longitude;
        });
        _loadMarkerIcon();
      }
    });
  }

  Widget _buildLocationSelectionArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),
        const Center(
          child: Text(
            "Punto de encuentro para el Plan",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              decoration: TextDecoration.none,
              fontFamily: 'Inter-Regular',
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _navigateToMeetingLocation,
          child: _latitude != null && _longitude != null
              ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: SizedBox(
                        height: 240,
                        width: double.infinity,
                        child: FutureBuilder<BitmapDescriptor>(
                          future: _markerIconFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final icon = snapshot.hasData
                                ? snapshot.data!
                                : BitmapDescriptor.defaultMarker;
                            return GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(_latitude!, _longitude!),
                                zoom: 16,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('selected'),
                                  position: LatLng(_latitude!, _longitude!),
                                  icon: icon,
                                  anchor: const Offset(0.5, 1.0),
                                )
                              },
                              zoomControlsEnabled: false,
                              myLocationButtonEnabled: false,
                              liteModeEnabled: false,
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            color: Colors.black.withOpacity(0.3),
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _location!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      height: 240,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icono-ubicacion.svg',
                          width: 30,
                          height: 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  /// Para formatear fecha en estilo "Lunes, 20 de Enero de 2025"
  String _formatHumanReadableDateOnly(DateTime date) {
    final Map<int, String> weekdays = {
      1: "Lunes",
      2: "Martes",
      3: "Miércoles",
      4: "Jueves",
      5: "Viernes",
      6: "Sábado",
      7: "Domingo",
    };
    final Map<int, String> months = {
      1: "Enero",
      2: "Febrero",
      3: "Marzo",
      4: "Abril",
      5: "Mayo",
      6: "Junio",
      7: "Julio",
      8: "Agosto",
      9: "Septiembre",
      10: "Octubre",
      11: "Noviembre",
      12: "Diciembre",
    };
    String weekday = weekdays[date.weekday] ?? "";
    String monthName = months[date.month] ?? "";
    return "$weekday, ${date.day} de $monthName de ${date.year}";
  }

  /// Para formatear hora en estilo "17:00"
  String _formatHumanReadableTime(TimeOfDay time) {
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  Widget _buildSelectedDatesPreview() {
    if (_startDate == null) return const SizedBox.shrink();
    final startDateText = _formatHumanReadableDateOnly(_startDate!);
    final startTimeText = (_allDay || _startTime == null)
        ? "todo el día"
        : "a las ${_formatHumanReadableTime(_startTime!)}";

    Widget? endDateWidget;
    if (_includeEndDate && _endDate != null) {
      final endDateText = _formatHumanReadableDateOnly(_endDate!);
      final endTimeText = (_allDay || _endTime == null)
          ? ""
          : " a las ${_formatHumanReadableTime(_endTime!)}";

      endDateWidget = RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'Inter-Regular',
            decoration: TextDecoration.none,
            color: Colors.white,
          ),
          children: [
            const TextSpan(text: "Hasta "),
            TextSpan(
              text: "$endDateText$endTimeText",
              style: const TextStyle(
                fontSize: 16,
                color: Color.fromARGB(235, 155, 157, 251),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Inter-Regular',
              decoration: TextDecoration.none,
              color: Colors.white,
            ),
            children: [
              TextSpan(
                text: startDateText,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(235, 155, 157, 251),
                ),
              ),
              if (!_allDay && _startTime != null) ...[
                const TextSpan(text: " "),
                TextSpan(
                  text: startTimeText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
              if (_allDay) ...[
                const TextSpan(text: " "),
                const TextSpan(
                  text: "(todo el día)",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (endDateWidget != null) endDateWidget,
      ],
    );
  }

  Widget _buildDateSelectionArea() {
    return GestureDetector(
      onTap: _showDateSelectionPopup,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              "Fecha y hora del plan",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Inter-Regular',
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: _includeEndDate ? 140 : 100,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/icono-calendario.svg',
                          width: 30,
                          height: 30,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        _buildSelectedDatesPreview(),
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
  }

  /// Cuando el usuario toca una imagen recortada, abrimos la pantalla donde
  /// se ve la imagen original y se puede recortar de nuevo.
  void _onTapCroppedImage(int index) async {
    final result = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(
        builder: (context) => _PreviewAndRecropScreen(
          originalImage: _selectedOriginalImages[index],
          croppedImage: _selectedCroppedImages[index],
        ),
      ),
    );
    if (result != null) {
      // El usuario recortó de nuevo
      setState(() {
        _selectedCroppedImages[index] = result;
      });
    }
  }

  Widget _buildMediaCarousel() {
    return Stack(
      children: [
        // PageView con imágenes y/o video
        Positioned.fill(
          child: PageView.builder(
            controller: _pageController,
            itemCount: totalMedia,
            onPageChanged: (index) {
              setState(() {
                _currentPageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final isImageSection = (index < _selectedCroppedImages.length);
              if (isImageSection) {
                final croppedImageData = _selectedCroppedImages[index];
                return GestureDetector(
                  onTap: () => _onTapCroppedImage(index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.memory(
                      croppedImageData,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              } else {
                // Vista previa de video (icono de reproducir)
                return ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        ),
        // Indicadores de páginas
        if (totalMedia > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalMedia, (i) {
                final isActive = (i == _currentPageIndex);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
        // Botón flotante para añadir más contenido
        Positioned(
          top: 10,
          right: 10,
          child: _buildAddMediaButton(),
        ),
      ],
    );
  }

  Widget _buildAddMediaButton() {
    return GestureDetector(
      onTap: _showMediaSelectionPopup,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            color: const ui.Color.fromARGB(255, 96, 94, 94).withOpacity(0.2),
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

  /// Sección para mostrar imágenes/video
  Widget _buildImageAndVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Center(
          child: Text(
            "Contenido multimedia",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              decoration: TextDecoration.none,
              fontFamily: 'Inter-Regular',
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 240,
          width: double.infinity,
          child: (totalMedia == 0)
              ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 124, 120, 120)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/anadir-imagen.svg',
                            width: 30,
                            height: 30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _buildAddMediaButton(),
                    ),
                  ],
                )
              : _buildMediaCarousel(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(
              right: 5,
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Encabezado
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: headerHorizontalInset),
                  child: Center(
                    child: Image.asset(
                      'assets/plan-sin-fondo.png',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Contenido principal
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: fieldsHorizontalInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "¡Hazle saber a la gente el plan que deseas compartir!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Inter-Regular',
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tipo de plan
                      CompositedTransformTarget(
                        link: _layerLink,
                        child: GestureDetector(
                          onTap: _toggleDropdown,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                width: 260,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 124, 120, 120)
                                      .withOpacity(0.2),
                                  border: Border.all(
                                    color: const Color.fromARGB(255, 151, 121, 215),
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          if (_selectedIconAsset != null)
                                            SvgPicture.asset(
                                              _selectedIconAsset!,
                                              width: 28,
                                              height: 28,
                                              color: Colors.white,
                                            ),
                                          if (_selectedIconData != null)
                                            Icon(
                                              _selectedIconData,
                                              color: Colors.white,
                                            ),
                                          if (_selectedIconAsset != null ||
                                              _selectedIconData != null)
                                            const SizedBox(width: 10),
                                          Flexible(
                                            child: Text(
                                              _customPlan ?? _selectedPlan ?? "Elige un plan",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'Inter-Regular',
                                                fontSize: 14,
                                                decoration: TextDecoration.none,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: Color.fromARGB(255, 227, 225, 231),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sección imágenes/video
                      _buildImageAndVideoSection(),

                      const SizedBox(height: 20),

                      // Fecha/hora
                      _buildDateSelectionArea(),

                      const SizedBox(height: 20),

                      // Ubicación
                      _buildLocationSelectionArea(),

                      const SizedBox(height: 20),

                      // Restricción de edad
                      const Text(
                        "Restricción de edad para el plan",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Inter-Regular',
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 124, 120, 120)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppColors.blue,
                                inactiveTrackColor:
                                    const Color.fromARGB(235, 225, 225, 234)
                                        .withOpacity(0.3),
                                trackHeight: 1,
                                thumbColor: AppColors.blue,
                                overlayColor: AppColors.blue.withOpacity(0.2),
                                thumbShape:
                                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                                overlayShape:
                                    const RoundSliderOverlayShape(overlayRadius: 24),
                              ),
                              child: RangeSlider(
                                values: _ageRange,
                                min: 0,
                                max: 100,
                                divisions: 100,
                                labels: RangeLabels(
                                  "${_ageRange.start.round()}",
                                  "${_ageRange.end.round()}",
                                ),
                                onChanged: (newRange) {
                                  setState(() {
                                    _ageRange = newRange;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "Participan edades de ${_ageRange.start.round()} a ${_ageRange.end.round()} años",
                              style: const TextStyle(
                                color: Color.fromARGB(255, 223, 199, 199),
                                fontSize: 14,
                                decoration: TextDecoration.none,
                                fontFamily: 'Inter-Regular',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Máximo participantes
                      const Text(
                        "Máximo número de participantes",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Inter-Regular',
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 124, 120, 120)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              'assets/icono-max-participantes.svg',
                              width: 28,
                              height: 28,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    _maxParticipants = int.tryParse(value);
                                  });
                                },
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  hintText: "Ingresa un número...",
                                  hintStyle: TextStyle(
                                    color: Colors.white70,
                                    fontFamily: 'Inter-Regular',
                                    decoration: TextDecoration.none,
                                  ),
                                  border: InputBorder.none,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Inter-Regular',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Descripción
                      const Text(
                        "Breve descripción del plan",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Inter-Regular',
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextField(
                          maxLines: 3,
                          onChanged: (value) {
                            setState(() {
                              _planDescription = value;
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: "Describe brevemente tu plan...",
                            hintStyle: TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Inter-Regular',
                              decoration: TextDecoration.none,
                            ),
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Inter-Regular',
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Visibilidad
                      const Text(
                        "Este plan es:",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Inter-Regular',
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedVisibility = "Publico";
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedVisibility == "Publico"
                                    ? AppColors.blue
                                    : const Color.fromARGB(255, 124, 120, 120)
                                        .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'assets/icono-plan-publico.svg',
                                    width: 24,
                                    height: 24,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Público",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Inter-Regular',
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedVisibility = "Privado";
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedVisibility == "Privado"
                                    ? AppColors.blue
                                    : const Color.fromARGB(255, 124, 120, 120)
                                        .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'assets/icono-plan-privado.svg',
                                    width: 24,
                                    height: 24,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Privado",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Inter-Regular',
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedVisibility = "Solo para mis seguidores";
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedVisibility ==
                                        "Solo para mis seguidores"
                                    ? AppColors.blue
                                    : const Color.fromARGB(255, 124, 120, 120)
                                        .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'assets/icono-plan-seguidores.svg',
                                    width: 24,
                                    height: 24,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Solo para mis seguidores",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Inter-Regular',
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Botón de Finalizar
                      ElevatedButton(
                        onPressed: _onCreatePlanPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(235, 17, 19, 135),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "Finalizar Plan",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            decoration: TextDecoration.none,
                            fontFamily: 'Inter-Regular',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Botón de cerrar
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(0),
                width: 35,
                height: 35,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: AppColors.blue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lógica al pulsar "Finalizar Plan"
  Future<void> _onCreatePlanPressed() async {
    try {
      final planId = DateTime.now().millisecondsSinceEpoch.toString();

      // Subir imágenes (recortadas y originales)
      final List<String> uploadedCroppedImages = [];
      final List<String> uploadedOriginalImages = [];

      for (int i = 0; i < _selectedCroppedImages.length; i++) {
        final croppedName = 'plan_backgrounds/${planId}_cropped_$i.png';
        final originalName = 'plan_backgrounds/${planId}_original_$i.png';

        final croppedUrl = await uploadImageToFirebase(
            _selectedCroppedImages[i], croppedName);
        final originalUrl = await uploadImageToFirebase(
            _selectedOriginalImages[i], originalName);

        if (croppedUrl != null) {
          uploadedCroppedImages.add(croppedUrl);
        }
        if (originalUrl != null) {
          uploadedOriginalImages.add(originalUrl);
        }
      }

      // Subir video
      String? uploadedVideo;
      if (_selectedVideo != null) {
        final videoUrl = await uploadVideo(_selectedVideo!, "${planId}_vid");
        if (videoUrl != null) {
          uploadedVideo = videoUrl;
        }
      }

      // Fecha/hora de inicio
      DateTime finalStartDateTime;
      if (_startDate != null) {
        finalStartDateTime = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
          _allDay ? 0 : (_startTime?.hour ?? 0),
          _allDay ? 0 : (_startTime?.minute ?? 0),
        );
      } else {
        final now = DateTime.now();
        finalStartDateTime = DateTime(now.year, now.month, now.day, 0, 0);
      }

      // Fecha/hora de fin
      DateTime finalFinishDateTime;
      if (_includeEndDate && _endDate != null) {
        finalFinishDateTime = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          _allDay ? 0 : (_endTime?.hour ?? 0),
          _allDay ? 0 : (_endTime?.minute ?? 0),
        );
      } else {
        finalFinishDateTime = DateTime(
          finalStartDateTime.year,
          finalStartDateTime.month,
          finalStartDateTime.day + 1,
          0,
          0,
        );
      }

      // Creamos el plan en Firestore (ver PlanModel.createPlan).
      // Pasamos las imágenes recortadas y las originales:
      await PlanModel.createPlan(
        type: _customPlan ?? _selectedPlan ?? '',
        description: _planDescription ?? '',
        minAge: _ageRange.start.round(),
        maxAge: _ageRange.end.round(),
        maxParticipants: _maxParticipants,
        location: _location ?? '',
        latitude: _latitude,
        longitude: _longitude,
        startTimestamp: finalStartDateTime,
        finishTimestamp: finalFinishDateTime,
        backgroundImage:
            uploadedCroppedImages.isNotEmpty ? uploadedCroppedImages.first : null,
        visibility: _selectedVisibility,
        iconAsset: _selectedIconAsset,
        special_plan: 0,
        images: uploadedCroppedImages,
        originalImages: uploadedOriginalImages, // <-- nuevo
        videoUrl: uploadedVideo,
      );

      Navigator.pop(context);
    } catch (error) {
      print("Error al crear el plan: $error");
      _showErrorPopup("Ocurrió un error al crear el plan.");
    }
  }
}

/// Diálogo para seleccionar fecha/hora
class DateSelectionDialog extends StatefulWidget {
  final bool initialAllDay;
  final bool initialIncludeEndDate;
  final DateTime? initialStartDate;
  final TimeOfDay? initialStartTime;
  final DateTime? initialEndDate;
  final TimeOfDay? initialEndTime;

  const DateSelectionDialog({
    Key? key,
    required this.initialAllDay,
    required this.initialIncludeEndDate,
    required this.initialStartDate,
    required this.initialStartTime,
    required this.initialEndDate,
    required this.initialEndTime,
  }) : super(key: key);

  @override
  _DateSelectionDialogState createState() => _DateSelectionDialogState();
}

class _DateSelectionDialogState extends State<DateSelectionDialog> {
  late bool allDay;
  late bool includeEndDate;
  DateTime? startDate;
  TimeOfDay? startTime;
  DateTime? endDate;
  TimeOfDay? endTime;

  @override
  void initState() {
    super.initState();
    allDay = widget.initialAllDay;
    includeEndDate = widget.initialIncludeEndDate;
    startDate = widget.initialStartDate;
    startTime = widget.initialStartTime;
    endDate = widget.initialEndDate;
    endTime = widget.initialEndTime;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Todo el día
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Todo el día",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            allDay = !allDay;
                            if (allDay) {
                              startTime = null;
                            }
                          });
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: allDay ? AppColors.blue : Colors.grey.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Incluir fecha final
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Incluir fecha final",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            includeEndDate = !includeEndDate;
                            if (!includeEndDate) {
                              endDate = null;
                              endTime = null;
                            }
                          });
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: includeEndDate
                                ? AppColors.blue
                                : Colors.grey.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Fecha de inicio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Fecha de inicio",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _pickStartDate,
                            child: _buildFrostedGlassContainer(
                              startDate == null
                                  ? "dd/mm/yyyy"
                                  : _formatNumericDateOnly(startDate!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (!allDay)
                            GestureDetector(
                              onTap: _pickStartTime,
                              child: _buildFrostedGlassContainer(
                                startTime == null
                                    ? "hh:mm:ss"
                                    : _formatNumericTime(startTime!),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Fecha final
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Fecha final",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      includeEndDate
                          ? Row(
                              children: [
                                GestureDetector(
                                  onTap: _pickEndDate,
                                  child: _buildFrostedGlassContainer(
                                    endDate == null
                                        ? "dd/mm/yyyy"
                                        : _formatNumericDateOnly(endDate!),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: _pickEndTime,
                                  child: _buildFrostedGlassContainer(
                                    endTime == null
                                        ? "hh:mm:ss"
                                        : _formatNumericTime(endTime!),
                                  ),
                                ),
                              ],
                            )
                          : _buildFrostedGlassContainer("Sin elegir"),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'allDay': allDay,
                        'includeEndDate': includeEndDate,
                        'startDate': startDate,
                        'startTime': startTime,
                        'endDate': endDate,
                        'endTime': endTime,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                    ),
                    child: const Text(
                      "Aceptar",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text(
                      "Cancelar",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Formato dd/mm/yyyy
  String _formatNumericDateOnly(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return "$day/$month/$year";
  }

  /// Formato hh:mm:ss
  String _formatNumericTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute:00";
  }

  Widget _buildFrostedGlassContainer(String text) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: startDate == null || startDate!.isBefore(now) ? now : startDate!,
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        startDate = pickedDate;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() {
        startTime = pickedTime;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final firstPossibleDate =
        startDate != null && startDate!.isAfter(now) ? startDate! : now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: endDate == null || endDate!.isBefore(firstPossibleDate)
          ? firstPossibleDate
          : endDate!,
      firstDate: firstPossibleDate,
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        endDate = pickedDate;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: endTime ?? TimeOfDay.now(),
    );
    if (pickedTime != null) {
      // Verificamos que no sea anterior a la fecha/hora de inicio
      if (startDate != null && endDate != null) {
        final startDateTime = (allDay || startTime == null)
            ? DateTime(startDate!.year, startDate!.month, startDate!.day)
            : DateTime(
                startDate!.year,
                startDate!.month,
                startDate!.day,
                startTime!.hour,
                startTime!.minute,
              );
        final endDateTime = DateTime(
          endDate!.year,
          endDate!.month,
          endDate!.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        if (!endDateTime.isAfter(startDateTime)) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Error"),
              content: const Text(
                "La fecha final debe ser posterior a la fecha/hora de inicio.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Aceptar"),
                ),
              ],
            ),
          );
          return;
        }
      }
      setState(() {
        endTime = pickedTime;
      });
    }
  }
}

/// ---------------------------------------------------------------------------
/// Pantalla interna para mostrar la imagen original y permitir recortar de nuevo
/// ---------------------------------------------------------------------------
class _PreviewAndRecropScreen extends StatefulWidget {
  final Uint8List originalImage;
  final Uint8List croppedImage;

  const _PreviewAndRecropScreen({
    Key? key,
    required this.originalImage,
    required this.croppedImage,
  }) : super(key: key);

  @override
  State<_PreviewAndRecropScreen> createState() => _PreviewAndRecropScreenState();
}

class _PreviewAndRecropScreenState extends State<_PreviewAndRecropScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Vista previa"),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.crop),
            onPressed: () async {
              // Reabrir el cropper con la imagen original
              final newCropped = await Navigator.push<Uint8List>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ImageCropperScreen(imageData: widget.originalImage),
                ),
              );
              if (newCropped != null) {
                Navigator.pop(context, newCropped);
              }
            },
          )
        ],
      ),
      body: InteractiveViewer(
        child: Center(
          child: Image.memory(widget.originalImage, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Pantalla para visualizar **varias** imágenes originales en fullscreen con swipe
/// (Se usará desde el FrostedPlanDialog)
/// ---------------------------------------------------------------------------
class _FullScreenImageViewer extends StatefulWidget {
  final List<String> originalImages;
  final int initialIndex;

  const _FullScreenImageViewer({
    Key? key,
    required this.originalImages,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        title: Text(
          "${_currentIndex + 1} / ${widget.originalImages.length}",
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.originalImages.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final imageUrl = widget.originalImages[index];
          return InteractiveViewer(
            child: Center(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}
