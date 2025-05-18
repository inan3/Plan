import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../main/colors.dart'; // Define AppColors
import '../../main/keys.dart';   // Contiene las claves APIKeys.androidApiKey y APIKeys.iosApiKey
import '../../utils/plans_list.dart'; // Lista de planes

// El diálogo acepta opcionalmente filtros iniciales para preservar el último estado.
class ExploreScreenFilterDialog extends StatefulWidget {
  final Map<String, dynamic>? initialFilters;
  const ExploreScreenFilterDialog({Key? key, this.initialFilters}) : super(key: key);

  @override
  _ExploreScreenFilterDialogState createState() =>
      _ExploreScreenFilterDialogState();
}

class _ExploreScreenFilterDialogState extends State<ExploreScreenFilterDialog>
    with SingleTickerProviderStateMixin {
  String planBusqueda = '';
  String? _selectedPlan;
  String? _customPlan;
  String? _selectedIconAsset;
  IconData? _selectedIconData;

  String regionBusqueda = '';
  final TextEditingController _regionController = TextEditingController();
  final FocusNode _regionFocusNode = FocusNode();
  List<dynamic> _regionPredictions = [];

  bool locationAllowed = false;
  RangeValues edadRange = const RangeValues(18, 60);
  int generoSeleccionado = 2;

  // Posición del usuario para cálculos internos
  Position? _userPosition;

  late AnimationController _animationController;

  final LayerLink _layerLink = LayerLink();
  final GlobalKey _dropdownKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isDropdownOpen = false;

  static const double _dropdownWidth = 260;

  @override
  void initState() {
    super.initState();
    // Si existen filtros iniciales, se cargan
    if (widget.initialFilters != null) {
      final init = widget.initialFilters!;
      planBusqueda = init['planBusqueda'] ?? '';
      _selectedPlan = init['planPredeterminado'];
      _selectedIconAsset = init['planIcon']; // Se carga el icono si existe
      regionBusqueda = init['regionBusqueda'] ?? '';
      edadRange = RangeValues(
        (init['edadMin'] ?? 18).toDouble(),
        (init['edadMax'] ?? 60).toDouble(),
      );
      generoSeleccionado = init['genero'] ?? 2;
      if (init['userCoordinates'] != null) {
        _userPosition = Position(
          latitude: init['userCoordinates']['lat'],
          longitude: init['userCoordinates']['lng'],
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
          floor: 0,
        );
        _regionController.text = regionBusqueda;
      }
    }
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _regionFocusNode.addListener(() {
      if (!_regionFocusNode.hasFocus) {
        setState(() {
          _regionPredictions = [];
        });
        if (_regionController.text.isNotEmpty) {
          _updateUserCoordinatesFromAddress(_regionController.text);
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _regionController.dispose();
    _regionFocusNode.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  Future<void> _updateUserCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        setState(() {
          _userPosition = Position(
            latitude: locations.first.latitude,
            longitude: locations.first.longitude,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
            floor: 0,
          );
        });
      }
    } catch (e) {
      debugPrint("Error al convertir dirección a coordenadas: $e");
    }
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = _dropdownKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    return OverlayEntry(
      builder: (context) => Positioned(
        width: _dropdownWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 5),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
                    border: Border.all(
                      color: const Color.fromARGB(255, 151, 121, 215),
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: plans.map<Widget>((plan) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPlan = plan['name'];
                              _selectedIconAsset = plan['icon'];
                              _customPlan = null;
                            });
                            _toggleDropdown();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                if (plan['icon'] != null)
                                  SvgPicture.asset(
                                    plan['icon'],
                                    width: 28,
                                    height: 28,
                                    color: Colors.white,
                                  ),
                                if (plan['icon'] != null)
                                  const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    plan['name'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Inter-Regular',
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleDropdown() {
    if (_isDropdownOpen) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    } else {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context)?.insert(_overlayEntry!);
    }
    setState(() {
      _isDropdownOpen = !_isDropdownOpen;
    });
  }

  Future<void> _obtenerUbicacion() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _userPosition = position;
      });
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        String address = "${placemark.street ?? ''} ${placemark.subThoroughfare ?? ''}, ${placemark.thoroughfare ?? ''}, ${placemark.postalCode ?? ''}, ${placemark.locality ?? ''}, ${placemark.country ?? ''}";
        setState(() {
          regionBusqueda = address;
          _regionController.text = address;
          _regionPredictions = [];
        });
      }
    } catch (e) {
      debugPrint("Error al obtener ubicación: $e");
    }
  }

  Future<void> _requestLocationPermission() async {
    PermissionStatus status = await Permission.location.request();

    if (status.isGranted) {
      setState(() {
        locationAllowed = true;
      });
      _obtenerUbicacion();
    } else if (status.isPermanentlyDenied) {
      setState(() {
        locationAllowed = false;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permiso de ubicación'),
          content: const Text('El permiso de ubicación ha sido denegado permanentemente. Ve a la configuración de la app para habilitarlo.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Configuración'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        locationAllowed = false;
      });
    }
  }

  Future<void> _fetchRegionPredictions(String input) async {
    if (input.isEmpty) {
      setState(() {
        _regionPredictions = [];
      });
      return;
    }

    final String key = Platform.isAndroid ? APIKeys.androidApiKey : APIKeys.iosApiKey;
    final String url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$key&language=es';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _regionPredictions = data['predictions'];
          });
        } else {
          debugPrint('Error en la API de Google Places: ${data['status']}');
        }
      } else {
        debugPrint('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error al obtener predicciones: $e');
    }
  }

  void _onRegionPredictionTap(dynamic prediction) {
    setState(() {
      regionBusqueda = prediction['description'];
      _regionController.text = regionBusqueda;
      _regionPredictions = [];
    });
    _updateUserCoordinatesFromAddress(regionBusqueda);
  }

  // Al aplicar filtros se devuelve un mapa que incluye:
  // - planBusqueda o planPredeterminado (para filtrar plan)
  // - regionBusqueda (texto a mostrar)
  // - edadMin, edadMax, genero y userCoordinates (para cálculos internos)
  void _aplicarFiltros() {
    Navigator.of(context).pop({
      'planBusqueda': planBusqueda,
      'planPredeterminado': _selectedPlan,
      'planIcon': _selectedIconAsset, // Se incluye el icono asociado
      'regionBusqueda': regionBusqueda,
      'edadMin': edadRange.start,
      'edadMax': edadRange.end,
      'genero': generoSeleccionado,
      'userCoordinates': _userPosition != null
          ? {
              'lat': _userPosition!.latitude,
              'lng': _userPosition!.longitude,
            }
          : null,
    });
  }

  // Función para limpiar los filtros de tipo de plan, dirección y rango de edades.
  void _limpiarFiltros() {
    setState(() {
      planBusqueda = '';
      _selectedPlan = null;
      _selectedIconAsset = null;
      _customPlan = null;
      regionBusqueda = '';
      _regionController.clear();
      edadRange = const RangeValues(18, 60);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> planSugeridos = planBusqueda.isNotEmpty
        ? plans.where((plan) {
            final nombre = plan['name'].toString().toLowerCase();
            return nombre.contains(planBusqueda.toLowerCase());
          }).toList()
        : [];

    final textStyle = const TextStyle(color: Colors.white, fontSize: 14);
    final textPainter = TextPainter(
      text: TextSpan(text: _regionController.text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final double minWidth = _dropdownWidth;
    final double dynamicWidth = textPainter.size.width + 48;
    final double regionFieldWidth = max(minWidth, dynamicWidth);

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.translucent,
      child: Center(
        child: GestureDetector(
          onTap: () {},
          behavior: HitTestBehavior.opaque,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 68, 66, 66).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          final animValue = _animationController.value;
                          return ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return LinearGradient(
                                colors: [AppColors.blue, Colors.white, AppColors.blue],
                                stops: [
                                  (animValue - 0.1).clamp(0.0, 1.0),
                                  animValue.clamp(0.0, 1.0),
                                  (animValue + 0.1).clamp(0.0, 1.0),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.srcIn,
                            child: const Text(
                              'Filtrar Planes',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(
                        color: Colors.white,
                        thickness: 0.2,
                        height: 20,
                      ),
                      CompositedTransformTarget(
                        key: _dropdownKey,
                        link: _layerLink,
                        child: GestureDetector(
                          onTap: _toggleDropdown,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                width: _dropdownWidth,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
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
                                      color: Color.fromARGB(255, 227, 225, 231),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '- o -',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: _dropdownWidth,
                        child: TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.2),
                            hintText: 'Busca por nombre...',
                            hintStyle: const TextStyle(
                              color: Color.fromARGB(255, 207, 193, 193),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              planBusqueda = value;
                            });
                          },
                        ),
                      ),
                      if (planBusqueda.isNotEmpty && planSugeridos.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          width: _dropdownWidth,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
                            border: Border.all(
                              color: const Color.fromARGB(255, 151, 121, 215),
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: planSugeridos.map((plan) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedPlan = plan['name'];
                                    _selectedIconAsset = plan['icon'];
                                    _customPlan = null;
                                    planBusqueda = '';
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      if (plan['icon'] != null)
                                        SvgPicture.asset(
                                          plan['icon'],
                                          width: 28,
                                          height: 28,
                                          color: Colors.white,
                                        ),
                                      if (plan['icon'] != null)
                                        const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          plan['name'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Inter-Regular',
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      const Divider(
                        color: Colors.white,
                        thickness: 0.2,
                        height: 20,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '¿En qué región buscas planes?',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: _dropdownWidth,
                          maxWidth: regionFieldWidth,
                        ),
                        child: TextField(
                          focusNode: _regionFocusNode,
                          controller: _regionController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: null,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.2),
                            hintText: 'Ciudad, país...',
                            hintStyle: const TextStyle(
                              color: Color.fromARGB(255, 207, 193, 193),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            prefixIcon: const Icon(
                              Icons.my_location,
                              color: Color.fromARGB(255, 175, 173, 173),
                            ),
                            suffixIcon: _regionController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _regionController.clear();
                                        regionBusqueda = '';
                                        _regionPredictions = [];
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onEditingComplete: () {
                            if (_regionController.text.isNotEmpty) {
                              _updateUserCoordinatesFromAddress(_regionController.text);
                            }
                          },
                          onChanged: (value) {
                            setState(() {
                              regionBusqueda = value;
                            });
                            _fetchRegionPredictions(value);
                          },
                        ),
                      ),
                      if (_regionPredictions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          width: _dropdownWidth,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
                            border: Border.all(
                              color: const Color.fromARGB(255, 151, 121, 215),
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: _regionPredictions.map((prediction) {
                              return ListTile(
                                title: Text(
                                  prediction['description'],
                                  style: const TextStyle(color: Colors.white),
                                ),
                                onTap: () => _onRegionPredictionTap(prediction),
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          '- o -',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: locationAllowed ? AppColors.blue : AppColors.blue.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _requestLocationPermission,
                        child: const Text(
                          'Tu ubicación actual',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Divider(
                        color: Colors.white,
                        thickness: 0.2,
                        height: 20,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '¿Qué rango de edad?',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: RangeSlider(
                              values: edadRange,
                              min: 18,
                              max: 100,
                              divisions: 82,
                              activeColor: AppColors.blue,
                              inactiveColor: Colors.white.withOpacity(0.3),
                              onChanged: (RangeValues values) {
                                setState(() {
                                  edadRange = values;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "${edadRange.start.round()} - ${edadRange.end.round()}",
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Botón de Limpiar Filtro
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _limpiarFiltros,
                        child: const Text(
                          'Limpiar Filtro',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(color: Colors.white),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.blue,
                            ),
                            onPressed: _aplicarFiltros,
                            child: const Text(
                              'Aceptar',
                              style: TextStyle(color: Colors.white),
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
      ),
    );
  }
}

Future<Map<String, dynamic>?> showExploreFilterDialog(BuildContext context,
    {Map<String, dynamic>? initialFilters}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: true,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: ExploreScreenFilterDialog(initialFilters: initialFilters),
    ),
  );
}
