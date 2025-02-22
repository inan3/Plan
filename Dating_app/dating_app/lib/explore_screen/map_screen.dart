import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  Set<Marker> _markers = {};
  bool _locationPermissionGranted = false;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(41.3851, 2.1734), // Ubicación inicial (ejemplo: Barcelona)
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
      setState(() {
        _locationPermissionGranted = true;
      });
      _loadNearbyUsers();
    }
  }

  Future<void> _loadNearbyUsers() async {
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    final Set<Marker> markers = {};

    for (var doc in usersSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['latitude'] != null && data['longitude'] != null && data['profileImageUrl'] != null) {
        final LatLng userPosition = LatLng(
          double.parse(data['latitude'].toString()),
          double.parse(data['longitude'].toString()),
        );

        markers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: userPosition,
            icon: await _getCustomMarkerIcon(data['profileImageUrl']),
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<BitmapDescriptor> _getCustomMarkerIcon(String imageUrl) async {
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
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
            },
            myLocationEnabled: _locationPermissionGranted,
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar...',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: () {},
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons.filter_list, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
