import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../main/colors.dart'; // Define AppColors
import '../../main/keys.dart'; // Contiene las claves APIKeys.androidApiKey y APIKeys.iosApiKey
import '../../utils/plans_list.dart'; // Lista de planes

// El diálogo acepta opcionalmente filtros iniciales para preservar el último estado.
class ExploreScreenFilterDialog extends StatefulWidget {
  final Map<String, dynamic>? initialFilters;
  final bool showRegionFilter;
  const ExploreScreenFilterDialog({
    Key? key,
    this.initialFilters,
    this.showRegionFilter = true,
  }) : super(key: key);

  @override
  _ExploreScreenFilterDialogState createState() =>
      _ExploreScreenFilterDialogState();
}

class _ExploreScreenFilterDialogState extends State<ExploreScreenFilterDialog>
    with SingleTickerProviderStateMixin {
  String planBusqueda = '';
  List<String> _selectedPlans = [];
  String? _customPlan;

  bool _onlyFollowed = false;
  bool _onlyPlans = false;

  String regionBusqueda = '';
  final TextEditingController _regionController = TextEditingController();
  final FocusNode _regionFocusNode = FocusNode();
  List<dynamic> _regionPredictions = [];

  bool locationAllowed = false;
  RangeValues edadRange = const RangeValues(18, 60);
  int generoSeleccionado = 2;
  DateTime? _selectedDate;

  // Posición del usuario para cálculos internos
  Position? _userPosition;

  late AnimationController _animationController;

  static const double _dropdownWidth = 260;

  @override
  void initState() {
    super.initState();
    // Si existen filtros iniciales, se cargan
    if (widget.initialFilters != null) {
      final init = widget.initialFilters!;
      planBusqueda = init['planBusqueda'] ?? '';
      if (init['selectedPlans'] != null) {
        _selectedPlans = List<String>.from(init['selectedPlans']);
      }
      _onlyFollowed = init['onlyFollowed'] ?? false;
      _onlyPlans = init['onlyPlans'] ?? false;
      regionBusqueda = init['regionBusqueda'] ?? '';
      edadRange = RangeValues(
        (init['edadMin'] ?? 18).toDouble(),
        (init['edadMax'] ?? 60).toDouble(),
      );
      generoSeleccionado = init['genero'] ?? 2;
      if (init['planDate'] != null && init['planDate'] is DateTime) {
        _selectedDate = init['planDate'] as DateTime;
      }
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
    }
  }

  Future<void> _obtenerUbicacion() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _userPosition = position;
      });
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        String address =
            "${placemark.street ?? ''} ${placemark.subThoroughfare ?? ''}, ${placemark.thoroughfare ?? ''}, ${placemark.postalCode ?? ''}, ${placemark.locality ?? ''}, ${placemark.country ?? ''}";
        setState(() {
          regionBusqueda = address;
          _regionController.text = address;
          _regionPredictions = [];
        });
      }
    } catch (e) {
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
          content: const Text(
              'El permiso de ubicación ha sido denegado permanentemente. Ve a la configuración de la app para habilitarlo.'),
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

    final String key =
        Platform.isAndroid ? APIKeys.androidApiKey : APIKeys.iosApiKey;
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$key&language=es';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _regionPredictions = data['predictions'];
          });
        } else {
        }
      } else {
      }
    } catch (e) {
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
  // - planBusqueda y selectedPlans (para filtrar plan)
  // - regionBusqueda (texto a mostrar)
  // - edadMin, edadMax, genero y userCoordinates (para cálculos internos)
  void _aplicarFiltros() {
    Navigator.of(context).pop({
      'planBusqueda': planBusqueda,
      'selectedPlans': _selectedPlans,
      'regionBusqueda': regionBusqueda,
      'planDate': _selectedDate,
      'edadMin': edadRange.start,
      'edadMax': edadRange.end,
      'genero': generoSeleccionado,
      'onlyFollowed': _onlyFollowed,
      'onlyPlans': _onlyPlans,
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
      _selectedPlans.clear();
      _customPlan = null;
      regionBusqueda = '';
      _regionController.clear();
      edadRange = const RangeValues(18, 60);
      _selectedDate = null;
      _onlyFollowed = false;
      _onlyPlans = false;
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

    final textStyle = const TextStyle(color: Colors.black, fontSize: 14);
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
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.lightLilac,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.greyBorder),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Filtrar Planes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.planColor,
                      ),
                    ),
                    const Divider(
                      color: Colors.black,
                      thickness: 0.2,
                      height: 20,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '¿Qué deseas ver?',
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Text(
                                _onlyPlans ? 'Solo planes' : 'Todo',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: !_onlyPlans,
                                activeColor: AppColors.planColor,
                                inactiveThumbColor: Colors.grey,
                                onChanged: (v) {
                                  setState(() {
                                    _onlyPlans = !v;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _onlyFollowed = !_onlyFollowed;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _onlyFollowed
                                  ? AppColors.planColor
                                  : AppColors.lightLilac,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.greyBorder),
                            ),
                            child: Text(
                              'Solo de personas que sigo',
                              style: TextStyle(
                                color:
                                    _onlyFollowed ? Colors.white : Colors.black,
                                fontFamily: 'Inter-Regular',
                                fontSize: 14,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                        ...plans.map((plan) {
                        final String name = plan['name'];
                        final bool selected = _selectedPlans.contains(name);
                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedPlans.remove(name);
                              } else {
                                _selectedPlans.add(name);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.planColor
                                  : AppColors.lightLilac,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.greyBorder),
                            ),
                            child: Text(
                              name,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.black,
                                fontFamily: 'Inter-Regular',
                                fontSize: 14,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '- o -',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: _dropdownWidth,
                      child: TextField(
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.lightLilac,
                          hintText: 'Busca por nombre...',
                          hintStyle: const TextStyle(
                            color: Colors.black54,
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
                          color: AppColors.lightLilac,
                          border: Border.all(color: AppColors.greyBorder),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: planSugeridos.map((plan) {
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  final name = plan['name'];
                                  if (_selectedPlans.contains(name)) {
                                    _selectedPlans.remove(name);
                                  } else {
                                    _selectedPlans.add(name);
                                  }
                                  _customPlan = null;
                                  planBusqueda = '';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Text(
                                  plan['name'],
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontFamily: 'Inter-Regular',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const Divider(
                      color: Colors.black,
                      thickness: 0.2,
                      height: 20,
                    ),
                    if (widget.showRegionFilter) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '¿En qué región buscas planes?',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
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
                          style: const TextStyle(color: Colors.black),
                          maxLines: null,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.lightLilac,
                            hintText: 'Ciudad, país...',
                            hintStyle: const TextStyle(
                              color: Colors.black54,
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
                                      color: Colors.black,
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
                              _updateUserCoordinatesFromAddress(
                                  _regionController.text);
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
                            color: AppColors.lightLilac,
                            border: Border.all(color: AppColors.greyBorder),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: _regionPredictions.map((prediction) {
                              return ListTile(
                                title: Text(
                                  prediction['description'],
                                  style: const TextStyle(color: Colors.black),
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
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: locationAllowed
                              ? AppColors.planColor
                              : AppColors.lightLilac,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _requestLocationPermission,
                        child: Text(
                          'Tu ubicación actual',
                          style: TextStyle(
                            color:
                                locationAllowed ? Colors.white : Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    const Divider(
                      color: Colors.black,
                      thickness: 0.2,
                      height: 20,
                    ),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '¿Para qué fecha buscas planes?',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.planColor,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () async {
                      final DateTime now = DateTime.now();
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? now,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                    child: Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Selecciona una fecha',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const Divider(
                    color: Colors.black,
                    thickness: 0.2,
                    height: 20,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '¿Qué rango de edad?',
                      style: TextStyle(
                        fontSize: 16,
                          color: Colors.black,
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
                            activeColor: AppColors.planColor,
                            inactiveColor: Colors.black26,
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.lightLilac,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "${edadRange.start.round()} - ${edadRange.end.round()}",
                              style: const TextStyle(color: Colors.black),
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
                            style: TextStyle(color: Colors.black),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.planColor,
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
    );
  }
}

Future<Map<String, dynamic>?> showExploreFilterDialog(
    BuildContext context,
    {Map<String, dynamic>? initialFilters,
    bool showRegionFilter = true}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: true,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: ExploreScreenFilterDialog(
        initialFilters: initialFilters,
        showRegionFilter: showRegionFilter,
      ),
    ),
  );
}
