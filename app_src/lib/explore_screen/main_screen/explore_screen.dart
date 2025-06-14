// explore_screen.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'explore_screen_filter.dart';
import 'explore_app_bar.dart';
import '../users_grid/users_grid.dart';
import '../menu_side_bar/menu_side_bar_screen.dart';
import '../chats/chats_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';
import 'notification_screen.dart';
import 'package:dating_app/plan_creation/new_plan_creation_screen.dart';
import 'searcher.dart';
import '../../tutorial/quick_start_guide.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExploreScreen extends StatefulWidget {
  final bool initiallyOpenSidebar;
  final bool showQuickStart;

  const ExploreScreen({
    Key? key,
    this.initiallyOpenSidebar = false,
    this.showQuickStart = false,
  }) : super(key: key);

  @override
  ExploreScreenState createState() => ExploreScreenState();
}

class ExploreScreenState extends State<ExploreScreen> {
  int _currentIndex = 0;
  int _selectedIconIndex = 0;

  User? _currentUser;
  final GlobalKey<MainSideBarScreenState> _menuKey =
      GlobalKey<MainSideBarScreenState>();
  final GlobalKey _addButtonKey = GlobalKey();
  final GlobalKey _homeButtonKey = GlobalKey();
  final GlobalKey _mapButtonKey = GlobalKey();
  final GlobalKey _chatButtonKey = GlobalKey();
  final GlobalKey _profileButtonKey = GlobalKey();
  final GlobalKey _menuIconKey = GlobalKey();
  final GlobalKey _notificationIconKey = GlobalKey();
  final GlobalKey _searchBarKey = GlobalKey();

  late bool isMenuOpen;
  RangeValues selectedAgeRange = const RangeValues(18, 40);
  double selectedDistance = 50;

  final Map<String, double> currentLocation = {'lat': 41.3851, 'lng': 2.1734};

  Map<String, dynamic> appliedFilters = {};

  late List<Widget> _otherPages;

  String _searchQuery = '';
  bool _showSearchResults = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    isMenuOpen = widget.initiallyOpenSidebar;
    _setStatusBarDark();
    _otherPages = [
      const MapScreen(),
      const ChatsScreen(),
      const ProfileScreen(),
    ];
    _currentIndex = 0;
    _selectedIconIndex = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _currentUser = FirebaseAuth.instance.currentUser;
      if (_currentUser == null) {
        final user = await FirebaseAuth.instance.authStateChanges().first;
        _currentUser = user;
      }
      if (_currentUser == null) return;

      setState(() {});

