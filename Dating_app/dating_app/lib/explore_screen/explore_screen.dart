import 'dart:math' as math;
import 'dart:ui'; // Para ImageFilter, etc.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dating_app/main/colors.dart';

// Importa el diálogo de filtros (actualizado)
import 'explore_screen_filter.dart';

import 'explore_app_bar.dart';
import 'users_grid.dart';
import 'menu_side_bar/menu_side_bar_screen.dart';
import 'chats/chats_screen.dart'; // Pantalla de mensajes
import 'users_managing/user_info_check.dart';
import 'map/map_screen.dart'; // Pantalla de búsqueda
import 'profile_screen.dart'; // Gestión del perfil
import 'notification_screen.dart'; // Pantalla de notificaciones
import 'package:dating_app/plan_creation/new_plan_creation_screen.dart';
import 'package:dating_app/plan_joining/plan_join_request.dart';
import 'filter_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  ExploreScreenState createState() => ExploreScreenState();
}

class ExploreScreenState extends State<ExploreScreen> {
  int _currentIndex = 0;
  int _selectedIconIndex = 0;
  bool _showPopup = false;

  final double _iconSize = 30.0;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<MainSideBarScreenState> _menuKey = GlobalKey<MainSideBarScreenState>();

  bool isMenuOpen = false;
  RangeValues selectedAgeRange = const RangeValues(18, 40);
  double selectedDistance = 50;

  // Ubicación por defecto en caso de que no se filtre
  final Map<String, double> currentLocation = {'lat': 41.3851, 'lng': 2.1734};

  // Filtros aplicados (se espera recibir: planBusqueda o planPredeterminado, regionBusqueda,
  // userCoordinates, edadMin, edadMax y genero)
  Map<String, dynamic> appliedFilters = {};

  double _spacingPopularToNearby = 10;
  double _popularTopSpacing = 5;
  late List<Widget> _otherPages;

  @override
  void initState() {
    super.initState();
    _setStatusBarDark();
    _otherPages = [
      const MapScreen(),
      const ChatsScreen(),
      ProfileScreen(),
    ];
    _currentIndex = 0;
    _selectedIconIndex = 0;
  }

  void _setStatusBarDark() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  void _onSearchChanged(String value) {
    // Implementa la lógica de búsqueda si lo requieres
  }

  // Al presionar el filtro, se envía el último estado de filtros
  void _onFilterPressed() async {
    final result = await showExploreFilterDialog(context, initialFilters: appliedFilters);
    if (result != null) {
      setState(() {
        appliedFilters = result;
        // Actualiza rango de edad
        selectedAgeRange = RangeValues(
          (result['edadMin'] ?? 18).toDouble(),
          (result['edadMax'] ?? 40).toDouble(),
        );
        // Si es necesario, actualiza ubicación, etc.
      });
    }
  }

