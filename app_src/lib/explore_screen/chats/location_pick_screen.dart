import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // para convertir dirección <-> coords

import '../../main/colors.dart';
// Si tienes tu getCustomSvgMarker:
import '../../plan_creation/new_plan_creation_screen.dart' show getCustomSvgMarker;

class LocationPickScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;

  const LocationPickScreen({
    Key? key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
  }) : super(key: key);

  @override
  _LocationPickScreenState createState() => _LocationPickScreenState();
}

class _LocationPickScreenState extends State<LocationPickScreen> {
  late GoogleMapController _mapController;
  BitmapDescriptor? _markerIcon;

  final TextEditingController _searchController = TextEditingController();
  double? _selectedLat;
  double? _selectedLng;
  String? _selectedAddress;

  bool _isMapReady = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();

    // Iniciamos con coords iniciales, si existen
    _selectedLat = widget.initialLat;
    _selectedLng = widget.initialLng;
    _selectedAddress = widget.initialAddress;

    _loadMarkerIcon();
  }

  Future<void> _loadMarkerIcon() async {
    try {
      // Si no te interesa el marcador custom, usa default:
      // _markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

      // Para un SVG custom:
      _markerIcon = await getCustomSvgMarker(
        context,
        'assets/icono-ubicacion-interno.svg', // tu asset
        AppColors.blue,
        width: 48,
        height: 48,
      );
    } catch (e) {
      _markerIcon = BitmapDescriptor.defaultMarker;
    }
    setState(() {});
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    setState(() {
      _isMapReady = true;
    });

    if (_selectedLat != null && _selectedLng != null) {
      _moveCameraTo(_selectedLat!, _selectedLng!);
    } else {
      // Tratamos de obtener ubicación actual
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return;
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            return;
          }
        }
        if (permission == LocationPermission.deniedForever) {
          return;
        }
        Position pos = await Geolocator.getCurrentPosition();
        _selectedLat = pos.latitude;
        _selectedLng = pos.longitude;
        _moveCameraTo(pos.latitude, pos.longitude);
        await _reverseGeocode(pos.latitude, pos.longitude);
      } catch (e) {
      }
    }
  }

  Future<void> _moveCameraTo(double lat, double lng) async {
    await _mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 16),
      ),
    );
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _selectedAddress = _formatPlacemark(place);
        });
      }
    } catch (e) {
      _selectedAddress = null;
    }
  }

  String _formatPlacemark(Placemark place) {
    return [
      place.thoroughfare,
      place.subThoroughfare,
      place.locality,
      place.country,
    ].where((s) => s != null && s.trim().isNotEmpty).join(", ");
  }

  void _onMapLongPress(LatLng position) async {
    _selectedLat = position.latitude;
    _selectedLng = position.longitude;
    await _reverseGeocode(position.latitude, position.longitude);
    setState(() {});
  }

  Future<void> _searchByAddress() async {
    FocusScope.of(context).unfocus();
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        _selectedLat = loc.latitude;
        _selectedLng = loc.longitude;
        _selectedAddress = query;
        await _moveCameraTo(loc.latitude, loc.longitude);
      }
    } catch (e) {
    }

    setState(() => _isSearching = false);
  }

  void _onConfirmLocation() {
    if (_selectedLat == null || _selectedLng == null) {
      Navigator.pop(context, null);
    } else {
      Navigator.pop(context, {
        'latitude': _selectedLat,
        'longitude': _selectedLng,
        'address': _selectedAddress ?? '',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final markerLat = _selectedLat ?? 0.0;
    final markerLng = _selectedLng ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Elegir ubicación"),
        backgroundColor: AppColors.white,
        actions: [
          IconButton(
            onPressed: _onConfirmLocation,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Column(
        children: [
          // Caja de búsqueda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Busca una dirección...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onSubmitted: (_) => _searchByAddress(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: _searchByAddress,
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  onLongPress: _onMapLongPress,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(40.416775, -3.703790), // Madrid por ejemplo
                    zoom: 14,
                  ),
                  markers: (_selectedLat != null && _selectedLng != null)
                      ? {
                          Marker(
                            markerId: const MarkerId('selected-marker'),
                            position: LatLng(markerLat, markerLng),
                            icon: _markerIcon ?? BitmapDescriptor.defaultMarker,
                          ),
                        }
                      : {},
                  zoomControlsEnabled: false,
                ),
                if (!_isMapReady)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          // Dirección textual
          if (_selectedAddress != null)
            Container(
              width: double.infinity,
              color: Colors.grey.shade200,
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Dirección actual: $_selectedAddress",
                style: const TextStyle(fontSize: 14),
              ),
            ),
          // Botón de confirmar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton.icon(
                onPressed: _onConfirmLocation,
                icon: const Icon(Icons.check),
                label: const Text("Confirmar ubicación"),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: AppColors.planColor,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
