import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dating_app/main/colors.dart';
import 'explore_app_bar.dart';
import 'popular_users_section.dart';
import 'plan_action_button.dart';
import 'filter_screen.dart';
import '../plan_creation/new_plan_creation_screen.dart';
import '../plan_joining/plan_join_request.dart';
import 'users_grid.dart';
import 'menu_side_bar_screen.dart';
import 'matches_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  ExploreScreenState createState() => ExploreScreenState();
}

class ExploreScreenState extends State<ExploreScreen> {
  int _currentIndex = 0;
  final double _iconSize = 30.0;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<MainSideBarScreenState> _menuKey = GlobalKey<MainSideBarScreenState>();

  bool isMenuOpen = false;
  RangeValues selectedAgeRange = const RangeValues(18, 40);
  double selectedDistance = 50;
  int selectedSearchIndex = 0;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _setStatusBarDark();
    _initializePages();
  }

  void _setStatusBarDark() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  void _initializePages() {
    _pages = [
      _buildExplorePage(),
      MatchesScreen(currentUserId: currentUser?.uid ?? ''),
      const Center(child: Text('Mensajes')),
      const Center(child: Text('Perfil')),
    ];
  }

  void _onSearchChanged(String value) {}

  void _onFilterPressed() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilterScreen(
          initialAgeRange: selectedAgeRange,
          initialDistance: selectedDistance,
          initialSelection: selectedSearchIndex,
        ),
      ),
    );

    if (!mounted) return;
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        selectedAgeRange = result['ageRange'];
        selectedDistance = result['distance'];
        selectedSearchIndex = result['selection'];
      });
      _setStatusBarDark();
    }
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

  Widget _buildExplorePage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  ExploreAppBar(
                    onMenuPressed: () => _menuKey.currentState?.toggleMenu(),
                    onFilterPressed: _onFilterPressed,
                    onSearchChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 10),
                  _buildPopularSection(),
                  _buildNearbySection(),
                  const SizedBox(height: 100), // Espacio para los botones flotantes
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopularSection() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: AppColors.popularBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const SizedBox(
          height: 180, // Cambiado de 150 a 180
          child: PopularUsersSection(),
        ),
      ),
    );
  }

Widget _buildNearbySection() {
  return ClipRRect(
    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: AppColors.nearbyBackground,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 20, top: 15, bottom: 10),
            child: Text(
              'Cercanos',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55, // Altura dinámica
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
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

                  final validUsers = snapshot.data!.docs
                      .where((doc) => doc['uid'] != currentUser?.uid)
                      .toList();

                  return Padding(
                  padding: const EdgeInsets.only(bottom: 2), // Margen inferior
                  child: UsersGrid(users: validUsers),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildBottomDock() {
    return Center(
      child: Container(
        width: 250,
        height: 60,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: AppColors.blue,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              iconSize: _iconSize,
              icon: Image.asset(
                'assets/casa.png',
                color: _currentIndex == 0 ? AppColors.blue : Colors.black,
                width: 32,
                height: 32,
              ),
              onPressed: () => setState(() => _currentIndex = 0),
            ),
            IconButton(
              iconSize: _iconSize,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Image.asset(
                    'assets/corazon.png',
                    color: _currentIndex == 1 ? AppColors.blue : Colors.black,
                    width: 32,
                    height: 32,
                  ),
                  Positioned(
                    right: -6,
                    top: -6,
                    child: StreamBuilder<int>(
                      stream: _notificationCountStream(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data == 0) return const SizedBox();
                        final count = snapshot.data!;
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
              ),
              onPressed: () => setState(() => _currentIndex = 1),
            ),
            IconButton(
              iconSize: _iconSize,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Image.asset(
                    'assets/mensaje.png',
                    color: _currentIndex == 2 ? AppColors.blue : Colors.black,
                    width: 32,
                    height: 32,
                  ),
                  StreamBuilder<int>(
                    stream: _unreadMessagesCountStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data! > 0) {
                        return Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
              onPressed: () => setState(() => _currentIndex = 2),
            ),
            IconButton(
              iconSize: _iconSize,
              icon: Image.asset(
                'assets/usuario.png',
                color: _currentIndex == 3 ? AppColors.blue : Colors.black,
                width: 32,
                height: 32,
              ),
              onPressed: () => setState(() => _currentIndex = 3),
            ),
          ],
        ),
      ),
    );
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
            Column(
              children: [
                Expanded(child: _pages[_currentIndex]),
                _buildBottomDock(),
              ],
            ),

            if (_currentIndex == 0)
              Positioned(
                bottom: 100,
                left: 20,
                child: PlanActionButton(
                  heroTag: 'joinPlan',
                  label: 'Unirse a Plan',
                  iconPath: 'assets/union.png',
                  onPressed: () => JoinPlanRequestScreen.showJoinPlanDialog(context),
                  margin: const EdgeInsets.only(left: 0, bottom: 0),
                  borderColor: const Color.fromARGB(236, 0, 4, 227),
                  borderWidth: 1,
                  textColor: AppColors.blue,
                  iconColor: AppColors.blue,
                ),
              ),

            if (_currentIndex == 0)
              Positioned(
                bottom: 100,
                right: 20,
                child: PlanActionButton(
                  heroTag: 'createPlan',
                  label: 'Crear Plan',
                  iconPath: 'assets/anadir.png',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NewPlanCreationScreen(),
                    ),
                  ),
                  margin: const EdgeInsets.only(right: 0, bottom: 0),
                  backgroundColor: AppColors.blue,
                  borderWidth: 0,
                  textColor: Colors.white,
                  iconColor: Colors.white,
                ),
              ),

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