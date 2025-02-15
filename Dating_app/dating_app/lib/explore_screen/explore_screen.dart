import 'dart:math' as math;
import 'dart:ui'; // Para BackdropFilter, ImageFilter, etc.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dating_app/main/colors.dart';

// Importa el diálogo de filtros (puede seguir usando el mismo si lo requieres)
import 'explore_screen_filter.dart';

import 'explore_app_bar.dart';
import 'popular_users_section.dart';
import 'users_grid.dart';
import 'menu_side_bar_screen.dart';
import 'chats/chats_screen.dart'; // Pantalla de mensajes
import 'users_managing/user_info_check.dart';
import 'search_screen.dart'; // Pantalla de búsqueda
import 'profile_screen.dart'; // Gestión del perfil
import 'notification_screen.dart'; // Pantalla de notificaciones
import 'package:dating_app/plan_creation/new_plan_creation_screen.dart';
import 'package:dating_app/plan_joining/plan_join_request.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  ExploreScreenState createState() => ExploreScreenState();
}

class ExploreScreenState extends State<ExploreScreen> {
  // _currentIndex: pestaña activa (0: Explore, 1: Search, 2: Chats, 3: Perfil)
  int _currentIndex = 0;
  // _selectedIconIndex: icono resaltado en el dock (índices 0..4; 2 es "añadir")
  int _selectedIconIndex = 0;
  // Variable para controlar si se muestra el pop up (no modal)
  bool _showPopup = false;

  final double _iconSize = 30.0;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<MainSideBarScreenState> _menuKey = GlobalKey<MainSideBarScreenState>();

  bool isMenuOpen = false;
  RangeValues selectedAgeRange = const RangeValues(18, 40);
  double selectedDistance = 50;
  int selectedSearchIndex = 0; // 0: Hombres, 1: Mujeres, 2: Todo el mundo

  // Ubicación actual (ejemplo: Barcelona)
  final Map<String, double> currentLocation = {'lat': 41.3851, 'lng': 2.1734};

  // Filtros aplicados desde el diálogo.
  Map<String, dynamic> appliedFilters = {};

  // Espaciado entre secciones.
  double _spacingPopularToNearby = 10;
  double _popularTopSpacing = 5;

  // Lista de páginas para las pestañas (excepto Explore que es 0)
  late List<Widget> _otherPages;

  @override
  void initState() {
    super.initState();
    _setStatusBarDark();
    // Definición de páginas: 1 → Search, 2 → Chats, 3 → Perfil.
    _otherPages = [
      const SearchScreen(),
      const ChatsScreen(),
      ProfileScreen(),
    ];
    _loadUserInterest();
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
    // Implementa la búsqueda si es necesario.
  }

  void _onFilterPressed() async {
    final result = await showExploreFilterDialog(context);
    if (result != null) {
      setState(() {
        appliedFilters = result;
      });
    }
  }

