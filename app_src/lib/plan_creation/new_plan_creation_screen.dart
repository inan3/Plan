import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async'; // Para usar Timer
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../main/colors.dart';
import '../models/plan_model.dart';
import 'image_cropper_screen.dart';
import 'meeting_location_screen.dart';
import '../utils/plans_list.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../explore_screen/users_grid/users_grid_helpers.dart';


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
  final ui.Picture picture =
      svgDrawableRoot.toPicture(size: Size(width, height));
  final ui.Image image =
      await picture.toImage(width.toInt(), height.toInt());
  final ByteData? bytes =
      await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
}

/// Función para subir imagen (PNG/JPG) a Firebase Storage y obtener la URL de descarga.
Future<String?> uploadImageToFirebase(Uint8List imageData, String fileName) async {
  try {
    final ref = FirebaseStorage.instance.ref().child(fileName);
    await ref.putData(imageData);
    String downloadURL = await ref.getDownloadURL();
    return downloadURL;
  } catch (error) {
    return null;
  }
}


///
/// [NewPlanCreationScreen.showPopup] soporta MODO EDICIÓN o CREACIÓN
/// al recibir [planToEdit] y [isEditMode].
///
class NewPlanCreationScreen {
  static void showPopup(
    BuildContext context, {
    PlanModel? planToEdit,
    bool isEditMode = false,
  }) {
    final t = AppLocalizations.of(context);
    showGeneralDialog(
      context: context,
      barrierLabel: t.newPlan,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return Material(
          type: MaterialType.transparency,
          child: Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.9,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromARGB(255, 13, 32, 53),
                    Color.fromARGB(255, 72, 38, 38),
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
                // Se pasa al widget interno el plan a editar y la info del modo
                child: _NewPlanPopupContent(
                  planToEdit: planToEdit,
                  isEditMode: isEditMode,
                ),
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
  final PlanModel? planToEdit;
  final bool isEditMode;

  const _NewPlanPopupContent({
    Key? key,
    this.planToEdit,
    this.isEditMode = false,
  }) : super(key: key);

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

  static const double _planButtonWidth = 260.0;
  static const double _dropdownWidth = 320.0;
  static const double _dropdownOffsetY = 44.0;
  static const double _dropdownOffsetX = -18;

  // Fecha y hora
  bool _includeEndDate = false;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  // Ubicación
  String? _location;
  double? _latitude;
  double? _longitude;

  // Sección de "fondo del plan": solo 1 imagen
  final List<Uint8List> _selectedCroppedImages = [];
  final List<Uint8List> _selectedOriginalImages = [];

  // Para el carrusel de imágenes
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

  // Marcador en el mapa
  Future<BitmapDescriptor>? _markerIconFuture;

  // Para controlar el popup de visibilidad (y cerrarlo automáticamente)
  Timer? _visibilityTimer;

  // Para estilo
  double headerHorizontalInset = 0;
  double fieldsHorizontalInset = 20;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // -----------------------------------------------------------------------
    // MODO EDICIÓN: Si hay un planToEdit, cargamos sus valores a los campos
    // -----------------------------------------------------------------------
    if (widget.isEditMode && widget.planToEdit != null) {
      final plan = widget.planToEdit!;

      // TYPE
      if (plan.type.isNotEmpty) {
        // Si el tipo de plan coincide con la lista local, lo asignas a _selectedPlan
        // de lo contrario, podrías ponerlo en _customPlan
        _selectedPlan = plan.type;
        // O: _customPlan = plan.type;
      }
      _selectedIconAsset = plan.iconAsset;

      // AGES
      _ageRange = RangeValues(plan.minAge.toDouble(), plan.maxAge.toDouble());

      // TIMESTAMPS
      if (plan.startTimestamp != null) {
        _startDate = plan.startTimestamp;
        _startTime = TimeOfDay.fromDateTime(plan.startTimestamp!);
      }
      if (plan.finishTimestamp != null) {
        _endDate = plan.finishTimestamp;
        _endTime = TimeOfDay.fromDateTime(plan.finishTimestamp!);
        _includeEndDate = true;
      }

      // LOCATION
      _location = plan.location;
      _latitude = plan.latitude;
      _longitude = plan.longitude;

      // MAX PARTICIPANTS
      _maxParticipants = plan.maxParticipants;

      // DESCRIPTION
      _planDescription = plan.description;

      // VISIBILITY
      _selectedVisibility = plan.visibility ?? "Público";
    }
  }

  // Cantidad de contenidos (imágenes recortadas)
  int get totalMedia => _selectedCroppedImages.length;

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
            offset: const Offset(_dropdownOffsetX, _dropdownOffsetY),
            child: _buildDropdownMenu(),
          ),
        ],
      ),
    );
  }

  /// Menú desplegable de planes + campo custom
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
            width: _dropdownWidth,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 165, 159, 159).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    alignment: WrapAlignment.start,
                    runAlignment: WrapAlignment.start,
                    spacing: 6,
                    runSpacing: 6,
                    children: plans.map((plan) {
                      final String lang =
                          AppLocalizations.of(context).locale.languageCode;
                      final String name = lang == 'en'
                          ? (plan['name_en'] ?? plan['name'])
                          : plan['name'];
                      final bool selected = _selectedPlan == name;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedPlan = name;
                            _customPlan = null;
                          });
                          _closeDropdown();
                        },
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.planColor
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Text(
                            name,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.white,
                              fontFamily: 'Inter-Regular',
                              fontSize: 14,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppLocalizations.of(context).orSeparator,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        _customPlan = value;
                        if (value.isNotEmpty) {
                          _selectedPlan = null;
                        }
                      });
                    },
                    style: const TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.none,
                      fontFamily: 'Inter-Regular',
                    ),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).writePlanHint,
                      hintStyle: const TextStyle(
                        color: Colors.white70,
                        decoration: TextDecoration.none,
                        fontFamily: 'Inter-Regular',
                      ),
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.8)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.8)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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

  /// Popup para subir la imagen
  void _showMediaSelectionPopup() {
    final t = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.2),
      builder: (_) {
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
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: Colors.blue),
                    title: Text(t.takePhoto),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
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

  /// Elegir imagen y recortarla
  Future<void> _pickImage(ImageSource source) async {
    final t = AppLocalizations.of(context);
    if (_selectedCroppedImages.length >= 1) {
      _showErrorPopup(t.onlyOneImage);
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
          builder: (_) => ImageCropperScreen(imageData: originalImageData),
        ),
      );
      if (croppedData != null) {
        setState(() {
          _selectedCroppedImages.add(croppedData);
          _selectedOriginalImages.add(originalImageData);
        });
      }
    }
  }


  /// Error popup
  void _showErrorPopup(String message) {
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.attention),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.ok),
          )
        ],
      ),
    );
  }

  /// Muestra un dialog para configurar las fechas
  Future<void> _showDateSelectionPopup() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DateSelectionDialog(
        initialIncludeEndDate: _includeEndDate,
        initialStartDate: _startDate,
        initialStartTime: _startTime,
        initialEndDate: _endDate,
        initialEndTime: _endTime,
      ),
    );
    if (result != null) {
      setState(() {
        _includeEndDate = result['includeEndDate'] as bool;
        _startDate = result['startDate'] as DateTime?;
        _startTime = result['startTime'] as TimeOfDay?;
        _endDate = result['endDate'] as DateTime?;
        _endTime = result['endTime'] as TimeOfDay?;
      });
    }
  }

  /// Seleccionar ubicación
  void _navigateToMeetingLocation() {
    // Creación de un plan temporal con la ubicación ya seleccionada
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

    final t = AppLocalizations.of(context);
    showGeneralDialog(
      context: context,
      barrierLabel: t.meetingLocation,
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

  /// Cargar el ícono SVG coloreado como marker
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

  /// Vista de la sección de ubicación
  Widget _buildLocationSelectionArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),
        Center(
          child: Text(
            AppLocalizations.of(context).meetingPoint,
            textAlign: TextAlign.center,
            style: const TextStyle(
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
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final icon = snap.hasData
                                ? snap.data!
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
                              _location ?? '',
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
                        color: const Color.fromARGB(255, 124, 120, 120)
                            .withOpacity(0.2),
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

  /// Formato para fecha en texto
  String _formatHumanReadableDateOnly(DateTime date) {
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat('EEEE, d MMMM y', locale).format(date);
  }

  String _formatHumanReadableTime(TimeOfDay time) {
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  Widget _buildSelectedDatesPreview() {
    if (_startDate == null) return const SizedBox.shrink();
    final startDateText = _formatHumanReadableDateOnly(_startDate!);
    final startTimeText = _startTime == null
        ? ''
        : "a las ${_formatHumanReadableTime(_startTime!)}";

    Widget? endDateWidget;
    if (_includeEndDate && _endDate != null) {
      final endDateText = _formatHumanReadableDateOnly(_endDate!);
      final endTimeText = _endTime == null
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
            TextSpan(text: AppLocalizations.of(context).until + ' '),
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
              if (_startTime != null) ...[
                const TextSpan(text: " "),
                TextSpan(
                  text: startTimeText,
                  style: const TextStyle(
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

  /// Container con la info de fecha/hora seleccionada
  Widget _buildDateSelectionArea() {
    return GestureDetector(
      onTap: _showDateSelectionPopup,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              AppLocalizations.of(context).planDateTime,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
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

  /// Al pulsar una imagen recortada: preview y recorte adicional
  void _onTapCroppedImage(int index) async {
    final result = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(
        builder: (_) => _PreviewAndRecropScreen(
          originalImage: _selectedOriginalImages[index],
          croppedImage: _selectedCroppedImages[index],
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedCroppedImages[index] = result;
      });
    }
  }

  /// Carrusel para la imagen recortada
  Widget _buildMediaCarousel() {
    return Stack(
      children: [
        Positioned.fill(
          child: PageView.builder(
            controller: _pageController,
            itemCount: totalMedia,
            onPageChanged: (index) {
              setState(() => _currentPageIndex = index);
            },
            itemBuilder: (context, index) {
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
            },
          ),
        ),
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
        Positioned(
          top: 10,
          right: 10,
          child: _buildDeleteMediaButton(),
        ),
      ],
    );
  }

  /// Botón para añadir la imagen
  Widget _buildAddMediaButton() {
    if (_selectedCroppedImages.length >= 1) return const SizedBox.shrink();
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

  /// Botón para eliminar la imagen cargada
  Widget _buildDeleteMediaButton() {
    if (_selectedCroppedImages.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _deleteSelectedMedia,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            color: const ui.Color.fromARGB(255, 96, 94, 94).withOpacity(0.2),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  /// Limpia las imágenes seleccionadas
  void _deleteSelectedMedia() {
    setState(() {
      _selectedCroppedImages.clear();
      _selectedOriginalImages.clear();
      _currentPageIndex = 0;
    });
  }

  /// Bloque para la sección multimedia
  Widget _buildImageAndVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Center(
          child: Text(
            widget.isEditMode
                ? AppLocalizations.of(context).editMedia
                : AppLocalizations.of(context).mediaContent,
            textAlign: TextAlign.center,
            style: const TextStyle(
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
                    GestureDetector(
                      onTap: _showMediaSelectionPopup,
                      child: ClipRRect(
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

  /// Bloque principal
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
                // Encabezado / Banner
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
                      // Título
                      Text(
                        widget.isEditMode
                            ? AppLocalizations.of(context).editPlanTitle
                            : AppLocalizations.of(context).sharePlanTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Inter-Regular',
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tipo de plan (desplegable + custom)
                      CompositedTransformTarget(
                        link: _layerLink,
                        child: GestureDetector(
                          onTap: _toggleDropdown,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                width: _planButtonWidth,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
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
                                      child: Text(
                                        _customPlan ??
                                            _selectedPlan ??
                                            AppLocalizations.of(context).chooseAPlan,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Inter-Regular',
                                          fontSize: 14,
                                          decoration: TextDecoration.none,
                                        ),
                                        overflow: TextOverflow.ellipsis,
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

                      // Sección imagen
                      _buildImageAndVideoSection(),
                      const SizedBox(height: 20),

                      // Sección Fecha/hora
                      _buildDateSelectionArea(),
                      const SizedBox(height: 20),

                      // Ubicación
                      _buildLocationSelectionArea(),
                      const SizedBox(height: 20),

                      // Restricción de edad
                      Text(
                        AppLocalizations.of(context).ageRestriction,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
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
                                activeTrackColor: AppColors.planColor,
                                inactiveTrackColor:
                                    const Color.fromARGB(235, 225, 225, 234)
                                        .withOpacity(0.3),
                                trackHeight: 1,
                                thumbColor: AppColors.planColor,
                                overlayColor: AppColors.planColor.withOpacity(0.2),
                                thumbShape:
                                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                                overlayShape:
                                    const RoundSliderOverlayShape(overlayRadius: 24),
                              ),
                              child: RangeSlider(
                                values: _ageRange,
                                min: 18,
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
                              AppLocalizations.of(context).planAgeRange(
                                  _ageRange.start.round(),
                                  _ageRange.end.round()),
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
                      Text(
                        AppLocalizations.of(context).maxParticipants,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Inter-Regular',
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 1,
                        ),
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
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  hintText: AppLocalizations.of(context).enterNumber,
                                  hintStyle: const TextStyle(
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
                      Text(
                        AppLocalizations.of(context).planDescription,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Inter-Regular',
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 124, 120, 120)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextField(
                          maxLines: 3,
                          onChanged: (value) => _planDescription = value,
                          controller: widget.isEditMode && widget.planToEdit != null
                              ? TextEditingController(text: _planDescription ?? '')
                              : null,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context).describePlan,
                            hintStyle: const TextStyle(
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
                      Text(
                        AppLocalizations.of(context).thisPlanIs,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
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
                              setState(() => _selectedVisibility = "Público");
                              _showVisibilityPopup(
                                AppLocalizations.of(context).publicPlanDesc,
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedVisibility == "Público"
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
                                  Text(
                                    AppLocalizations.of(context).public,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
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
                              setState(() => _selectedVisibility = "Privado");
                              _showVisibilityPopup(
                                AppLocalizations.of(context).privatePlanDesc,
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
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
                                  Text(
                                    AppLocalizations.of(context).private,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
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
                              setState(() =>
                                  _selectedVisibility = "Solo para mis seguidores");
                              _showVisibilityPopup(
                                AppLocalizations.of(context).followersPlanDesc,
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
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
                                  Text(
                                    AppLocalizations.of(context).onlyFollowers,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
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

                      // Botón: Finalizar o Actualizar
                      ElevatedButton(
                        onPressed: _onCreateOrUpdatePlanPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.planColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          widget.isEditMode
                              ? AppLocalizations.of(context).updatePlan
                              : AppLocalizations.of(context).createPlan,
                          style: const TextStyle(
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

          // Botón de cerrar (esquina)
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

  /// Muestra un popup con info sobre la visibilidad
  void _showVisibilityPopup(String message) {
    _visibilityTimer?.cancel();

    final t = AppLocalizations.of(context);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: t.visibilityInfo,
      barrierColor: Colors.black54,
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent,
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _visibilityTimer?.cancel();
    });

    _visibilityTimer = Timer(const Duration(seconds: 4), () {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    });
  }

  /// Crea o actualiza el plan dependiendo del isEditMode
  Future<void> _onCreateOrUpdatePlanPressed() async {
    try {
      // id único si es creación
      final planId = widget.isEditMode && widget.planToEdit != null
          ? widget.planToEdit!.id
          : DateTime.now().millisecondsSinceEpoch.toString();

      // Subir imágenes a Firebase
      final List<String> uploadedCroppedImages = [];
      final List<String> uploadedOriginalImages = [];

      for (int i = 0; i < _selectedCroppedImages.length; i++) {
        final croppedName = 'plan_backgrounds/${planId}_cropped_$i.png';
        final originalName = 'plan_backgrounds/${planId}_original_$i.png';

        final croppedUrl = await uploadImageToFirebase(
          _selectedCroppedImages[i],
          croppedName,
        );
        final originalUrl = await uploadImageToFirebase(
          _selectedOriginalImages[i],
          originalName,
        );

        if (croppedUrl != null) {
          uploadedCroppedImages.add(croppedUrl);
        }
        if (originalUrl != null) {
          uploadedOriginalImages.add(originalUrl);
        }
      }


      // Fecha/hora de inicio
      DateTime finalStartDateTime;
      if (_startDate != null && _startTime != null) {
        finalStartDateTime = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
          _startTime!.hour,
          _startTime!.minute,
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
          _endTime?.hour ?? 0,
          _endTime?.minute ?? 0,
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

      // Construir el tipo (custom o de la lista)
      final finalType = _customPlan ?? _selectedPlan ?? '';

      // -------------------------------------------------------------------
      // MODO EDICIÓN: Si isEditMode es true, se actualiza
      // -------------------------------------------------------------------
      if (widget.isEditMode && widget.planToEdit != null) {
        await PlanModel.updatePlan(
          planId,
          type: finalType,
          typeLowercase: finalType.toLowerCase(),
          description: _planDescription ?? '',
          minAge: _ageRange.start.round(),
          maxAge: _ageRange.end.round(),
          maxParticipants: _maxParticipants,
          location: _location ?? '',
          latitude: _latitude,
          longitude: _longitude,
          startTimestamp: finalStartDateTime,
          finishTimestamp: finalFinishDateTime,
          backgroundImage: uploadedCroppedImages.isNotEmpty
              ? uploadedCroppedImages.first
              : (widget.planToEdit!.backgroundImage ?? ''),
          visibility: _selectedVisibility,
          iconAsset: _selectedIconAsset,
          images: uploadedCroppedImages.isNotEmpty
              ? uploadedCroppedImages
              : (widget.planToEdit!.images ?? []),
          originalImages: uploadedOriginalImages.isNotEmpty
              ? uploadedOriginalImages
              : (widget.planToEdit!.originalImages ?? []),
          videoUrl: widget.planToEdit!.videoUrl,
        );
      } else {
        // -------------------------------------------------------------------
        // MODO CREACIÓN: crear un plan nuevo
        // -------------------------------------------------------------------
        await PlanModel.createPlan(
          type: finalType,
          typeLowercase: finalType.toLowerCase(),
          description: _planDescription ?? '',
          minAge: _ageRange.start.round(),
          maxAge: _ageRange.end.round(),
          maxParticipants: _maxParticipants,
          location: _location ?? '',
          latitude: _latitude,
          longitude: _longitude,
          startTimestamp: finalStartDateTime,
          finishTimestamp: finalFinishDateTime,
          backgroundImage: uploadedCroppedImages.isNotEmpty
              ? uploadedCroppedImages.first
              : null,
          visibility: _selectedVisibility,
          iconAsset: _selectedIconAsset,
          special_plan: 0,
          images: uploadedCroppedImages,
          originalImages: uploadedOriginalImages,
          videoUrl: null,
        );

        // Actualizar el estado de planes activos del usuario
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await PlanModel.updateUserHasActivePlan(user.uid);
        }
      }

      // Regresar y cerrar el popup
      Navigator.pop(context);
    } catch (error) {
      _showErrorPopup(AppLocalizations.of(context).planProcessError);
    }
  }
}

/// Popup de selección de fecha/hora (no cambia en modo edición)
class DateSelectionDialog extends StatefulWidget {
  final bool initialIncludeEndDate;
  final DateTime? initialStartDate;
  final TimeOfDay? initialStartTime;
  final DateTime? initialEndDate;
  final TimeOfDay? initialEndTime;

  const DateSelectionDialog({
    Key? key,
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
  late bool includeEndDate;
  DateTime? startDate;
  TimeOfDay? startTime;
  DateTime? endDate;
  TimeOfDay? endTime;

  @override
  void initState() {
    super.initState();
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 13, 32, 53),
                  Color.fromARGB(255, 72, 38, 38),
                  Color(0xFF12232E),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Incluir fecha final
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).includeEndDate,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Switch(
                        value: includeEndDate,
                        activeTrackColor: AppColors.planColor,
                        activeColor: Colors.white,
                        inactiveTrackColor: Colors.grey,
                        inactiveThumbColor: Colors.white,
                        onChanged: (value) {
                          setState(() {
                            includeEndDate = value;
                            if (!includeEndDate) {
                              endDate = null;
                              endTime = null;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Fecha de inicio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).startDate,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _pickStartDate,
                            child: _buildFrostedGlassContainer(
                              startDate == null
                                  ? AppLocalizations.of(context).chooseDate
                                  : _formatNumericDateOnly(startDate!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _pickStartTime,
                            child: _buildFrostedGlassContainer(
                              startTime == null
                                  ? AppLocalizations.of(context).chooseTime
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
                      Text(
                        AppLocalizations.of(context).endDate,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      includeEndDate
                          ? Row(
                              children: [
                                GestureDetector(
                                  onTap: _pickEndDate,
                                  child: _buildFrostedGlassContainer(
                                    endDate == null
                                        ? AppLocalizations.of(context).chooseDay
                                        : _formatNumericDateOnly(endDate!),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: _pickEndTime,
                                  child: _buildFrostedGlassContainer(
                                    endTime == null
                                        ? AppLocalizations.of(context).chooseTime
                                        : _formatNumericTime(endTime!),
                                  ),
                                ),
                              ],
                            )
                          : _buildFrostedGlassContainer(AppLocalizations.of(context).notSelected),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: Text(
                          AppLocalizations.of(context).cancel,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          if (startDate == null || startTime == null) {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(AppLocalizations.of(context).error),
                                content: Text(AppLocalizations.of(context).mustSelectStart),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(AppLocalizations.of(context).accept),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context, {
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
                        child: Text(
                          AppLocalizations.of(context).accept,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatNumericDateOnly(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return "$day/$month/$year";
  }

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
      initialDate:
          (startDate == null || startDate!.isBefore(now)) ? now : startDate!,
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() => startDate = pickedDate);
    }
  }

  Future<void> _pickStartTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() => startTime = pickedTime);
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final firstPossibleDate =
        startDate != null && startDate!.isAfter(now) ? startDate! : now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate:
          (endDate == null || endDate!.isBefore(firstPossibleDate))
              ? firstPossibleDate
              : endDate!,
      firstDate: firstPossibleDate,
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() => endDate = pickedDate);
    }
  }

  Future<void> _pickEndTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: endTime ?? TimeOfDay.now(),
    );
    if (pickedTime != null) {
      // Asegurarnos de que la fecha final sea posterior a la inicial
      if (startDate != null && startTime != null && endDate != null) {
        final startDateTime = DateTime(
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
            builder: (_) => AlertDialog(
              title: Text(AppLocalizations.of(context).error),
              content: Text(AppLocalizations.of(context).endAfterStartError),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context).accept),
                ),
              ],
            ),
          );
          return;
        }
      }
      setState(() => endTime = pickedTime);
    }
  }
}

/// Pantalla de Vista Previa de imagen y recorte adicional
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
        title: Text(AppLocalizations.of(context).preview),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.crop),
            onPressed: () async {
              // Reabrir el cropper con la imagen original
              final newCropped = await Navigator.push<Uint8List>(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageCropperScreen(
                    imageData: widget.originalImage,
                  ),
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

/// Pantalla fullscreen para ver imágenes originales
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
        title: Text("${_currentIndex + 1} / ${widget.originalImages.length}"),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.originalImages.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          final imageUrl = widget.originalImages[index];
          return InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) => const Icon(Icons.error),
              ),
            ),
          );
        },
      ),
    );
  }
}
