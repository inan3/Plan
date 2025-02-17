import 'dart:ui';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart'; // Asegúrate de agregar esta dependencia

import '../../main/colors.dart';
import '../../main/keys.dart'; // Tus claves (APIKeys.androidApiKey / APIKeys.iosApiKey)
import '../models/plan_model.dart'; // Modelo PlanModel

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

  final LatLng _initialPosition = const LatLng(40.416775, -3.703790);
  
  final String googleAPIKey = Platform.isAndroid
      ? APIKeys.androidApiKey
      : APIKeys.iosApiKey;

  @override
  void initState() {
    super.initState();
    // Si el plan ya tiene datos, podrías inicializar _selectedLocation aquí.
  }

  void _hideKeyboard() => FocusScope.of(context).unfocus();

  Future<void> _fetchPredictions(String input) async {
    if (input.isEmpty) {
      setState(() => _predictionList = []);
      return;
    }

    final url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$googleAPIKey&language=es';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _predictionList = data['predictions'];
          });
        } else {
          debugPrint('Error en la API de Autocomplete: ${data['status']}');
        }
      } else {
        debugPrint('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error al obtener predicciones: $e');
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
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(_selectedLocation!),
          );
        } else {
          debugPrint('Error en la API de Place Details: ${data['status']}');
        }
      } else {
        debugPrint('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error al obtener detalles del lugar: $e');
    }
  }

  /// Obtiene la ubicación real y realiza reverse geocoding para obtener la dirección
  Future<void> _useCurrentLocation() async {
    // Comprueba y solicita permisos
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
      
      // Realiza reverse geocoding usando la API de Google
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$googleAPIKey&language=es';
      final response = await http.get(Uri.parse(url));
      String address;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['results'].length > 0) {
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
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_selectedLocation!),
      );
    } catch (e) {
      debugPrint("Error al obtener la ubicación: $e");
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
    // Se guarda la ubicación real en el plan
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                    },
                    markers: _selectedLocation != null
                        ? {
                            Marker(
                              markerId: const MarkerId('selectedLoc'),
                              position: _selectedLocation!,
                            )
                          }
                        : {},
                    onTap: (pos) {
                      setState(() {
                        _selectedLocation = pos;
                      });
                    },
                    initialCameraPosition: CameraPosition(
                      target: _initialPosition,
                      zoom: 14,
                    ),
                    zoomControlsEnabled: false,
                  ),
                ),
                // Input de búsqueda en la parte superior
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Busca un lugar...",
                          hintStyle: const TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: () =>
                                _fetchPredictions(_searchController.text),
                          ),
                        ),
                        onChanged: (value) => _fetchPredictions(value),
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
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 4),
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
                // Dock inferior: botón "Tu ubicación actual", dirección y confirmar
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
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        color: Colors.black.withOpacity(0.4),
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _useCurrentLocation,
                              child: const Text(
                                "Tu ubicación actual",
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_selectedAddress != null)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
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
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _onConfirmLocation,
                              child: const Text(
                                "Confirmar ubicación",
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
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
    );
  }
}
