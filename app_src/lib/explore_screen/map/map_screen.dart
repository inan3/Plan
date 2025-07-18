// map_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../../main/keys.dart';
import 'plans_in_map_screen.dart';
import '../main_screen/explore_screen_filter.dart';
import '../../l10n/app_localizations.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Position? _currentPosition;
  bool _locationPermissionGranted = false;
  double _currentZoom = 14.0;
  List<dynamic> _predictions = [];
  List<Marker> _allMarkers = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Map<String, dynamic> _appliedFilters = {'onlyPlans': false};
  Future<void>? _loadFuture;
  final PlansInMapScreen _plansLoader = PlansInMapScreen();
  LatLng? _lastQueryCenter;
  static const double _reloadThresholdKm = 5.0;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(41.3851, 2.1734),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _searchController.addListener(() {
      _fetchAddressPredictions(_searchController.text);
    });
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
        final c = await _controller.future;
        c.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 14.0,
            ),
          ),
        );
      }
      _loadMarkers(filters: _appliedFilters);
    }
  }

  Future<void> _loadMarkersInternal({Map<String, dynamic>? filters}) async {
    final controller = await _controller.future;
    final bounds = await controller.getVisibleRegion();
    final centerLat =
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
    final centerLng =
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
    _lastQueryCenter = LatLng(centerLat, centerLng);

    final planMarkers =
        await _plansLoader.loadPlansMarkers(context, filters: filters);
    Set<Marker> markers = {...planMarkers};

    // When the user selects "Todo" we should display both plan markers and
    // markers for users without an active plan. The filter stores this choice
    // using the `onlyPlans` boolean (true => show only plans). If it is not
    // true, we load additional user markers.
    final bool showOnlyPlans = filters?['onlyPlans'] == true;

    if (!showOnlyPlans) {
      final userMarkers = await _plansLoader.loadUsersWithoutPlansMarkers(
        context,
        bounds: bounds,
        filters: filters,
      );
      markers.addAll(userMarkers);
    }
    _allMarkers = markers.toList()
      ..sort((a, b) => a.markerId.value.compareTo(b.markerId.value));
    _updateVisibleMarkers(_currentZoom);
  }

  void _loadMarkers({Map<String, dynamic>? filters}) {
    setState(() {
      _loadFuture = _loadMarkersInternal(filters: filters);
    });
  }

  void _updateVisibleMarkers(double zoom) {
    int maxToShow;
    if (zoom < 8) {
      maxToShow = 50;
    } else if (zoom < 10) {
      maxToShow = 200;
    } else if (zoom < 12) {
      maxToShow = 500;
    } else {
      maxToShow = _allMarkers.length;
    }
    final limited = _allMarkers.length > maxToShow
        ? _allMarkers.sublist(0, maxToShow)
        : _allMarkers;
    // Evitamos redistribuir los marcadores para que permanezcan fijos al hacer
    // zoom. Simplemente convertimos la lista limitada en un conjunto y
    // limpiamos las polilíneas.
    setState(() {
      _markers = limited.toSet();
      _polylines = {};
    });
  }


  double _distanceKm(LatLng a, LatLng b) {
    const earthRadius = 6371;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);
    final sa = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(a.latitude)) *
            math.cos(_deg2rad(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(sa), math.sqrt(1 - sa));
    return earthRadius * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);

  Future<void> _fetchAddressPredictions(String input) async {
    if (input.isEmpty) {
      setState(() {
        _predictions = [];
      });
      return;
    }
    final key = Platform.isAndroid ? APIKeys.androidApiKey : APIKeys.iosApiKey;
    final url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$key&language=es';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
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
    } catch (_) {
      setState(() {
        _predictions = [];
      });
    }
  }

  Future<void> _onPredictionTap(dynamic p) async {
    final placeId = p['place_id'];
    final key = Platform.isAndroid ? APIKeys.androidApiKey : APIKeys.iosApiKey;
    final url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$key';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'OK') {
          final loc = data['result']['geometry']['location'];
          final c = await _controller.future;
          c.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: LatLng(loc['lat'], loc['lng']), zoom: 14),
            ),
          );
          setState(() {
            _searchController.text = p['description'];
            _predictions = [];
            _searchFocusNode.unfocus();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _onFilterPressed() async {
    final result = await showExploreFilterDialog(
      context,
      initialFilters: _appliedFilters,
      showRegionFilter: false,
    );
    if (result != null) {
      setState(() {
        _appliedFilters = result;
      });
      _loadMarkers(filters: _appliedFilters);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FutureBuilder(
            future: _loadFuture,
            builder: (context, snapshot) {
              return GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: _initialPosition,
                markers: _markers,
                polylines: _polylines,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                onMapCreated: (c) {
                  _controller.complete(c);
                  if (_currentPosition != null) {
                    c.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(_currentPosition!.latitude,
                              _currentPosition!.longitude),
                          zoom: 14.0,
                        ),
                      ),
                    );
                    _loadMarkers(filters: _appliedFilters);
                  }
                },
                onCameraMove: (pos) {
                  _currentZoom = pos.zoom;
                },
                onCameraIdle: () async {
                  final c = await _controller.future;
                  final bounds = await c.getVisibleRegion();
                  final center = LatLng(
                    (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
                    (bounds.northeast.longitude + bounds.southwest.longitude) /
                        2,
                  );
                  if (_lastQueryCenter == null ||
                      _distanceKm(center, _lastQueryCenter!) >
                          _reloadThresholdKm) {
                    _plansLoader.resetUserPagination();
                    _loadMarkers(filters: _appliedFilters);
                  } else {
                    _updateVisibleMarkers(_currentZoom);
                  }
                },
                myLocationEnabled: _locationPermissionGranted,
              );
            },
          ),
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
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)
                                .searchAddressPlansHint,
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixIcon:
                                const Icon(Icons.search, color: Colors.grey),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear,
                                        color: Colors.grey),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _predictions = [];
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 20,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.fromARGB(255, 13, 32, 53),
                                Color.fromARGB(255, 72, 38, 38),
                                Color(0xFF12232E),
                              ],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.srcIn,
                          child: Image.asset(
                            'assets/filter.png',
                            width: 24,
                            height: 24,
                          ),
                        ),
                        onPressed: _onFilterPressed,
                      ),
                    ],
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
                      itemBuilder: (context, i) {
                        final pred = _predictions[i];
                        return ListTile(
                          title: Text(
                            pred['description'],
                            style: const TextStyle(color: Colors.black),
                          ),
                          onTap: () => _onPredictionTap(pred),
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