      final prefs = await SharedPreferences.getInstance();
      final userId = _currentUser!.uid;
      final key = 'quickStartShown_$userId';
      final alreadyShown = prefs.getBool(key) ?? false;
      if (widget.showQuickStart || !alreadyShown) {
        Future.delayed(const Duration(milliseconds: 500), () {
          QuickStartGuide(
            context: context,
            addButtonKey: _addButtonKey,
            homeButtonKey: _homeButtonKey,
            mapButtonKey: _mapButtonKey,
            chatButtonKey: _chatButtonKey,
            profileButtonKey: _profileButtonKey,
            menuButtonKey: _menuIconKey,
            notificationButtonKey: _notificationIconKey,
            searchBarKey: _searchBarKey,
            userId: userId,
          ).show();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setStatusBarDark() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  void _onSearchChanged(String value) {}

  void _onFilterPressed() async {
    final result =
        await showExploreFilterDialog(context, initialFilters: appliedFilters);
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

  void changePage(int pageIndex) {
    setState(() {
      _currentIndex = pageIndex;
      _selectedIconIndex = _mapPageIndexToDockIndex(pageIndex);
    });
  }

  Widget _buildExplorePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        children: [
          ExploreAppBar(
            onMenuPressed: () => _menuKey.currentState?.toggleMenu(),
            menuButtonKey: _menuIconKey,
            onNotificationPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationScreen(
                    currentUserId: _currentUser?.uid ?? '',
                  ),
                ),
              );
            },
            notificationButtonKey: _notificationIconKey,
            onSearchChanged: _onSearchChanged,
            notificationCountStream: _notificationCountStream(),
          ),
          _buildSearchContainer(),
          Expanded(
            child: _showSearchResults
                ? Searcher(
                    query: _searchQuery,
                    maxHeight: double.infinity,
                    isVisible: true,
                  )
                : _buildNearbySection(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchContainer() {
    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 15, top: 0, bottom: 10),
      child: Container(
        key: _searchBarKey,
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
                      Color.fromARGB(255, 13, 32, 53),
                      Color.fromARGB(255, 72, 38, 38),
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
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 230, 230, 230),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                            _showSearchResults = value.isNotEmpty;
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Buscar...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Colors.black54),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                            _showSearchResults = false;
                          });
                        },
                      ),
                  ],
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
    );
  }

  Future<List<String>> _fetchUserIdsWithPlans(
      List<String> planFilters, DateTime? dateFilter) async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('plans').get();
    final now = DateTime.now();
    Set<String> uids = {};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final Timestamp? ts = data['start_timestamp'];
      if (ts == null) continue;
      final startDate = ts.toDate();

      if (dateFilter != null) {
        if (startDate.year != dateFilter.year ||
            startDate.month != dateFilter.month ||
            startDate.day != dateFilter.day) {
          continue;
        }
      } else {
        if (!startDate.isAfter(now)) continue;
      }

      if (planFilters.isEmpty) {
        uids.add(data['createdBy'].toString());
      } else {
        final String planType = data['type']?.toString().toLowerCase() ?? '';
        for (var filter in planFilters) {
          if (planType.contains(filter.toLowerCase().trim())) {
            uids.add(data['createdBy'].toString());
            break;
          }
        }
      }
    }
    return uids.toList();
  }

  Future<List<QueryDocumentSnapshot>> _fetchNearbyUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    if (snapshot.docs.isEmpty) return [];

    List<QueryDocumentSnapshot> validUsers = snapshot.docs;

    if (_currentUser != null) {
      validUsers = validUsers.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['uid']?.toString() != _currentUser!.uid;
      }).toList();
    }

    // Filtrar solo usuarios seguidos si la opción está activada
    final bool onlyFollowed = appliedFilters['onlyFollowed'] == true;
    Set<String> followedIds = {};
    if (onlyFollowed && _currentUser != null) {
      final snap = await FirebaseFirestore.instance
          .collection('followed')
          .where('userId', isEqualTo: _currentUser!.uid)
          .get();
      for (final doc in snap.docs) {
        final fid = doc.data()['followedId'] as String?;
        if (fid != null) followedIds.add(fid);
      }
      validUsers = validUsers.where((doc) {
        final uid = (doc.data() as Map<String, dynamic>)['uid']?.toString();
        return uid != null && followedIds.contains(uid);
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
      final double latA =
          double.tryParse(dataA['latitude']?.toString() ?? '') ?? 0;
      final double lngA =
          double.tryParse(dataA['longitude']?.toString() ?? '') ?? 0;
      final double latB =
          double.tryParse(dataB['latitude']?.toString() ?? '') ?? 0;
      final double lngB =
          double.tryParse(dataB['longitude']?.toString() ?? '') ?? 0;
      final distanceA = computeDistance(referenceLat, referenceLng, latA, lngA);
      final distanceB = computeDistance(referenceLat, referenceLng, latB, lngB);
      return distanceA.compareTo(distanceB);
    });

    final bool onlyPlans = appliedFilters['onlyPlans'] == true;

    List<String> planFilters = [];
    if (appliedFilters['selectedPlans'] != null) {
      planFilters.addAll(List<String>.from(appliedFilters['selectedPlans']));
    }
    if (appliedFilters['planBusqueda'] != null &&
        (appliedFilters['planBusqueda'] as String).trim().isNotEmpty) {
      planFilters.add(appliedFilters['planBusqueda'] as String);
    }
    final DateTime? dateFilter = appliedFilters['planDate'];

    if (planFilters.isNotEmpty || dateFilter != null || onlyPlans) {
      final allowedUids = await _fetchUserIdsWithPlans(planFilters, dateFilter);
      validUsers = validUsers.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final uid = data['uid'].toString();
        return allowedUids.contains(uid);
      }).toList();
    }

    return validUsers;
  }

  Widget _buildNearbySection() {
    return FutureBuilder<List<QueryDocumentSnapshot>>( 
      future: _fetchNearbyUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.black));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No hay usuarios cercanos.',
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
          );
        }
        final List<QueryDocumentSnapshot> validUsers = snapshot.data!;
        return UsersGrid(users: validUsers);
      },
    );
  }

  Stream<int> _notificationCountStream() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: _currentUser?.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _unreadMessagesCountStream() {
    return FirebaseFirestore.instance
        .collection('messages')
        .where('participants', arrayContains: _currentUser?.uid)
        .where('receiverId', isEqualTo: _currentUser?.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  int _mapDockIndexToPageIndex(int dockIndex) {
    switch (dockIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        // El + abre creación de plan, no cambia de pantalla
        return _currentIndex;
      case 3:
        return 2;
      case 4:
        return 3;
      default:
        return _currentIndex;
    }
  }

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
      NewPlanCreationScreen.showPopup(context);
    } else {
      setState(() {
        _currentIndex = _mapDockIndexToPageIndex(dockIndex);
        _selectedIconIndex = dockIndex;
      });
    }
  }

  Future<bool> _handleBackPress() async {
    if (Navigator.of(context).canPop()) {
      return true;
    }

    if (isMenuOpen) {
      _menuKey.currentState?.toggleMenu();
      return false;
    }

    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
        _selectedIconIndex = 0;
      });
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: WillPopScope(
        onWillPop: _handleBackPress,
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
              _currentIndex == 0
                  ? _buildExplorePage()
                  : _otherPages[_currentIndex - 1],
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: DockSection(
                    currentIndex: _currentIndex,
                    selectedIconIndex: _selectedIconIndex,
                    onTapIcon: _onDockIconTap,
                    addButtonKey: _addButtonKey,
                    homeButtonKey: _homeButtonKey,
                    mapButtonKey: _mapButtonKey,
                    chatButtonKey: _chatButtonKey,
                    profileButtonKey: _profileButtonKey,
                    notificationCountStream: null,
                    unreadMessagesCountStream: _unreadMessagesCountStream(),
                    badgeSize: 10,
                    badgeOffsetX: 15,
                    badgeOffsetY: 15,
                  ),
                ),
              ),
              MainSideBarScreen(
                key: _menuKey,
                onMenuToggled: (bool open) => setState(() => isMenuOpen = open),
                onPageChange: changePage,
                initiallyOpenSidebar: widget.initiallyOpenSidebar,
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
  final GlobalKey addButtonKey;
  final GlobalKey homeButtonKey;
  final GlobalKey mapButtonKey;
  final GlobalKey chatButtonKey;
  final GlobalKey profileButtonKey;
  final double iconSize;
  final double selectedBackgroundSize;
  final double iconSpacing;
  final MainAxisAlignment mainAxisAlignment;
  final EdgeInsetsGeometry padding;
  final Stream<int>? notificationCountStream;
  final Stream<int>? unreadMessagesCountStream;

  /// Diámetro del punto rojo
  final double badgeSize;

  /// Desplazamiento del centro del badge respecto al centro del icono
  final double badgeOffsetX;
  final double badgeOffsetY;

  const DockSection({
    Key? key,
    required this.currentIndex,
    required this.selectedIconIndex,
    required this.onTapIcon,
    required this.addButtonKey,
    required this.homeButtonKey,
    required this.mapButtonKey,
    required this.chatButtonKey,
    required this.profileButtonKey,
    this.iconSize = 23.0,
    this.selectedBackgroundSize = 60.0,
    // Ajustamos iconSpacing para acercar los iconos.
    this.iconSpacing = 2.0,
    this.mainAxisAlignment = MainAxisAlignment.start,
    // Reducimos la separación lateral para que quepa el último icono.
    this.padding =
        const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 0),
    this.notificationCountStream,
    this.unreadMessagesCountStream,
    this.badgeSize = 10,
    this.badgeOffsetX = 10,
    this.badgeOffsetY = -10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          height: 70,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(255, 13, 32, 53),
                Color.fromARGB(255, 72, 38, 38),
                Color(0xFF12232E),
              ],
            ),
            borderRadius: BorderRadius.all(Radius.circular(60)),
          ),
          child: Row(
            mainAxisAlignment: mainAxisAlignment,
            children: [
              // margen interior izquierdo
              Padding(
                padding: const EdgeInsets.only(left: 6.0),
                child: _buildIconButton(
                  index: 0,
                  asset: 'assets/casa.svg',
                  targetKey: homeButtonKey,
                ),
              ),
              SizedBox(width: iconSpacing),
              _buildIconButton(
                index: 1,
                asset: 'assets/icono-mapa.svg',
                targetKey: mapButtonKey,
              ),
              SizedBox(width: iconSpacing),
              _buildIconButton(
                index: 2,
                asset: 'assets/anadir.svg',
                notificationCountStream: notificationCountStream,
                overrideIconSize: 70.0,
                targetKey: addButtonKey,
              ),
              SizedBox(width: iconSpacing),
              _buildIconButton(
                index: 3,
                asset: 'assets/mensaje.svg',
                unreadMessagesCountStream: unreadMessagesCountStream,
                targetKey: chatButtonKey,
              ),
              SizedBox(width: iconSpacing),
              _buildIconButton(
                index: 4,
                asset: 'assets/usuario.svg',
                targetKey: profileButtonKey,
              ),
              // margen interior derecho NUEVO
              const SizedBox(width: 6),
            ],
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
    Key? targetKey,
  }) {
    final double effectiveIconSize = overrideIconSize ?? iconSize;
    final bool isSelected = selectedIconIndex == index;

    Widget baseStack = Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: () => onTapIcon(index),
          borderRadius: BorderRadius.circular(selectedBackgroundSize / 2),
          child: Container(
            key: targetKey,
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
                                    Color.fromARGB(255, 13, 32, 53),
                                    Color.fromARGB(255, 72, 38, 38),
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
                                    Color.fromARGB(255, 13, 32, 53),
                                    Color.fromARGB(255, 72, 38, 38),
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

    // Si no es el icono de mensajes, retornamos baseStack directamente
    if (index != 3 || unreadMessagesCountStream == null) {
      return baseStack;
    }

    // Si ES el icono de mensajes (index=3) y hay unreadMessagesCountStream
    return StreamBuilder<int>(
      stream: unreadMessagesCountStream,
      builder: (context, snapshot) {
        final int unreadCount = snapshot.data ?? 0;
        final bool showBadge = unreadCount > 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            baseStack,
            if (showBadge)
              Positioned(
                right: badgeOffsetX,
                top: badgeOffsetY,
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
