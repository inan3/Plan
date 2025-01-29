import 'package:dating_app/main/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      const Center(child: Text('Mensajes')),  // Placeholder
      const Center(child: Text('Perfil')),    // Placeholder
    ];
  }

  void _onSearchChanged(String value) {
    // tu lógica de búsqueda
  }

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

  /// Conteo de notificaciones únicamente para los tipos usados en MatchesScreen
  Stream<int> _notificationCountStream() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: currentUser?.uid)
        .where('type', whereIn: ['join_request', 'join_accepted', 'join_rejected'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Widget _buildExplorePage() {
    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 40),
            ExploreAppBar(
              onMenuPressed: () => _menuKey.currentState?.toggleMenu(),
              onFilterPressed: _onFilterPressed,
              onSearchChanged: _onSearchChanged,
            ),
            const SizedBox(height: 10),
            const PopularUsersSection(),
            const SizedBox(height: 10),
            Expanded(
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
                        'No hay usuarios disponibles.',
                        style: TextStyle(fontSize: 18, color: Colors.black),
                      ),
                    );
                  }

                  // Filtra al usuario actual (no lo muestres)
                  final validUsers = snapshot.data!.docs
                      .where((doc) => doc['uid'] != currentUser?.uid)
                      .toList();

                  return UsersGrid(users: validUsers);
                },
              ),
            ),
          ],
        ),
        // Menú lateral
        MainSideBarScreen(
          key: _menuKey,
          onMenuToggled: (bool open) {
            setState(() {
              isMenuOpen = open;
            });
          },
        ),

        // Botón "Unirse a Plan"
        if (_currentIndex == 0)
          Positioned(
            bottom: 80,
            left: 20,
            child: PlanActionButton(
              heroTag: 'joinPlan',
              label: 'Unirse a Plan',
              iconPath: 'assets/boton-union.png',
              onPressed: () {
                JoinPlanRequestScreen.showJoinPlanDialog(context);
              },
              margin: const EdgeInsets.only(left: 32, bottom: 70),
              borderColor: const Color.fromARGB(236, 0, 4, 227),
              borderWidth: 1,
              textColor: AppColors.blue,
              iconColor: AppColors.blue,
            ),
          ),

        // Botón "Crear Plan"
        if (_currentIndex == 0)
          Positioned(
            bottom: 80,
            right: 20,
            child: PlanActionButton(
              heroTag: 'createPlan',
              label: 'Crear Plan',
              iconPath: 'assets/boton-editar.png',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NewPlanCreationScreen(),
                  ),
                );
              },
              margin: const EdgeInsets.only(right: 8, bottom: 70),
              backgroundColor: AppColors.blue,
              borderWidth: 0,
              textColor: Colors.white,
              iconColor: Colors.white,
            ),
          ),
      ],
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
        backgroundColor: Colors.white,
        body: _pages[_currentIndex],

        bottomNavigationBar: Container(
          width: double.infinity,
          height: 60,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(vertical: 8),
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
              // Botón Explore
              IconButton(
                iconSize: _iconSize,
                icon: Icon(
                  Icons.location_on,
                  color: _currentIndex == 0
                      ? AppColors.blue
                      : const Color.fromARGB(57, 44, 43, 43),
                ),
                onPressed: () {
                  setState(() => _currentIndex = 0);
                },
              ),

              // Botón Notificaciones => MatchesScreen
              IconButton(
                iconSize: _iconSize,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.favorite,
                      color: _currentIndex == 1
                          ? AppColors.blue
                          : const Color.fromARGB(57, 44, 43, 43),
                    ),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: StreamBuilder<int>(
                        stream: _notificationCountStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data == 0) {
                            return const SizedBox();
                          }
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
                onPressed: () {
                  setState(() => _currentIndex = 1);
                },
              ),

              // Botón Mensajes (placeholder)
              IconButton(
                iconSize: _iconSize,
                icon: Icon(
                  Icons.message,
                  color: _currentIndex == 2
                      ? AppColors.blue
                      : const Color.fromARGB(57, 44, 43, 43),
                ),
                onPressed: () {
                  setState(() => _currentIndex = 2);
                },
              ),

              // Botón Perfil (placeholder)
              IconButton(
                iconSize: _iconSize,
                icon: Icon(
                  Icons.person,
                  color: _currentIndex == 3
                      ? AppColors.blue
                      : const Color.fromARGB(57, 44, 43, 43),
                ),
                onPressed: () {
                  setState(() => _currentIndex = 3);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
