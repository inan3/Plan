import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'plans_in_map_screen.dart';
import '../explore_screen_filter.dart'; // Asegúrate de que la ruta sea la correcta

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

  // Variable para almacenar los filtros aplicados
  Map<String, dynamic>? _filters;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(41.3851, 2.1734), // Ejemplo: Barcelona
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    PermissionStatus status = await Permission.locationWhenInUse.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      status = await Permission.locationWhenInUse.request();
    }

    if (status.isGranted) {
      // Obtiene la ubicación actual del usuario
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

      // Carga los marcadores (planes + usuarios sin plan)
      _loadMarkers();
    }
  }

  /// Carga y combina los marcadores de planes con los de usuarios sin plan
  Future<void> _loadMarkers() async {
    final plansLoader = PlansInMapScreen();

    // 1) Marcadores de planes con el filtro
    final planMarkers = await plansLoader.loadPlansMarkers(context, filters: _filters);

    // 2) Marcadores de usuarios sin plan (también con el filtro, si procede)
    final userNoPlanMarkers = await plansLoader.loadUsersWithoutPlansMarkers(context, filters: _filters);

    // 3) Combinamos
    setState(() {
      _markers = {
        ...planMarkers,
        ...userNoPlanMarkers,
      };
    });
  }

  // Función para abrir el diálogo de filtros y actualizar la interfaz
  Future<void> _openFilterDialog() async {
    final result = await showExploreFilterDialog(context, initialFilters: _filters);
    if (result != null) {
      setState(() {
        _filters = result;
      });
      // Vuelve a cargar para aplicar los filtros
      _loadMarkers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Se utiliza una AppBar que incluye el botón para abrir el filtro
      appBar: AppBar(
        title: const Text('Mapa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _openFilterDialog,
          ),
        ],
      ),
      body: GoogleMap(
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
    );
  }
}
