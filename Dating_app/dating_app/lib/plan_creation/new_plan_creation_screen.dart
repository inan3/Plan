import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // <--- Import necesario
import '../main/colors.dart';
import 'plan_description_screen.dart';
import '../models/plan_model.dart';
import 'image_cropper_screen.dart';
import 'meeting_location_screen.dart'; // Este fichero contiene MeetingLocationPopup

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
              child: Material( // <-- Material agregado aquí
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
  String? _selectedPlan;
  String? _customPlan;
  String? _selectedIconAsset;
  IconData? _selectedIconData;
  bool _isDropdownOpen = false;
  OverlayEntry? _overlayEntry;
  double _separatorSpacing = 20.0;
  final LayerLink _layerLink = LayerLink();
  DateTime? _selectedDateTime;
  bool _allDay = false;
  bool _includeEndDate = false;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  // Variables para la ubicación
  String? _location;
  double? _latitude;
  double? _longitude;
  String? _planDescription;
  Uint8List? _selectedImage;
  double headerHorizontalInset = 0;
  double fieldsHorizontalInset = 20;

  final List<Map<String, dynamic>> _plans = [
    {'icon': 'assets/icono-baile.svg', 'name': 'Baile'},
    {'icon': 'assets/icono-cena.svg', 'name': 'Cena'},
    {'icon': 'assets/icono-charla-seminario.svg', 'name': 'Charla o Seminario'},
    {'icon': 'assets/icono-cine.svg', 'name': 'Cine'},
    {'icon': 'assets/icono-concierto-musica.svg', 'name': 'Concierto o Música'},
    {'icon': 'assets/icono-deporte.svg', 'name': 'Deporte'},
    {'icon': 'assets/icono-excursion.svg', 'name': 'Excursión o Senderismo'},
    {'icon': 'assets/icono-fiesta.svg', 'name': 'Fiesta'},
    {'icon': 'assets/icono-juegos.svg', 'name': 'Juegos'},
    {'icon': 'assets/icono-tour-cultural.svg', 'name': 'Museo o Tour Cultural'},
    {'icon': 'assets/icono-sesion-estudio.svg', 'name': 'Sesión de Estudio'},
    {'icon': 'assets/icono-cafe.svg', 'name': 'Tomar algo'},
    {'icon': 'assets/icono-viaje.svg', 'name': 'Viaje'},
    {'icon': 'assets/icono-yoga.svg', 'name': 'Yoga o Relajación'},
  ];

  Widget _buildFrostedGlassContainer({required String text}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
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
                                  borderSide: const BorderSide(
                                      color: Colors.white, width: 1.5),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
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
                          Expanded(
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.zero,
                              itemCount: _plans.length,
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
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                  dense: true,
                                  leading: SvgPicture.asset(
                                    _plans[index]['icon'],
                                    width: 28,
                                    height: 28,
                                    color: const Color.fromARGB(235, 229, 229, 252),
                                  ),
                                  title: Text(
                                    _plans[index]['name'],
                                    style: const TextStyle(
                                      color: Color.fromARGB(255, 218, 207, 207),
                                      decoration: TextDecoration.none,
                                      fontFamily: 'Inter-Regular',
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _selectedPlan = _plans[index]['name'];
                                      _selectedIconAsset = _plans[index]['icon'];
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
                offset: const Offset(0, 5),
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
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                                      initialDate: _startDate == null || _startDate!.isBefore(now)
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
                                        : _startDate!.toLocal().toString().split(' ')[0],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (!_allDay)
                                  GestureDetector(
                                    onTap: () async {
                                      TimeOfDay? pickedTime = await showTimePicker(
                                        context: context,
                                        initialTime: _startTime ?? TimeOfDay.now(),
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
                                          DateTime firstPossibleDate = _startDate != null && _startDate!.isAfter(DateTime.now())
                                              ? _startDate!
                                              : DateTime.now();
                                          DateTime? pickedDate = await showDatePicker(
                                            context: context,
                                            initialDate: _endDate == null || _endDate!.isBefore(firstPossibleDate)
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
                                              : _endDate!.toLocal().toString().split(' ')[0],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                        onTap: () async {
                                          TimeOfDay? pickedTime = await showTimePicker(
                                            context: context,
                                            initialTime: _endTime ?? TimeOfDay.now(),
                                          );
                                          if (pickedTime != null) {
                                            if (_startDate != null && _endDate != null) {
                                              DateTime startDateTime;
                                              if (_allDay || _startTime == null) {
                                                startDateTime = DateTime(
                                                  _startDate!.year,
                                                  _startDate!.month,
                                                  _startDate!.day,
                                                );
                                              } else {
                                                startDateTime = DateTime(
                                                  _startDate!.year,
                                                  _startDate!.month,
                                                  _startDate!.day,
                                                  _startTime!.hour,
                                                  _startTime!.minute,
                                                );
                                              }
                                              DateTime endDateTime = DateTime(
                                                _endDate!.year,
                                                _endDate!.month,
                                                _endDate!.day,
                                                pickedTime.hour,
                                                pickedTime.minute,
                                              );
                                              if (!endDateTime.isAfter(startDateTime)) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: const Text("Error"),
                                                    content: const Text(
                                                      "La fecha final debe ser posterior a la fecha y hora de inicio.",
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
                                : _buildFrostedGlassContainer(text: "Sin elegir"),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedDateTime = _startDate;
                            });
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

  /// Función para abrir el popup de MeetingLocation y actualizar la ubicación
  void _navigateToMeetingLocation() {
    final plan = PlanModel(
      id: '',
      type: _customPlan ?? _selectedPlan ?? '',
      description: _planDescription ?? '',
      minAge: 0,
      maxAge: 0,
      location: _location ?? '',
      date: DateTime.now(),
      createdBy: '',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MeetingLocationPopup(plan: plan),
      ),
    ).then((updatedPlan) {
      if (updatedPlan != null && updatedPlan is PlanModel) {
        setState(() {
          _location = updatedPlan.location;
          _latitude = updatedPlan.latitude;
          _longitude = updatedPlan.longitude;
        });
      }
    });
  }

  /// Widget actualizado para la selección de ubicación:
  /// Si ya se ha elegido una ubicación (y se tienen coordenadas),
  /// se muestra un pequeño mapa con un overlay frosted glass que muestra la dirección.
  Widget _buildLocationSelectionArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          "Selecciona ubicación",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            decoration: TextDecoration.none,
            fontFamily: 'Inter-Regular',
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _navigateToMeetingLocation,
          child: _latitude != null && _longitude != null
              ? Stack(
                  children: [
                    Container(
                      height: 240,
                      width: double.infinity,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(_latitude!, _longitude!),
                          zoom: 16,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('selected'),
                            position: LatLng(_latitude!, _longitude!),
                          )
                        },
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        liteModeEnabled: true, // Vista simplificada
                        gestureRecognizers: {},
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
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      height: 240,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
                        border: Border.all(
                          color: const Color.fromARGB(255, 151, 121, 215),
                        ),
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
    if (_selectedDateTime != null) completed++;
    if (_location != null && _location!.isNotEmpty) completed++;
    return completed;
  }

  Widget _buildVerticalProgressBar() {
    int completedSteps = _countCompletedSteps();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (index) {
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

  // Función para construir el área de selección de imagen
  Widget _buildImageSelectionArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Text(
          "Selecciona un fondo que represente a tu Plan",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            decoration: TextDecoration.none,
            fontFamily: 'Inter-Regular',
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _showImageSelectionPopup,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
                  border: Border.all(
                    color: const Color.fromARGB(255, 151, 121, 215),
                  ),
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

  // Función para construir el área de selección de fecha
  Widget _buildDateSelectionArea() {
    return GestureDetector(
      onTap: _showDateSelectionPopup,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: _includeEndDate ? 120 : 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
              border: Border.all(
                color: const Color.fromARGB(255, 151, 121, 215),
              ),
              borderRadius: BorderRadius.circular(30),
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
                      Text(
                        _allDay
                            ? _startDate!.toLocal().toString().split(' ')[0]
                            : "${_startDate!.toLocal().toString().split(' ')[0]} ${_startTime != null ? _startTime!.format(context) : ''}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          decoration: TextDecoration.none,
                          fontFamily: 'Inter-Regular',
                        ),
                      ),
                      if (_includeEndDate && _endDate != null)
                        Text(
                          !_allDay && _endTime != null
                              ? "${_endDate!.toLocal().toString().split(' ')[0]} ${_endTime!.format(context)}"
                              : _endDate!.toLocal().toString().split(' ')[0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            decoration: TextDecoration.none,
                            fontFamily: 'Inter-Regular',
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material( // Se envuelve todo el contenido en un widget Material
      type: MaterialType.transparency,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(right: 5),
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
                        "¡Hazle saber a la gente el Plan que deseas compartir!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Inter-Regular',
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 20),
                      CompositedTransformTarget(
                        link: _layerLink,
                        child: GestureDetector(
                          onTap: _toggleDropdown,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                width: 260,
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
                                          if (_selectedIconAsset != null || _selectedIconData != null)
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
                                      color: AppColors.blue,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: ((_selectedPlan != null) || (_customPlan != null))
                            ? Column(
                                key: const ValueKey(1),
                                children: [
                                  const SizedBox(height: 20),
                                  _buildImageSelectionArea(),
                                  const SizedBox(height: 20),
                                  _buildLocationSelectionArea(),
                                  const SizedBox(height: 20),
                                  Container(
                                    height: 1,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildDateSelectionArea(),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 20),
                      if (_planDescription != null && _planDescription!.isNotEmpty)
                        ElevatedButton(
                          onPressed: () {
                            final plan = PlanModel(
                              id: '',
                              type: _customPlan ?? _selectedPlan!,
                              description: _planDescription ?? '',
                              minAge: 0,
                              maxAge: 0,
                              location: _location ?? '',
                              date: DateTime.now(),
                              createdBy: '',
                            );
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlanDescriptionScreen(plan: plan),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blue,
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