  void _loadUserInterest() async {
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();
        if (userDoc.exists) {
          final String interest = userDoc['interest'].toString();
          int defaultIndex;
          if (interest == 'Hombres') {
            defaultIndex = 0;
          } else if (interest == 'Mujeres') {
            defaultIndex = 1;
          } else {
            defaultIndex = 2;
          }
          setState(() {
            selectedSearchIndex = defaultIndex;
          });
        }
      } catch (e) {
        print('Error al cargar la preferencia del usuario: $e');
      }
    }
  }

  // Función para calcular la distancia (Haversine)
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
            onFilterPressed: _onFilterPressed,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: PopularUsersSection(topSpacing: _popularTopSpacing),
          ),
          SizedBox(height: _spacingPopularToNearby),
          Expanded(child: _buildNearbySection()),
        ],
      ),
    );
  }

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
        final validUsers = snapshot.data!.docs.where((doc) {
          final uid = doc.data() is Map<String, dynamic>
              ? (doc.data() as Map<String, dynamic>)['uid']
              : null;
          return uid != null && uid != currentUser?.uid;
        }).toList();

        List<QueryDocumentSnapshot> filteredUsers = validUsers;
        if (selectedSearchIndex == 0) {
          filteredUsers = validUsers.where((doc) =>
              (doc.data() as Map<String, dynamic>)['gender'] == 'Hombre').toList();
        } else if (selectedSearchIndex == 1) {
          filteredUsers = validUsers.where((doc) =>
              (doc.data() as Map<String, dynamic>)['gender'] == 'Mujer').toList();
        }

        filteredUsers = filteredUsers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final int userAge = int.tryParse(data['age'].toString()) ?? 0;
          return userAge >= selectedAgeRange.start.round() &&
              userAge <= selectedAgeRange.end.round();
        }).toList();

        if (appliedFilters.containsKey('regionBusqueda') &&
            (appliedFilters['regionBusqueda'] as String).isNotEmpty) {
          final String regionFilter = (appliedFilters['regionBusqueda'] as String).toLowerCase();
          filteredUsers = filteredUsers.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String city = (data['city'] ?? '').toString().toLowerCase();
            final String country = (data['country'] ?? '').toString().toLowerCase();
            return city.contains(regionFilter) || country.contains(regionFilter);
          }).toList();
        }

        filteredUsers.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final double latA = double.tryParse(dataA['latitude']?.toString() ?? '') ?? 0;
          final double lngA = double.tryParse(dataA['longitude']?.toString() ?? '') ?? 0;
          final double latB = double.tryParse(dataB['latitude']?.toString() ?? '') ?? 0;
          final double lngB = double.tryParse(dataB['longitude']?.toString() ?? '') ?? 0;
          final distanceA = computeDistance(currentLocation['lat']!, currentLocation['lng']!, latA, lngA);
          final distanceB = computeDistance(currentLocation['lat']!, currentLocation['lng']!, latB, lngB);
          return distanceA.compareTo(distanceB);
        });

        return UsersGrid(
          users: filteredUsers,
          onUserTap: (userDoc) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserInfoCheck(userId: userDoc.id),
              ),
            );
          },
        );
      },
    );
  }

  Stream<int> _notificationCountStream() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: currentUser?.uid)
        .where('type', whereIn: ['join_request', 'join_accepted', 'join_rejected'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _unreadMessagesCountStream() {
    return FirebaseFirestore.instance
        .collection('messages')
        .where('receiverId', isEqualTo: currentUser?.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Pop up no modal con las opciones "Crear Plan" y "Unirse a Plan"
  Widget _buildPopup() {
    const double dockBottomMargin = 50.0;
    const double dockHeight = 70.0;
    return Positioned(
      // Posicionar el pop up en la parte superior del dock
      bottom: dockBottomMargin + dockHeight,
      left: 40,
      right: 40,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 38, 37, 37).withOpacity(0.3),
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
                              fit: BoxFit.contain,
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
                  // Línea separadora
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
                              fit: BoxFit.contain,
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
        ),
      ),
    );
  }

  // Mapea el índice del dock (0,1,3,4) a la página correspondiente.
  int _mapDockIndexToPageIndex(int dockIndex) {
    switch (dockIndex) {
      case 0:
        return 0; // Explore
      case 1:
        return 1; // Search
      case 3:
        return 2; // Chats
      case 4:
        return 3; // Perfil
      default:
        return _currentIndex;
    }
  }

  // Callback para el tap en el dock.
  void _onDockIconTap(int dockIndex) {
    if (dockIndex == 2) {
      // Pulsado "añadir": mostrar el pop up y resaltar el icono
      setState(() {
        _selectedIconIndex = 2;
        _showPopup = true;
      });
    } else {
      // Si se pulsa otro icono, cerramos el pop up (si está abierto) y navegamos inmediatamente
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
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 239, 235, 243),
                Color.fromARGB(255, 232, 223, 242),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              // Página actual (Explore o la otra según _currentIndex)
              _currentIndex == 0 ? _buildExplorePage() : _otherPages[_currentIndex - 1],
              // Pop up no modal (visible si _showPopup es true)
              if (_showPopup) _buildPopup(),
              // Dock inferior (siempre encima del pop up)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: DockSection(
                    currentIndex: _currentIndex,
                    selectedIconIndex: _selectedIconIndex,
                    onTapIcon: _onDockIconTap,
                    notificationCountStream: null,
                    unreadMessagesCountStream: _unreadMessagesCountStream(),
                  ),
                ),
              ),
              // Menú lateral
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

// ---------------------
// DEFINICIÓN DEL DOCK
// ---------------------
class DockSection extends StatelessWidget {
  final int currentIndex; // Opcional, para lógica extra
  final int selectedIconIndex; // Ícono resaltado (0..4)
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
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(50)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
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
                _buildIconButton(index: 1, asset: 'assets/lupa.svg'),
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
                : SizedBox(
                    width: selectedBackgroundSize,
                    height: selectedBackgroundSize,
                    child: Center(
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
        ),
        if (notificationCountStream != null)
          Positioned(
            right: 2,
            top: 2,
            child: StreamBuilder<int>(
              stream: notificationCountStream,
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                if (count == 0) return const SizedBox();
                if (index == 3) {
                  return Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                    ),
                  );
                }
                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
