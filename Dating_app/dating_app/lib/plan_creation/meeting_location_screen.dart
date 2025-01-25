import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import '../../main/colors.dart';
import '../../explore_screen/explore_screen.dart';
import '../../main/keys.dart'; // Asegúrate de tener tus claves aquí

class MeetingLocationScreen extends StatefulWidget {
  const MeetingLocationScreen({Key? key}) : super(key: key);

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

  // API Key de Google Places
  final String googleAPIKey = Platform.isAndroid
      ? APIKeys.androidApiKey
      : APIKeys.iosApiKey;

  /// Oculta el teclado al hacer tap en un área vacía
  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
  }

  /// Lógica para obtener predicciones de lugares
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

  /// Obtiene los detalles de un lugar seleccionado
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
            _selectedLocation =
                LatLng(location['lat'], location['lng']);
            _predictionList = [];
            _searchController.text = _selectedAddress!;
          });

          // Mueve la cámara al lugar seleccionado
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

  /// Confirmación de ubicación elegida
  void _confirmLocation() {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No has seleccionado ninguna ubicación.")),
      );
      return;
    }

    // Aquí puedes continuar la lógica para guardar o usar la ubicación seleccionada
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Ubicación confirmada: $_selectedAddress",
        ),
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

            // Contenido principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/plan-sin-fondo.png',
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Elige la ubicación del encuentro",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Campo de búsqueda
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

                  const SizedBox(height: 10),

                  // Lista de predicciones
                  Expanded(
                    child: ListView.builder(
                      itemCount: _predictionList.length,
                      itemBuilder: (context, index) {
                        final prediction = _predictionList[index];
                        return ListTile(
                          title: Text(prediction['description']),
                          onTap: () {
                            _fetchPlaceDetails(prediction['place_id']);
                          },
                        );
                      },
                    ),
                  ),

                  // Dirección seleccionada
                  if (_selectedAddress != null) ...[
                    Text(
                      "Dirección seleccionada: $_selectedAddress",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),

            // Botón "X" para salir
            Positioned(
              top: 45,
              left: 20,
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
              onPressed: _confirmLocation,
            ),
          ],
        ),
      ),
    );
  }
}
