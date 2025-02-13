import 'dart:math' as math;
import 'dart:ui'; // Para BackdropFilter, ImageFilter, etc.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dating_app/main/colors.dart';

// Importa el diálogo de filtros
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
import 'add_plan_screen.dart';
import 'package:dating_app/plan_creation/new_plan_creation_screen.dart';
import 'package:dating_app/plan_joining/plan_join_request.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  ExploreScreenState createState() => ExploreScreenState();
}

class ExploreScreenState extends State<ExploreScreen> {
  int _currentIndex = 0;
  final double _iconSize = 30.0;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<MainSideBarScreenState> _menuKey =
      GlobalKey<MainSideBarScreenState>();

  bool isMenuOpen = false;
  RangeValues selectedAgeRange = const RangeValues(18, 40);
  double selectedDistance = 50;
  int selectedSearchIndex = 0; // 0: Hombres, 1: Mujeres, 2: Todo el mundo

  // Suponemos que conocemos la ubicación actual del usuario (ejemplo: Barcelona).
  final Map<String, double> currentLocation = {'lat': 41.3851, 'lng': 2.1734};

  // Este mapa se actualizará cuando se apliquen los filtros desde el diálogo.
  Map<String, dynamic> appliedFilters = {};

  // Variables para controlar el espacio entre secciones
  double _spacingPopularToNearby = 10;
  double _popularTopSpacing = 5;

  late List<Widget> _otherPages;

  @override
  void initState() {
    super.initState();
    _setStatusBarDark();
    _otherPages = [
      const SearchScreen(),
      const AddPlanScreen(),
      const ChatsScreen(),
      ProfileScreen(),
    ];
    _loadUserInterest();
  }

  void _setStatusBarDark() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  void _onSearchChanged(String value) {
    // Implementa la búsqueda si es necesario.
  }

  void _onFilterPressed() async {
    // Abre el diálogo de filtros y actualiza los filtros aplicados
    final result = await showExploreFilterDialog(context);
    if (result != null) {
      setState(() {
        appliedFilters = result;
      });
    }
  }

  // Carga la preferencia de "interest" (Hombres/Mujeres/Todo el mundo).
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

  // Función para calcular la distancia entre dos puntos (Haversine)
  double computeDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371; // en km
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

  double _deg2rad(double deg) {
    return deg * (math.pi / 180);
  }

