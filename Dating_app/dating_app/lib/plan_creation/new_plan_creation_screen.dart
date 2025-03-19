import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

/// Función para subir la imagen a Firebase Storage y obtener la URL de descarga.
Future<String?> uploadBackgroundImage(Uint8List imageData, String planId) async {
  try {
    final ref = FirebaseStorage.instance
        .ref()
        .child('plan_backgrounds/$planId.png');
    await ref.putData(imageData);
    String downloadURL = await ref.getDownloadURL();
    return downloadURL;
  } catch (error) {
    print('Error al subir la imagen: $error');
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
  // Paso 1: Elección del tipo de plan
  String? _selectedPlan;
  String? _customPlan;
  String? _selectedIconAsset;
  IconData? _selectedIconData;
  bool _isDropdownOpen = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  // Paso 3: Fecha y hora
  bool _allDay = false;
  bool _includeEndDate = false;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  // Paso 4: Ubicación
  String? _location;
  double? _latitude;
  double? _longitude;

  // Paso 2: Imagen de fondo
  Uint8List? _selectedImage;

  // Paso 5: Restricción de edad
  RangeValues _ageRange = const RangeValues(18, 60);

  // Paso 6: Máximo número de participantes
  int? _maxParticipants;

  // Paso 7: Breve descripción del plan
  String? _planDescription;

  // Paso 8: Visibilidad del plan
  String? _selectedVisibility;

  double headerHorizontalInset = 0;
  double fieldsHorizontalInset = 20;

  // Variable para el ícono del marcador
  Future<BitmapDescriptor>? _markerIconFuture;

  @override
  void initState() {
    super.initState();
  }

  /// Función para asignar (o reasignar) el Future del marcador personalizado.
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

  Widget _buildFrostedGlassContainer({required String text}) {
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
            style: const TextStyle(
              color: Colors.white,
              decoration: TextDecoration.none,
              fontFamily: 'Inter-Regular',
            ),
          ),
        ),
      ),
    );
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
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeDropdown,
            ),
          ),
          Positioned(
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 44),
              child: ClipRRect(
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
                        color: const Color.fromARGB(255, 165, 159, 159)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
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
                                  borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.8)),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.8)),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide:
                                      const BorderSide(color: Colors.white),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4.0),
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
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 4.0),
                                  dense: true,
                                  leading: SvgPicture.asset(
                                    plans[index]['icon'],
                                    width: 28,
                                    height: 28,
                                    color: const Color.fromARGB(
                                        235, 229, 229, 252),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndCropImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      final imageData = await pickedFile.readAsBytes();
      final croppedData = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageCropperScreen(imageData: imageData),
        ),
      );
      if (croppedData != null) {
        setState(() => _selectedImage = croppedData);
      }
    }
  }

  void _showImageSelectionPopup() {
    showGeneralDialog(
      context: context,
      barrierLabel: "Selecciona imagen",
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
                "Selecciona una imagen",
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
                  _pickAndCropImage(ImageSource.gallery);
                  Navigator.pop(context);
                },
                child: const Text(
                  "Desde la galería",
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.none,
                    fontFamily: 'Inter-Regular',
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  _pickAndCropImage(ImageSource.camera);
                  Navigator.pop(context);
                },
                child: const Text(
                  "Tomar una foto",
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

  void _showDateSelectionPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Opción 1: Todo el día
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Todo el día",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                decoration: TextDecoration.none,
                                fontFamily: 'Inter-Regular',
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setStateDialog(() {
                                  _allDay = !_allDay;
                                  if (_allDay) {
                                    _startTime = null;
                                  }
                                });
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: _allDay
                                      ? AppColors.blue
                                      : Colors.grey.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Opción 2: Incluir fecha final
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Incluir fecha final",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                decoration: TextDecoration.none,
                                fontFamily: 'Inter-Regular',
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setStateDialog(() {
                                  _includeEndDate = !_includeEndDate;
                                  if (!_includeEndDate) {
                                    _endDate = null;
                                    _endTime = null;
                                  }
                                });
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: _includeEndDate
                                      ? AppColors.blue
                                      : Colors.grey.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Opción 3: Fecha de inicio (fecha y hora)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Fecha de inicio",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                decoration: TextDecoration.none,
                                fontFamily: 'Inter-Regular',
                              ),
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    DateTime now = DateTime.now();
                                    DateTime? pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: _startDate == null ||
                                              _startDate!.isBefore(now)
                                          ? now
                                          : _startDate!,
                                      firstDate: now,
                                      lastDate: DateTime(2100),
                                    );
                                    if (pickedDate != null) {
                                      setStateDialog(() {
                                        _startDate = pickedDate;
                                      });
                                    }
                                  },
                                  child: _buildFrostedGlassContainer(
                                    text: _startDate == null
                                        ? "Seleccionar"
                                        : _startDate!
                                            .toLocal()
                                            .toString()
                                            .split(' ')[0],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (!_allDay)
                                  GestureDetector(
                                    onTap: () async {
                                      TimeOfDay? pickedTime =
                                          await showTimePicker(
                                        context: context,
                                        initialTime:
                                            _startTime ?? TimeOfDay.now(),
                                      );
                                      if (pickedTime != null) {
                                        setStateDialog(() {
                                          _startTime = pickedTime;
                                        });
                                      }
                                    },
                                    child: _buildFrostedGlassContainer(
                                      text: _startTime == null
                                          ? "Seleccionar"
                                          : _startTime!.format(context),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Opción 4: Fecha final (fecha y hora)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Fecha final",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                decoration: TextDecoration.none,
                                fontFamily: 'Inter-Regular',
                              ),
                            ),
                            _includeEndDate
                                ? Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () async {
                                          DateTime firstPossibleDate =
                                              _startDate != null &&
                                                      _startDate!
                                                          .isAfter(DateTime
                                                              .now())
                                                  ? _startDate!
                                                  : DateTime.now();
                                          DateTime? pickedDate =
                                              await showDatePicker(
                                            context: context,
                                            initialDate: _endDate == null ||
                                                    _endDate!
                                                        .isBefore(firstPossibleDate)
                                                ? firstPossibleDate
                                                : _endDate!,
                                            firstDate: firstPossibleDate,
                                            lastDate: DateTime(2100),
                                          );
                                          if (pickedDate != null) {
                                            setStateDialog(() {
                                              _endDate = pickedDate;
                                            });
                                          }
                                        },
                                        child: _buildFrostedGlassContainer(
                                          text: _endDate == null
                                              ? "Seleccionar"
                                              : _endDate!
                                                  .toLocal()
                                                  .toString()
                                                  .split(' ')[0],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                        onTap: () async {
                                          TimeOfDay? pickedTime =
                                              await showTimePicker(
                                            context: context,
                                            initialTime: _endTime ??
                                                TimeOfDay.now(),
                                          );
                                          if (pickedTime != null) {
                                            // Verificamos que fin sea posterior al inicio
                                            if (_startDate != null &&
                                                _endDate != null) {
                                              DateTime startDateTime = (_allDay ||
                                                      _startTime == null)
                                                  ? DateTime(
                                                      _startDate!.year,
                                                      _startDate!.month,
                                                      _startDate!.day)
                                                  : DateTime(
                                                      _startDate!.year,
                                                      _startDate!.month,
                                                      _startDate!.day,
                                                      _startTime!.hour,
                                                      _startTime!.minute);
                                              DateTime endDateTime =
                                                  DateTime(
                                                _endDate!.year,
                                                _endDate!.month,
                                                _endDate!.day,
                                                pickedTime.hour,
                                                pickedTime.minute,
                                              );
                                              if (!endDateTime
                                                  .isAfter(startDateTime)) {
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (context) =>
                                                          AlertDialog(
                                                    title:
                                                        const Text("Error"),
                                                    content: const Text(
                                                      "La fecha final debe ser posterior a la fecha y hora de inicio.",
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context),
                                                        child:
                                                            const Text("Aceptar"),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                return;
                                              }
                                            }
                                            setStateDialog(() {
                                              _endTime = pickedTime;
                                            });
                                          }
                                        },
                                        child: _buildFrostedGlassContainer(
                                          text: _endTime == null
                                              ? "Seleccionar"
                                              : _endTime!.format(context),
                                        ),
                                      ),
                                    ],
                                  )
                                : _buildFrostedGlassContainer(
                                    text: "Sin elegir",
                                  ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blue,
                          ),
                          child: const Text(
                            "Aceptar",
                            style: TextStyle(
                              decoration: TextDecoration.none,
                              color: Colors.white,
                              fontFamily: 'Inter-Regular',
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Popup de ubicación
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
          child: Container(
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
      } else {
        print("No se recibió plan actualizado");
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
                      child: Container(
                        height: 240,
                        width: double.infinity,
                        child: FutureBuilder<BitmapDescriptor>(
                          future: _markerIconFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
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
                    Positioned.fill(
                      child: Container(
                        color: Colors.transparent,
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
                        color:
                            const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
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

  int _countCompletedSteps() {
    int completed = 0;
    if (_selectedPlan != null || _customPlan != null) completed++;
    if (_selectedImage != null) completed++;
    // Para contar como completado, verificamos si al menos eligió fecha de inicio
    if (_startDate != null) completed++;
    if (_location != null && _location!.isNotEmpty) completed++;
    if (_ageRange != null) completed++;
    if (_maxParticipants != null && _maxParticipants! > 0) completed++;
    if (_planDescription != null && _planDescription!.isNotEmpty) completed++;
    if (_selectedVisibility != null) completed++;
    return completed;
  }

  Widget _buildVerticalProgressBar() {
    int completedSteps = _countCompletedSteps();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(8, (index) {
        final isCompleted = (index + 1) <= completedSteps;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          height: 15,
          width: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: isCompleted
                ? const LinearGradient(
                    colors: [Colors.blueAccent, Colors.blue],
                  )
                : null,
            color: isCompleted ? null : Colors.grey[300],
          ),
        );
      }),
    );
  }

  Widget _buildImageSelectionArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Center(
          child: Text(
            "Fondo del plan",
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
          onTap: _showImageSelectionPopup,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  color:
                      const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: _selectedImage == null
                      ? SvgPicture.asset(
                          'assets/anadir-imagen.svg',
                          width: 30,
                          height: 30,
                          color: Colors.white,
                        )
                      : Image.memory(
                          _selectedImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 240,
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  TextSpan _buildFormattedDateTextSpan(
    DateTime date, {
    TimeOfDay? time,
    bool allDay = false,
    bool isEndDate = false,
  }) {
    final String formattedDate =
        "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    final Map<int, String> weekdays = {
      1: "Lunes",
      2: "Martes",
      3: "Miércoles",
      4: "Jueves",
      5: "Viernes",
      6: "Sábado",
      7: "Domingo",
    };
    final String weekday = weekdays[date.weekday] ?? "";

    const TextStyle baseStyle = TextStyle(
      fontSize: 14,
      fontFamily: 'Inter-Regular',
      decoration: TextDecoration.none,
      color: Colors.white,
    );
    const TextStyle valueStyle = TextStyle(
      fontSize: 16,
      fontFamily: 'Inter-Regular',
      decoration: TextDecoration.none,
      color: Color.fromARGB(235, 155, 157, 251),
    );

    List<TextSpan> children = [];

    if (isEndDate) {
      children.add(const TextSpan(text: "Hasta ", style: baseStyle));
    }

    children.add(TextSpan(text: "$weekday, ", style: valueStyle));
    children.add(TextSpan(text: formattedDate, style: valueStyle));

    if (!isEndDate) {
      if (!allDay && time != null) {
        final String formattedTime =
            "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
        children.add(const TextSpan(text: " a las ", style: baseStyle));
        children.add(TextSpan(text: formattedTime, style: valueStyle));
      } else if (allDay) {
        children.add(const TextSpan(text: " todo el día", style: baseStyle));
      }
    } else {
      if (time != null) {
        final String formattedTime =
            "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
        children.add(const TextSpan(text: " a las ", style: baseStyle));
        children.add(TextSpan(text: formattedTime, style: valueStyle));
      }
    }

    return TextSpan(children: children, style: baseStyle);
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
                  color:
                      const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                        if (_startDate != null)
                          Column(
                            children: [
                              RichText(
                                textAlign: TextAlign.center,
                                text: _buildFormattedDateTextSpan(
                                  _startDate!,
                                  time: _allDay ? null : _startTime,
                                  allDay: _allDay,
                                ),
                              ),
                              if (_includeEndDate &&
                                  _endDate != null &&
                                  (_allDay || _endTime != null))
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: _buildFormattedDateTextSpan(
                                    _endDate!,
                                    time: _allDay ? null : _endTime,
                                    allDay: _allDay,
                                    isEndDate: true,
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
          ),
        ],
      ),
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
                      // Paso 1: Dropdown para seleccionar el tipo de plan
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
                                    color:
                                        const Color.fromARGB(255, 151, 121, 215),
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
                                              _customPlan ??
                                                  _selectedPlan ??
                                                  "Elige un plan",
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
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: ((_selectedPlan != null) || (_customPlan != null))
                            ? Column(
                                key: const ValueKey(1),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildImageSelectionArea(),
                                  if (_selectedImage != null) ...[
                                    const SizedBox(height: 20),
                                    _buildDateSelectionArea(),
                                  ],
                                  if (_startDate != null) ...[
                                    const SizedBox(height: 20),
                                    _buildLocationSelectionArea(),
                                  ],
                                  if (_location != null && _location!.isNotEmpty) ...[
                                    const SizedBox(height: 20),
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
                                        color: const Color.fromARGB(
                                                255, 124, 120, 120)
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Column(
                                        children: [
                                          SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              activeTrackColor: AppColors.blue,
                                              inactiveTrackColor:
                                                  const Color.fromARGB(
                                                          235, 225, 225, 234)
                                                      .withOpacity(0.3),
                                              trackHeight: 1,
                                              thumbColor: AppColors.blue,
                                              overlayColor:
                                                  AppColors.blue.withOpacity(0.2),
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                      enabledThumbRadius: 8),
                                              overlayShape:
                                                  const RoundSliderOverlayShape(
                                                      overlayRadius: 24),
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
                                              color:
                                                  Color.fromARGB(255, 223, 199, 199),
                                              fontSize: 14,
                                              decoration: TextDecoration.none,
                                              fontFamily: 'Inter-Regular',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color.fromARGB(
                                                255, 124, 120, 120)
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
                                                  _maxParticipants =
                                                      int.tryParse(value);
                                                });
                                              },
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        vertical: 8,
                                                        horizontal: 0),
                                                hintText: "Ingresa un número...",
                                                hintStyle: TextStyle(
                                                  color: Colors.white70,
                                                  fontFamily: 'Inter-Regular',
                                                  decoration:
                                                      TextDecoration.none,
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color.fromARGB(
                                                255, 124, 120, 120)
                                            .withOpacity(0.2),
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
                                          hintText:
                                              "Describe brevemente tu plan...",
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
                                              color: _selectedVisibility ==
                                                      "Publico"
                                                  ? AppColors.blue
                                                  : const Color.fromARGB(
                                                          255, 124, 120, 120)
                                                      .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
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
                                                    decoration:
                                                        TextDecoration.none,
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
                                              color: _selectedVisibility ==
                                                      "Privado"
                                                  ? AppColors.blue
                                                  : const Color.fromARGB(
                                                          255, 124, 120, 120)
                                                      .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
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
                                                    decoration:
                                                        TextDecoration.none,
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
                                              _selectedVisibility =
                                                  "Solo para mis seguidores";
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
                                                  : const Color.fromARGB(
                                                          255, 124, 120, 120)
                                                      .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
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
                                                    decoration:
                                                        TextDecoration.none,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 20),
                      // Botón de Finalizar Plan
                      if (_countCompletedSteps() == 8)
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              String? backgroundImageUrl;
                              // Si existe una imagen seleccionada, súbela a Firebase Storage
                              if (_selectedImage != null) {
                                final planId =
                                    DateTime.now().millisecondsSinceEpoch
                                        .toString();
                                backgroundImageUrl = await uploadBackgroundImage(
                                    _selectedImage!, planId);
                              }

                              // ================================
                              // LÓGICA PARA start_timestamp y finish_timestamp
                              // ================================
                              // Aseguramos fecha/hora de inicio
                              DateTime finalStartDateTime;
                              if (_startDate != null) {
                                finalStartDateTime = DateTime(
                                  _startDate!.year,
                                  _startDate!.month,
                                  _startDate!.day,
                                  // Si _allDay, asumimos 00:00
                                  _allDay ? 0 : (_startTime?.hour ?? 0),
                                  _allDay ? 0 : (_startTime?.minute ?? 0),
                                );
                              } else {
                                // En caso extremo de que no haya elegido nada
                                // asumimos "ahora" como la fecha de inicio
                                final now = DateTime.now();
                                finalStartDateTime = DateTime(
                                    now.year, now.month, now.day, 0, 0);
                              }

                              // Aseguramos fecha/hora de fin
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
                                // Si no incluyó fecha/hora final,
                                // ponemos 00:00 del siguiente día
                                finalFinishDateTime = DateTime(
                                  finalStartDateTime.year,
                                  finalStartDateTime.month,
                                  finalStartDateTime.day + 1,
                                  0,
                                  0,
                                );
                              }

                              // Creamos el plan en Firestore
                              await PlanModel.createPlan(
                                type: _customPlan ?? _selectedPlan!,
                                description: _planDescription ?? '',
                                minAge: _ageRange.start.round(),
                                maxAge: _ageRange.end.round(),
                                maxParticipants: _maxParticipants,
                                location: _location ?? '',
                                latitude: _latitude,
                                longitude: _longitude,

                                /// Pasamos nuestros timestamps calculados
                                startTimestamp: finalStartDateTime,
                                finishTimestamp: finalFinishDateTime,

                                backgroundImage: backgroundImageUrl,
                                visibility: _selectedVisibility,
                                iconAsset: _selectedIconAsset,
                                special_plan: 0, // Plan normal
                              );
                              Navigator.pop(context);
                            } catch (error) {
                              print("Error al crear el plan: $error");
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(235, 17, 19, 135),
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
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: Container(
              width: 2,
              alignment: Alignment.center,
              child: _buildVerticalProgressBar(),
            ),
          ),
        ],
      ),
    );
  }
}
