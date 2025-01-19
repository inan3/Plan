import 'dart:async'; // Importa Completer
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class PlanMapPicker extends StatefulWidget {
  final TextEditingController addressController;
  final ValueChanged<LatLng> onLocationSelected;
  final ValueChanged<String> onAddressSelected;

  const PlanMapPicker({
    Key? key,
    required this.addressController,
    required this.onLocationSelected,
    required this.onAddressSelected,
  }) : super(key: key);

  @override
  _PlanMapPickerState createState() => _PlanMapPickerState();
}

class _PlanMapPickerState extends State<PlanMapPicker> {
  final Completer<GoogleMapController> _mapControllerCompleter = Completer();
  LatLng _tempLocation = const LatLng(37.7749, -122.4194);

  void _searchAddress() async {
    if (widget.addressController.text.isNotEmpty) {
      try {
        List<Location> locations = await locationFromAddress(widget.addressController.text);
        if (locations.isNotEmpty) {
          setState(() {
            _tempLocation = LatLng(locations.first.latitude, locations.first.longitude);
          });
          final mapController = await _mapControllerCompleter.future;
          mapController.animateCamera(CameraUpdate.newLatLng(_tempLocation));
        }
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró la dirección.')),
        );
      }
    }
  }

  void _selectAddress() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _tempLocation.latitude,
        _tempLocation.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = "${place.street} ${place.locality}, ${place.country}";
        widget.onAddressSelected(address);
      }
    } catch (_) {
      widget.onAddressSelected("Lat: ${_tempLocation.latitude}, Lng: ${_tempLocation.longitude}");
    }
    widget.onLocationSelected(_tempLocation);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ubicación:',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: widget.addressController,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Escribe una dirección',
            hintText: 'Introduce la dirección',
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _searchAddress,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 300,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: _tempLocation, zoom: 14.0),
            markers: {
              Marker(
                markerId: const MarkerId('selectedLocation'),
                position: _tempLocation,
                draggable: true,
                onDragEnd: (newPosition) {
                  setState(() {
                    _tempLocation = newPosition;
                  });
                },
              ),
            },
            onMapCreated: (GoogleMapController controller) {
              if (!_mapControllerCompleter.isCompleted) {
                _mapControllerCompleter.complete(controller);
              }
            },
            onTap: (position) {
              setState(() {
                _tempLocation = position;
              });
              _selectAddress();
            },
          ),
        ),
      ],
    );
  }
}