  /// Construye la pantalla Explore con el AppBar y las secciones correspondientes.
  Widget _buildExplorePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        children: [
          // AppBar de Explore (fijo)
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
            // Se pasa el stream para mostrar el badge en el icono de notificación
            notificationCountStream: _notificationCountStream(),
          ),
          // Sección de usuarios populares (fija)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: PopularUsersSection(
              topSpacing: _popularTopSpacing,
            ),
          ),
          SizedBox(height: _spacingPopularToNearby),
          // Sección de usuarios cercanos: desplazable.
          Expanded(child: _buildNearbySection()),
        ],
      ),
    );
  }

  /// Sección de usuarios cercanos.
  Widget _buildNearbySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.black),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No hay usuarios cercanos.',
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
          );
        }

        // Excluir al usuario actual.
        final validUsers = snapshot.data!.docs.where((doc) {
          final uid = doc.data() is Map<String, dynamic>
              ? (doc.data() as Map<String, dynamic>)['uid']
              : null;
          return uid != null && uid != currentUser?.uid;
        }).toList();

        // Filtrar por género según selectedSearchIndex.
        List<QueryDocumentSnapshot> filteredUsers = validUsers;
        if (selectedSearchIndex == 0) {
          filteredUsers = validUsers
              .where((doc) =>
                  (doc.data() as Map<String, dynamic>)['gender'] == 'Hombre')
              .toList();
        } else if (selectedSearchIndex == 1) {
          filteredUsers = validUsers
              .where((doc) =>
                  (doc.data() as Map<String, dynamic>)['gender'] == 'Mujer')
              .toList();
        }

        // Filtrar por rango de edad.
        filteredUsers = filteredUsers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final int userAge = int.tryParse(data['age'].toString()) ?? 0;
          return userAge >= selectedAgeRange.start.round() &&
              userAge <= selectedAgeRange.end.round();
        }).toList();

        // Filtrar por región si se aplicó el filtro.
        if (appliedFilters.containsKey('regionBusqueda') &&
            (appliedFilters['regionBusqueda'] as String).isNotEmpty) {
          final String regionFilter =
              (appliedFilters['regionBusqueda'] as String).toLowerCase();
          filteredUsers = filteredUsers.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String city = (data['city'] ?? '').toString().toLowerCase();
            final String country =
                (data['country'] ?? '').toString().toLowerCase();
            return city.contains(regionFilter) || country.contains(regionFilter);
          }).toList();
        }

        // Ordenar por distancia respecto a la ubicación actual.
        filteredUsers.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final double latA =
              double.tryParse(dataA['latitude']?.toString() ?? '') ?? 0;
          final double lngA =
              double.tryParse(dataA['longitude']?.toString() ?? '') ?? 0;
          final double latB =
              double.tryParse(dataB['latitude']?.toString() ?? '') ?? 0;
          final double lngB =
              double.tryParse(dataB['longitude']?.toString() ?? '') ?? 0;
          final distanceA = computeDistance(
              currentLocation['lat']!, currentLocation['lng']!, latA, lngA);
          final distanceB = computeDistance(
              currentLocation['lat']!, currentLocation['lng']!, latB, lngB);
          return distanceA.compareTo(distanceB);
        });

        final allUsers = filteredUsers;

        return UsersGrid(
          users: allUsers,
          onUserTap: (userDoc) {
            final Map<String, dynamic> data = userDoc is QueryDocumentSnapshot
                ? (userDoc.data() as Map<String, dynamic>)
                : userDoc as Map<String, dynamic>;
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

  // Se muestra el badge de notificaciones para el ExploreAppBar.
  Stream<int> _notificationCountStream() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: currentUser?.uid)
        .where('type',
            whereIn: ['join_request', 'join_accepted', 'join_rejected'])
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

  /// Método para mostrar el pop up con las opciones "Crear Plan" y "Unirse a Plan"
  /// posicionado justo arriba del dock, compartiendo el mismo fondo.
  void _showPlanOptionsPopup(BuildContext context) {
    // Valores para posicionar el pop up: el dock se posiciona a 20 desde abajo y tiene altura 70.
    const double dockBottomMargin = 50.0;
    const double dockHeight = 70.0;

    showGeneralDialog(
      context: context,
      barrierLabel: "Plan Options",
      barrierDismissible: true,
      barrierColor: Colors.transparent, // Sin oscurecer el fondo
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Stack(
          children: [
            // El Positioned limita el tamaño al contenido del pop up.
            Positioned(
              bottom: dockBottomMargin + dockHeight,
              left: 40,
              right: 40,
              child: Material(
                color: Colors.transparent,
                // Dentro de showGeneralDialog en _showPlanOptionsPopup...
                // Dentro de showGeneralDialog en _showPlanOptionsPopup...
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black26, // Mismo fondo que el dock
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Sólo ocupa lo justo para sus hijos
                    children: [
                      // Botón "Crear Plan" con icono de assets/anadir.svg
                      InkWell(
                        onTap: () {
                          Navigator.of(context).pop(); // Cierra el pop up
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NewPlanCreationScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          // Fijamos la altura del botón para que no cambie según el icono
                          height: 60,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Icono en un SizedBox de tamaño fijo
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: SvgPicture.asset(
                                  'assets/anadir.svg',
                                  color: Colors.white,
                                  // Puedes ajustar scale o BoxFit si es necesario
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
                      // Línea fina blanca separadora
                      Container(
                        height: 1,
                        color: Colors.white,
                      ),
                      // Botón "Unirse a Plan" con icono de assets/union.svg
                      InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          JoinPlanRequestScreen.showJoinPlanDialog(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          height: 60,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
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
                                "Unirse a Plan",
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
            )
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: child,
        );
      },
    );
  }

  // Nuevo callback para el Dock: si se pulsa el ícono de anadir (índice 2), se muestra el pop up.
  void _onDockIconTap(int index) {
    if (index == 2) {
      _showPlanOptionsPopup(context);
    } else {
      setState(() {
        _currentIndex = index;
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
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            _currentIndex == 0
                ? _buildExplorePage()
                : _otherPages[_currentIndex - 1],
            // Barra inferior fija con efecto frosted.
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: DockSection(
                  currentIndex: _currentIndex,
                  onTapIcon: _onDockIconTap,
                  // Se elimina el stream de notificaciones para evitar que aparezca en "anadir.svg"
                  notificationCountStream: null,
                  unreadMessagesCountStream: _unreadMessagesCountStream(),
                ),
              ),
            ),
            // Menú lateral.
            MainSideBarScreen(
              key: _menuKey,
              onMenuToggled: (bool open) => setState(() => isMenuOpen = open),
            ),
          ],
        ),
      ),
    );
  }
}

// Asegúrate de que solo exista UNA definición de DockSection en tu proyecto.
class DockSection extends StatelessWidget {
  final int currentIndex;
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
    super.key,
    required this.currentIndex,
    required this.onTapIcon,
    this.iconSize = 23.0,
    this.selectedBackgroundSize = 60.0,
    this.iconSpacing = 4.0,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.padding = const EdgeInsets.only(left: 40, right: 40, bottom: 20, top: 0),
    this.containerWidth = 328.0,
    this.notificationCountStream,
    this.unreadMessagesCountStream,
  });

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
    final bool isSelected = currentIndex == index;
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