  // Cálculo de distancia (Haversine)
  double computeDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371; // km
    double dLat = _deg2rad(lat2 - lat1);
    double dLng = _deg2rad(lng2 - lng1);
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);

  Widget _buildExplorePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        children: [
          ExploreAppBar(
            onMenuPressed: () => _menuKey.currentState?.toggleMenu(),
            onNotificationPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationScreen(
                    currentUserId: currentUser?.uid ?? '',
                  ),
                ),
              );
            },
            onSearchChanged: _onSearchChanged,
            notificationCountStream: _notificationCountStream(),
          ),
          Transform.translate(
            offset: const Offset(0, 0),
            child: _buildSearchContainer(),
          ),
          SizedBox(height: _spacingPopularToNearby),
          Expanded(child: _buildNearbySection()),
        ],
      ),
    );
  }

  Widget _buildSearchContainer() {
    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 15, top: 0, bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 213, 212, 212),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: SvgPicture.asset(
                'assets/lupa.svg',
                width: 24,
                height: 24,
                color: AppColors.blue,
              ),
            ),
            Expanded(
              child: TextField(
                onChanged: (value) {
                  // Lógica de búsqueda si la requieres
                },
                decoration: const InputDecoration(
                  hintText: 'Buscar...',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: Image.asset(
                'assets/filter.png',
                width: 24,
                height: 24,
                color: AppColors.blue,
              ),
              onPressed: _onFilterPressed,
            ),
          ],
        ),
      ),
    );
  }

  // Consulta "plans" para ver qué usuarios tienen un plan que coincida con un texto
  Future<List<String>> _fetchUserIdsWithPlan(String planFilter) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('plans').get();
    List<String> uids = [];
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final String planType = data['type']?.toString().toLowerCase() ?? '';
      if (planType.contains(planFilter.toLowerCase().trim())) {
        uids.add(data['createdBy'].toString());
      }
    }
    return uids;
  }

  // Listado de usuarios cercanos, filtrados
  Widget _buildNearbySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.black));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No hay usuarios cercanos.',
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
          );
        }

        List<QueryDocumentSnapshot> validUsers = snapshot.data!.docs;

        // Excluir usuario actual
        if (currentUser != null) {
          validUsers = validUsers.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['uid']?.toString() != currentUser!.uid;
          }).toList();
        }

        // Filtrar por rango de edad
        validUsers = validUsers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final int userAge = int.tryParse(data['age'].toString()) ?? 0;
          return userAge >= selectedAgeRange.start.round() &&
              userAge <= selectedAgeRange.end.round();
        }).toList();

        // Ordenar por distancia
        final double referenceLat = (appliedFilters['userCoordinates'] != null)
            ? (appliedFilters['userCoordinates']['lat'] as double)
            : currentLocation['lat']!;
        final double referenceLng = (appliedFilters['userCoordinates'] != null)
            ? (appliedFilters['userCoordinates']['lng'] as double)
            : currentLocation['lng']!;

        validUsers.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final double latA = double.tryParse(dataA['latitude']?.toString() ?? '') ?? 0;
          final double lngA = double.tryParse(dataA['longitude']?.toString() ?? '') ?? 0;
          final double latB = double.tryParse(dataB['latitude']?.toString() ?? '') ?? 0;
          final double lngB = double.tryParse(dataB['longitude']?.toString() ?? '') ?? 0;
          final distanceA = computeDistance(referenceLat, referenceLng, latA, lngA);
          final distanceB = computeDistance(referenceLat, referenceLng, latB, lngB);
          return distanceA.compareTo(distanceB);
        });

        // Filtrar por plan (opcional)
        final String? planFilter = (appliedFilters['planPredeterminado'] != null &&
                (appliedFilters['planPredeterminado'] as String).trim().isNotEmpty)
            ? appliedFilters['planPredeterminado'] as String
            : (appliedFilters['planBusqueda'] != null &&
                    (appliedFilters['planBusqueda'] as String).trim().isNotEmpty
                ? appliedFilters['planBusqueda'] as String
                : null);

        if (planFilter != null) {
          return FutureBuilder<List<String>>(
            future: _fetchUserIdsWithPlan(planFilter),
            builder: (context, planSnapshot) {
              if (planSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!planSnapshot.hasData || planSnapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'No hay planes con ese nombre.',
                    style: TextStyle(fontSize: 18, color: Colors.black),
                  ),
                );
              }
              final allowedUids = planSnapshot.data!;
              final filteredUsers = validUsers.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return allowedUids.contains(data['uid'].toString());
              }).toList();
              return UsersGrid(users: filteredUsers);
            },
          );
        } else {
          return UsersGrid(users: validUsers);
        }
      },
    );
  }

  /// NOTA: Se ha quitado el filtro `.where('read', isEqualTo: false)` para que no falle con notificaciones viejas.
  Stream<int> _notificationCountStream() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: currentUser?.uid)
        .where('type', whereIn: [
          'join_request',
          'join_accepted',
          'join_rejected',
          'invitation',
        ])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Seguimos filtrando mensajes no leídos
  Stream<int> _unreadMessagesCountStream() {
    return FirebaseFirestore.instance
        .collection('messages')
        .where('receiverId', isEqualTo: currentUser?.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Pop up no modal (Crear/Unirse a Plan)
  Widget _buildPopup() {
    const double dockBottomMargin = 50.0;
    const double dockHeight = 70.0;
    return Positioned(
      bottom: dockBottomMargin + dockHeight,
      left: 40,
      right: 40,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 38, 37, 37).withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón "Crear Plan"
              InkWell(
                onTap: () {
                  setState(() {
                    _showPopup = false;
                  });
                  NewPlanCreationScreen.showPopup(context);
                },
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Transform.scale(
                        scale: 1.5,
                        child: SvgPicture.asset(
                          'assets/anadir.svg',
                          color: Colors.white,
                          width: 24,
                          height: 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Crear Plan",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                height: 1,
                color: Colors.white,
              ),
              // Botón "Unirse a Plan"
              InkWell(
                onTap: () {
                  setState(() {
                    _showPopup = false;
                  });
                  JoinPlanRequestScreen.showJoinPlanDialog(context);
                },
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: SvgPicture.asset(
                          'assets/union.svg',
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Unirse a un Plan",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _mapDockIndexToPageIndex(int dockIndex) {
    switch (dockIndex) {
      case 0:
        return 0; // Explore
      case 1:
        return 1; // Search (MapScreen)
      case 3:
        return 2; // Chats
      case 4:
        return 3; // Perfil
      default:
        return _currentIndex;
    }
  }

  void _onDockIconTap(int dockIndex) {
    if (dockIndex == 2) {
      setState(() {
        _selectedIconIndex = 2;
        _showPopup = true;
      });
    } else {
      if (_showPopup) {
        setState(() {
          _showPopup = false;
        });
      }
      setState(() {
        _currentIndex = _mapDockIndexToPageIndex(dockIndex);
        _selectedIconIndex = dockIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 245, 239, 240),
                Color.fromARGB(255, 250, 249, 251),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              _currentIndex == 0 ? _buildExplorePage() : _otherPages[_currentIndex - 1],
              if (_showPopup) _buildPopup(),
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: DockSection(
                    currentIndex: _currentIndex,
                    selectedIconIndex: _selectedIconIndex,
                    onTapIcon: _onDockIconTap,
                    notificationCountStream: null, // No se usa aquí
                    unreadMessagesCountStream: _unreadMessagesCountStream(),
                  ),
                ),
              ),
              MainSideBarScreen(
                key: _menuKey,
                onMenuToggled: (bool open) => setState(() => isMenuOpen = open),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// DockSection: Versión sin BackdropFilter
// -----------------------------------------------------------------------
class DockSection extends StatelessWidget {
  final int currentIndex;
  final int selectedIconIndex;
  final Function(int) onTapIcon;
  final double iconSize;
  final double selectedBackgroundSize;
  final double iconSpacing;
  final MainAxisAlignment mainAxisAlignment;
  final EdgeInsetsGeometry padding;
  final Stream<int>? notificationCountStream;
  final Stream<int>? unreadMessagesCountStream;
  final double containerWidth;

  const DockSection({
    Key? key,
    required this.currentIndex,
    required this.selectedIconIndex,
    required this.onTapIcon,
    this.iconSize = 23.0,
    this.selectedBackgroundSize = 60.0,
    this.iconSpacing = 4.0,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.padding = const EdgeInsets.only(left: 40, right: 40, bottom: 20, top: 0),
    this.containerWidth = 328.0,
    this.notificationCountStream,
    this.unreadMessagesCountStream,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Container(
        height: 70,
        width: containerWidth,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: const BorderRadius.all(Radius.circular(60)),
        ),
        child: Row(
          mainAxisAlignment: mainAxisAlignment,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6.0),
              child: _buildIconButton(index: 0, asset: 'assets/casa.svg'),
            ),
            SizedBox(width: iconSpacing),
            _buildIconButton(index: 1, asset: 'assets/icono-mapa.svg'),
            SizedBox(width: iconSpacing),
            _buildIconButton(
              index: 2,
              asset: 'assets/anadir.svg',
              notificationCountStream: notificationCountStream,
              overrideIconSize: 70.0,
            ),
            SizedBox(width: iconSpacing),
            _buildIconButton(
              index: 3,
              asset: 'assets/mensaje.svg',
              unreadMessagesCountStream: unreadMessagesCountStream,
            ),
            SizedBox(width: iconSpacing),
            _buildIconButton(index: 4, asset: 'assets/usuario.svg'),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required int index,
    required String asset,
    Stream<int>? notificationCountStream,
    Stream<int>? unreadMessagesCountStream,
    double? overrideIconSize,
  }) {
    final double effectiveIconSize = overrideIconSize ?? iconSize;
    final bool isSelected = selectedIconIndex == index;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: () => onTapIcon(index),
          borderRadius: BorderRadius.circular(selectedBackgroundSize / 2),
          child: Container(
            width: selectedBackgroundSize,
            height: selectedBackgroundSize,
            alignment: Alignment.center,
            child: isSelected
                ? Container(
                    width: selectedBackgroundSize,
                    height: selectedBackgroundSize,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: asset.endsWith('.svg')
                          ? SvgPicture.asset(
                              asset,
                              color: AppColors.blue,
                              width: effectiveIconSize,
                              height: effectiveIconSize,
                            )
                          : Image.asset(
                              asset,
                              color: AppColors.blue,
                              width: effectiveIconSize,
                              height: effectiveIconSize,
                            ),
                    ),
                  )
                : Center(
                    child: asset.endsWith('.svg')
                        ? SvgPicture.asset(
                            asset,
                            color: Colors.white,
                            width: effectiveIconSize,
                            height: effectiveIconSize,
                          )
                        : Image.asset(
                            asset,
                            color: Colors.white,
                            width: effectiveIconSize,
                            height: effectiveIconSize,
                          ),
                  ),
          ),
        ),
        // Ejemplo si quieres poner un badge en este icono también...
      ],
    );
  }
}
