import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dating_app/main/colors.dart';

import 'explore_screen_filter.dart';
import 'explore_app_bar.dart';
import 'users_grid.dart';
import 'menu_side_bar/menu_side_bar_screen.dart';
import 'chats/chats_screen.dart';
import 'users_managing/user_info_check.dart';
import 'map/map_screen.dart';
import 'profile/profile_screen.dart';
import 'notification_screen.dart';
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

  final Map<String, double> currentLocation = {'lat': 41.3851, 'lng': 2.1734};

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
      const ProfileScreen(),
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

  void _onSearchChanged(String value) {}

  void _onFilterPressed() async {
    final result = await showExploreFilterDialog(context, initialFilters: appliedFilters);
    if (result != null) {
      setState(() {
        appliedFilters = result;
        selectedAgeRange = RangeValues(
          (result['edadMin'] ?? 18).toDouble(),
          (result['edadMax'] ?? 40).toDouble(),
        );
      });
    }
  }

  double computeDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371;
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

  // Nueva función para cambiar la página desde el menú lateral
  void changePage(int pageIndex) {
    setState(() {
      _currentIndex = pageIndex;
      _selectedIconIndex = _mapPageIndexToDockIndex(pageIndex);
      if (_showPopup) {
        _showPopup = false;
      }
    });
  }

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
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0D253F),
                      Color(0xFF1B3A57),
                      Color(0xFF12232E),
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcIn,
                child: SvgPicture.asset(
                  'assets/lupa.svg',
                  width: 24,
                  height: 24,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                onChanged: (value) {},
                decoration: const InputDecoration(
                  hintText: 'Buscar...',
                  border: InputBorder.none,
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
                      Color(0xFF0D253F),
                      Color(0xFF1B3A57),
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
    );
  }

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

        if (currentUser != null) {
          validUsers = validUsers.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['uid']?.toString() != currentUser!.uid;
          }).toList();
        }

        validUsers = validUsers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final int userAge = int.tryParse(data['age'].toString()) ?? 0;
          return userAge >= selectedAgeRange.start.round() &&
              userAge <= selectedAgeRange.end.round();
        }).toList();

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

  Stream<int> _unreadMessagesCountStream() {
    return FirebaseFirestore.instance
        .collection('messages')
        .where('receiverId', isEqualTo: currentUser?.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

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
        return 0;
      case 1:
        return 1;
      case 3:
        return 2;
      case 4:
        return 3;
      default:
        return _currentIndex;
    }
  }

  // Nueva función para mapear el índice de página al índice del dock
  int _mapPageIndexToDockIndex(int pageIndex) {
    switch (pageIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 3;
      case 3:
        return 4;
      default:
        return _selectedIconIndex;
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
                    notificationCountStream: null,
                    unreadMessagesCountStream: _unreadMessagesCountStream(),
                  ),
                ),
              ),
              MainSideBarScreen(
                key: _menuKey,
                onMenuToggled: (bool open) => setState(() => isMenuOpen = open),
                onPageChange: changePage, // Pasamos la función para cambiar la página
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        decoration: const BoxDecoration(
          // Aquí aplicamos la MISMA decoración con degradado
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D253F),
              Color(0xFF1B3A57),
              Color(0xFF12232E),
            ],
          ),
          borderRadius: BorderRadius.all(Radius.circular(60)),
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
                          ? ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF0D253F),
                                    Color(0xFF1B3A57),
                                    Color(0xFF12232E),
                                  ],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.srcIn,
                              child: SvgPicture.asset(
                                asset,
                                width: effectiveIconSize,
                                height: effectiveIconSize,
                              ),
                            )
                          : ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF0D253F),
                                    Color(0xFF1B3A57),
                                    Color(0xFF12232E),
                                  ],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.srcIn,
                              child: Image.asset(
                                asset,
                                width: effectiveIconSize,
                                height: effectiveIconSize,
                              ),
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
      ],
    );
  }
}
