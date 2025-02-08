import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import '../../main/colors.dart';
import '../../explore_screen/explore_screen.dart';
import '../../main/keys.dart'; // Asegúrate de tener tus claves aquí
import 'date_time_screen.dart'; // Importa la pantalla de selección de fecha y hora
import '../models/plan_model.dart'; // Importa el modelo PlanModel

class MeetingLocationScreen extends StatefulWidget {
  final PlanModel plan;

  const MeetingLocationScreen({required this.plan, super.key});

  @override
  State<MeetingLocationScreen> createState() => _MeetingLocationScreenState();
}

class _MeetingLocationScreenState extends State<MeetingLocationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<dynamic> _predictionList = [];
  LatLng? _selectedLocation;
  String? _selectedAddress;
  GoogleMapController? _mapController;

  static final LatLng _initialPosition = const LatLng(40.416775, -3.703790);

  final String googleAPIKey = Platform.isAndroid
      ? APIKeys.androidApiKey
      : APIKeys.iosApiKey;

  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _fetchPredictions(String input) async {
    if (input.isEmpty) {
      setState(() {
        _predictionList = [];
      });
      return;
    }

    final String url =
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
          print('Error en la API de Google Places: ${data['status']}');
        }
      } else {
        print('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al obtener predicciones: $e');
    }
  }

  Future<void> _fetchPlaceDetails(String placeId) async {
    final String url =
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
          print('Error en la API de detalles: ${data['status']}');
        }
      } else {
        print('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al obtener detalles del lugar: $e');
    }
  }

  void _navigateToDateTimeScreen() {
    if (_selectedLocation == null || _selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, selecciona una ubicación antes de continuar.")),
      );
      return;
    }

    // Guardamos la ubicación en el modelo
    widget.plan.location = _selectedAddress!;
    widget.plan.latitude = _selectedLocation!.latitude;
    widget.plan.longitude = _selectedLocation!.longitude;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DateTimeScreen(plan: widget.plan),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: _hideKeyboard,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Mapa interactivo
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 14.0,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              markers: _selectedLocation != null
                  ? {
                      Marker(
                        markerId: const MarkerId('selectedLocation'),
                        position: _selectedLocation!,
                      ),
                    }
                  : {},
            ),

            // Contenedor superior con input y lista de predicciones
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      "Elige la ubicación del encuentro",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Input de texto
                    TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Introduce una dirección',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        _fetchPredictions(value);
                      },
                    ),

                    // Lista de predicciones dentro del contenedor
                    if (_predictionList.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: _predictionList.length,
                        itemBuilder: (context, index) {
                          final prediction = _predictionList[index];
                          return GestureDetector(
                            onTap: () {
                              _fetchPlaceDetails(prediction['place_id']);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              child: Text(
                                prediction['description'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.blue,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Contenedor con ubicación seleccionada
            if (_selectedAddress != null)
              Positioned(
                bottom: 80,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Texto descriptivo
                    Text(
                      "Punto de encuentro seleccionado:",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Contenedor para la dirección seleccionada
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.place, color: AppColors.blue, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedAddress!,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.blue,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Botón "X" para salir
            Positioned(
              top: 45,
              left: 16,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const ExploreScreen()),
                    (route) => false,
                  );
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: AppColors.blue,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Barra inferior con flechas
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 32),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward, color: Colors.blue, size: 32),
              onPressed: _navigateToDateTimeScreen,
            ),
          ],
        ),
      ),
    );
  }
}
