//meeting_location_screen.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../../main/colors.dart';
import '../../main/keys.dart';
import '../models/plan_model.dart';

/// Extensión para convertir Color a hexadecimal (incluyendo alfa)
extension ColorExtension on Color {
  String toHex({bool leadingHashSign = true}) =>
      '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
}

/// Función que convierte el SVG a BitmapDescriptor aplicando el color deseado
Future<BitmapDescriptor> getCustomSvgMarker(
    BuildContext context, String assetPath, Color color,
    {double width = 48, double height = 48}) async {
  // Cargar el contenido del SVG como String
  String svgString = await DefaultAssetBundle.of(context).loadString(assetPath);

  // Reemplaza el atributo fill del SVG por el color deseado
  final String coloredSvgString = svgString.replaceAll(
    RegExp(r'fill="[^"]*"'),
    'fill="${color.toHex()}"',
  );

  // Parsear el SVG
  final DrawableRoot svgDrawableRoot =
      await svg.fromSvgString(coloredSvgString, assetPath);

  // Renderizar a un Picture con el tamaño deseado
  final ui.Picture picture =
      svgDrawableRoot.toPicture(size: Size(width, height));

  // Convertir el Picture a Image
  final ui.Image image = await picture.toImage(width.toInt(), height.toInt());

  // Obtener los bytes en formato PNG
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
}

class MeetingLocationPopup extends StatefulWidget {
  final PlanModel plan;

  const MeetingLocationPopup({Key? key, required this.plan}) : super(key: key);

  @override
  State<MeetingLocationPopup> createState() => _MeetingLocationPopupState();
}

