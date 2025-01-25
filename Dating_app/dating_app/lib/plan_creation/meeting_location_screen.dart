import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

import '../../main/colors.dart';
import '../../explore_screen/explore_screen.dart';

class MeetingLocationScreen extends StatefulWidget {
  const MeetingLocationScreen({Key? key}) : super(key: key);

  @override
  State<MeetingLocationScreen> createState() => _MeetingLocationScreenState();
}

class _MeetingLocationScreenState extends State<MeetingLocationScreen> {
  GoogleMapController? _mapController;
  Marker? _selectedMarker;
  final TextEditingController _searchController = TextEditingController();
  List<String> _suggestions = [];

  // Coordenadas iniciales (ejemplo: Madrid)
  static const LatLng _initialPosition = LatLng(40.416775, -3.703790);

  // Busca sugerencias de direcciones
  Future<void> _updateSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions.clear();
      });
      return;
    }

    try {
      final locations = await locationFromAddress(query);
      setState(() {
        _suggestions = locations
            .map((location) =>
                "${location.latitude}, ${location.longitude}")
            .toList();
      });
    } catch (e) {
      setState(() {
        _suggestions.clear();
      });
    }
  }

  // Selecciona una dirección de las sugerencias
  Future<void> _selectSuggestion(String suggestion) async {
    try {
      final coords = suggestion.split(', ');
      final lat = double.parse(coords[0]);
      final lng = double.parse(coords[1]);
      final position = LatLng(lat, lng);

      setState(() {
        _selectedMarker = Marker(
          markerId: const MarkerId("selected"),
          position: position,
        );
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(position));
      _suggestions.clear();
      _searchController.clear();
    } catch (e) {
      // Manejar errores
    }
  }

  // Selecciona ubicación tocando el mapa
  void _onMapTap(LatLng position) {
    setState(() {
      _selectedMarker = Marker(
        markerId: const MarkerId("selected"),
        position: position,
      );
    });
  }

  // Confirma la ubicación seleccionada
  void _confirmLocation() {
    if (_selectedMarker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No has seleccionado ninguna ubicación.")),
      );
      return;
    }

    // Ejemplo: lógica al confirmar ubicación
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Ubicación confirmada: ${_selectedMarker?.position.latitude}, ${_selectedMarker?.position.longitude}",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Mapa
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _initialPosition,
                zoom: 12,
              ),
              markers: _selectedMarker != null ? {_selectedMarker!} : {},
              onMapCreated: (controller) => _mapController = controller,
              onTap: _onMapTap,
            ),

            // Input de búsqueda
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: "Buscar dirección...",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _updateSuggestions,
                  ),
                  // Lista de sugerencias
                  if (_suggestions.isNotEmpty)
                    Container(
                      color: Colors.white,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(_suggestions[index]),
                            onTap: () => _selectSuggestion(_suggestions[index]),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // Botón "X" para salir a ExploreScreen
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
            // Flecha para volver atrás
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 32),
              onPressed: () {
                Navigator.pop(context);
              },
            ),

            // Flecha para confirmar
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
