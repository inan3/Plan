import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../../main/keys.dart'; // Asegúrate de que contenga APIKeys.androidApiKey y APIKeys.iosApiKey
import 'plans_in_map_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  Set<Marker> _markers = {};
  bool _locationPermissionGranted = false;
  Position? _currentPosition;

  // Controladores y variables para el buscador de direcciones
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<dynamic> _predictions = [];

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(41.3851, 2.1734), // Ejemplo: Barcelona
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();

    // Listener para obtener predicciones mientras se escribe
    _searchController.addListener(() {
      _fetchAddressPredictions(_searchController.text);
    });

    // Listener para cerrar las predicciones cuando el campo pierde el foco
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        setState(() {
          _predictions = [];
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    PermissionStatus status = await Permission.locationWhenInUse.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      status = await Permission.locationWhenInUse.request();
    }

    if (status.isGranted) {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _locationPermissionGranted = true;
      });

      if (_controller.isCompleted) {
        final controller = await _controller.future;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 14.0,
            ),
          ),
        );
      }

      // Cargar marcadores después de obtener la posición
      await _loadMarkers();
    }
  }

  Future<void> _loadMarkers() async {
    final plansLoader = PlansInMapScreen();
    final planMarkers = await plansLoader.loadPlansMarkers(context);
    final userNoPlanMarkers = await plansLoader.loadUsersWithoutPlansMarkers(context);

    setState(() {
      _markers = {...planMarkers, ...userNoPlanMarkers};
    });
  }

  // Función para obtener predicciones de direcciones usando Google Places API
  Future<void> _fetchAddressPredictions(String input) async {
    if (input.isEmpty) {
      setState(() {
        _predictions = [];
      });
      return;
    }

    final String apiKey = Platform.isAndroid ? APIKeys.androidApiKey : APIKeys.iosApiKey;
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$apiKey&language=es';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _predictions = data['predictions'];
          });
        } else {
          setState(() {
            _predictions = [];
          });
        }
      } else {
        setState(() {
          _predictions = [];
        });
      }
    } catch (e) {
      setState(() {
        _predictions = [];
      });
    }
  }

  // Función para centrar el mapa en una dirección seleccionada
  Future<void> _onPredictionTap(dynamic prediction) async {
    final placeId = prediction['place_id'];
    final String apiKey = Platform.isAndroid ? APIKeys.androidApiKey : APIKeys.iosApiKey;
    final String url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];

          final controller = await _controller.future;
          controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(lat, lng),
                zoom: 14.0,
              ),
            ),
          );

          // Aseguramos que la lista desaparezca después de seleccionar la dirección
          setState(() {
            _searchController.text = prediction['description'];
            _predictions = []; // Vacía la lista de predicciones
            _searchFocusNode.unfocus(); // Quita el foco para cerrar el teclado
          });
        }
      }
    } catch (e) {
      debugPrint('Error al obtener detalles de la dirección: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              if (_currentPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 14.0,
                    ),
                  ),
                );
              }
            },
            myLocationEnabled: _locationPermissionGranted,
          ),
          // Campo de búsqueda y predicciones
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Buscar dirección...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _predictions = [];
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    ),
                  ),
                ),
                if (_predictions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _predictions.length,
                      itemBuilder: (context, index) {
                        final prediction = _predictions[index];
                        return ListTile(
                          title: Text(
                            prediction['description'],
                            style: const TextStyle(color: Colors.black),
                          ),
                          onTap: () => _onPredictionTap(prediction),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}