class _MeetingLocationPopupState extends State<MeetingLocationPopup> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<dynamic> _predictionList = [];

  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  BitmapDescriptor? _customMarkerIcon;

  final LatLng _initialPosition = const LatLng(40.416775, -3.703790);

  final String googleAPIKey = Platform.isAndroid
      ? APIKeys.androidApiKey
      : APIKeys.iosApiKey;

  @override
  void initState() {
    super.initState();

    // Si el plan ya tiene dirección y coordenadas, se asignan a las variables locales.
    if (widget.plan.location.isNotEmpty &&
        widget.plan.latitude != 0.0 &&
        widget.plan.longitude != 0.0) {
      _selectedAddress = widget.plan.location;
      _selectedLocation = LatLng(widget.plan.latitude!, widget.plan.longitude!);
      _searchController.text = widget.plan.location;
    }

    // Cargar el icono personalizado a partir del SVG coloreado con AppColors.blue
    getCustomSvgMarker(context, 'assets/icono-ubicacion-interno.svg', AppColors.blue)
        .then((icon) {
      setState(() {
        _customMarkerIcon = icon;
      });
    });
  }

  void _hideKeyboard() => FocusScope.of(context).unfocus();

  Future<void> _fetchPredictions(String input) async {
    if (input.isEmpty) {
      setState(() => _predictionList = []);
      return;
    }

    final encodedInput = Uri.encodeComponent(input);
    final url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$encodedInput&key=$googleAPIKey&language=es';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _predictionList = data['predictions'];
          });
        } else {
        }
      } else {
      }
    } catch (e) {
    }
  }

  Future<void> _fetchPlaceDetails(String placeId) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$googleAPIKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          setState(() {
            _selectedAddress = data['result']['formatted_address'];
            _selectedLocation = LatLng(location['lat'], location['lng']);
            _predictionList = [];
            _searchController.text = _selectedAddress!;
          });
          // Centrar la cámara en la ubicación seleccionada
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(_selectedLocation!),
          );
        } else {
        }
      } else {
      }
    } catch (e) {
    }
  }

  /// Obtiene la ubicación actual y realiza reverse geocoding para obtener la dirección
  Future<void> _useCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permiso de ubicación denegado")),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "El permiso de ubicación está denegado permanentemente, no se puede solicitar")),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);

      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$googleAPIKey&language=es';
      final response = await http.get(Uri.parse(url));

      String address;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' &&
            data['results'] != null &&
            (data['results'] as List).isNotEmpty) {
          address = data['results'][0]['formatted_address'];
        } else {
          address = "Dirección no encontrada";
        }
      } else {
        address = "Dirección no disponible";
      }

      setState(() {
        _selectedLocation = currentLatLng;
        _selectedAddress = address;
        _searchController.text = address;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_selectedLocation!),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al obtener la ubicación")),
      );
    }
  }

  void _onConfirmLocation() {
    if (_selectedLocation == null || _selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor, selecciona una ubicación."),
        ),
      );
      return;
    }
    // Guarda la ubicación en el plan y cierra el popup
    widget.plan.location = _selectedAddress!;
    widget.plan.latitude = _selectedLocation!.latitude;
    widget.plan.longitude = _selectedLocation!.longitude;
    Navigator.pop(context, widget.plan);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _hideKeyboard,
      behavior: HitTestBehavior.translucent,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // Mapa de fondo
                  Positioned.fill(
                    child: GoogleMap(
                      onMapCreated: (controller) {
                        _mapController = controller;
                        // Si ya se tenía una ubicación seleccionada, centrar la cámara
                        if (_selectedLocation != null) {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLng(_selectedLocation!),
                          );
                        }
                      },
                      markers: _selectedLocation != null
                          ? {
                              Marker(
                                markerId: const MarkerId('selectedLoc'),
                                position: _selectedLocation!,
                                icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
                              )
                            }
                          : {},
                      // Al tocar el mapa se actualiza la ubicación y se centra la cámara
                      onTap: (pos) {
                        setState(() {
                          _selectedLocation = pos;
                        });
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLng(pos),
                        );
                      },
                      initialCameraPosition: CameraPosition(
                        target: _initialPosition,
                        zoom: 14,
                      ),
                      zoomControlsEnabled: false,
                    ),
                  ),
                  // Campo de búsqueda con efecto frosted glass
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Material(
                      color: Colors.transparent,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _focusNode,
                              onChanged: (value) {
                                _fetchPredictions(value);
                              },
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                hintText: "Busca un lugar...",
                                hintStyle: const TextStyle(color: Color.fromARGB(232, 255, 255, 255)),
                                border: InputBorder.none,
                                prefixIcon: IconButton(
                                  icon: const Icon(Icons.search, color: Colors.white),
                                  onPressed: () => _fetchPredictions(_searchController.text),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Lista de predicciones
                  if (_predictionList.isNotEmpty)
                    Positioned(
                      top: 80,
                      left: 20,
                      right: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(8),
                          itemCount: _predictionList.length,
                          itemBuilder: (context, index) {
                            final item = _predictionList[index];
                            return InkWell(
                              onTap: () {
                                _fetchPlaceDetails(item['place_id']);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                child: Text(
                                  item['description'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  // Dock inferior: Botón "Tu ubicación actual", muestra dirección y botón "Confirmar ubicación"
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
                        child: Container(
                          color: Colors.black.withOpacity(0.2),
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Botón "Tu ubicación actual"
                              ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _useCurrentLocation,
                                      child: IntrinsicWidth(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: const Color.fromARGB(255, 111, 110, 110)
                                                .withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(30),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.2),
                                            ),
                                          ),
                                          child: const Text(
                                            "Tu ubicación actual",
                                            style: TextStyle(
                                              color: AppColors.blue,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_selectedAddress != null)
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(255, 149, 144, 144)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    _selectedAddress!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              const SizedBox(height: 16),
                              // Botón "Confirmar ubicación"
                              ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _onConfirmLocation,
                                      child: IntrinsicWidth(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: AppColors.blue,
                                            borderRadius: BorderRadius.circular(30),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.2),
                                            ),
                                          ),
                                          child: const Text(
                                            "Confirmar ubicación",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Fin botón "Confirmar ubicación"
                            ],
                          ),
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
    );
  }
}
