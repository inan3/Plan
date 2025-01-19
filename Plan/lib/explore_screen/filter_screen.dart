import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class FilterScreen extends StatefulWidget {
  final RangeValues initialAgeRange;
  final double initialDistance;
  final int initialSelection;

  FilterScreen({
    Key? key,
    required this.initialAgeRange,
    required this.initialDistance,
    required this.initialSelection,
  }) : super(key: key);

  @override
  _FilterScreenState createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late RangeValues ageRange;
  late double distance;
  late List<bool> isSelected;

  // Nueva funcionalidad: Localización
  String _selectedLocation = 'Ubicación actual';
  LatLng? _chosenLocation;
  final List<String> _locations = ['Ubicación actual', 'Seleccionar en el mapa'];

  @override
  void initState() {
    super.initState();
    ageRange = widget.initialAgeRange;
    distance = widget.initialDistance;
    isSelected = [false, false, false];
    isSelected[widget.initialSelection] = true;

    _determinePosition(); // Obtener ubicación actual al inicio
  }

  // Nueva funcionalidad: Obtener ubicación actual
  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _selectedLocation = "${place.locality}, ${place.country}";
        });
      }
    } catch (e) {
      print("Error obteniendo ubicación: $e");
    }
  }

  // Nueva funcionalidad: Abrir mapa para seleccionar ubicación
  void _openMapModal() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) {
      LatLng? selectedPosition = _chosenLocation;

      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _chosenLocation ?? LatLng(40.4168, -3.7038), // Madrid por defecto
                  zoom: 12,
                ),
                onTap: (LatLng position) {
                  setState(() {
                    selectedPosition = position;
                  });
                },
                markers: selectedPosition != null
                    ? {
                        Marker(
                          markerId: MarkerId('selected'),
                          position: selectedPosition!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // Marcador azul
                        ),
                      }
                    : {},
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () async {
                  if (selectedPosition != null) {
                    try {
                      List<Placemark> placemarks = await placemarkFromCoordinates(
                        selectedPosition!.latitude, selectedPosition!.longitude,
                      );
                      if (placemarks.isNotEmpty) {
                        Placemark place = placemarks.first;
                        setState(() {
                          _chosenLocation = selectedPosition;
                          _selectedLocation = "${place.locality}, ${place.administrativeArea}";
                        });
                      }
                    } catch (e) {
                      print("Error obteniendo ubicación seleccionada: $e");
                    }
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: const Text('Guardar ubicación'),
              ),
            ),
          ],
        ),
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context, {
              'ageRange': ageRange,
              'distance': distance,
              'selection': isSelected.indexWhere((element) => element),
              'location': _selectedLocation,
            });
          },
        ),
        title: const Text('Filtros'),
        backgroundColor: Colors.purple,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                ageRange = const RangeValues(18, 40);
                distance = 50;
                isSelected = [true, false, false];
                _selectedLocation = 'Ubicación actual';
              });
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nueva funcionalidad: Localización (colocada al inicio)
            const Text('Ubicación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _locations.contains(_selectedLocation) ? _selectedLocation : 'Ubicación actual',
              items: _locations.map((location) => DropdownMenuItem(value: location, child: Text(location))).toList(),
              onChanged: (value) {
                setState(() {
                  if (value == 'Seleccionar en el mapa') {
                    _openMapModal();
                  } else {
                    _selectedLocation = value!;
                  }
                });
              },
            ),
            const SizedBox(height: 20),

            // Filtros originales
            const Text('Busco', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ToggleButtons(
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Hombres'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Mujeres'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Todo el mundo'),
                ),
              ],
              isSelected: isSelected,
              onPressed: (int index) {
                setState(() {
                  for (int i = 0; i < isSelected.length; i++) {
                    isSelected[i] = i == index;
                  }
                });
              },
            ),
            const SizedBox(height: 20),

            const Text('Edad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('${ageRange.start.round()} años'),
                Expanded(
                  child: RangeSlider(
                    values: ageRange,
                    min: 18,
                    max: 100,
                    divisions: 82,
                    onChanged: (RangeValues values) {
                      setState(() {
                        ageRange = values;
                      });
                    },
                  ),
                ),
                Text('${ageRange.end.round()} años'),
              ],
            ),
            const SizedBox(height: 20),

            const Text('Distancia (km)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('${distance.round()} km'),
                Expanded(
                  child: Slider(
                    value: distance,
                    min: 2,
                    max: 100,
                    divisions: 98,
                    onChanged: (double value) {
                      setState(() {
                        distance = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'ageRange': ageRange,
                  'distance': distance,
                  'selection': isSelected.indexWhere((element) => element),
                  'location': _selectedLocation,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }
}
