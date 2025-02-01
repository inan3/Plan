import 'dart:ui'; // Para BackdropFilter, ImageFilter
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
import 'users_managing/user_info_check.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

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

  // Streams de notificaciones y mensajes
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
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                  const SizedBox(height: 100),
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
          height: 180,
          child: PopularUsersSection(),
        ),
      ),
    );
  }

  Widget _buildNearbySection() {
    // Retiramos el fondo para que use el mismo color del Scaffold
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 15),
        decoration: const BoxDecoration(
          // color: AppColors.nearbyBackground, // Eliminado
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
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
              height: MediaQuery.of(context).size.height * 0.55,
              child: StreamBuilder<QuerySnapshot>(
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

                  final validUsers = snapshot.data!.docs
                      .where((doc) => doc['uid'] != currentUser?.uid)
                      .toList();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: UsersGrid(
                      users: validUsers,
                      onUserTap: (userDoc) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserInfoCheck(userId: userDoc.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
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
                // Barra inferior con efecto frosted SOLO en su contenedor
                DockSection(
                  currentIndex: _currentIndex,
                  onTapIcon: (index) => setState(() => _currentIndex = index),
                  notificationCountStream: _notificationCountStream(),
                  unreadMessagesCountStream: _unreadMessagesCountStream(),
                ),
              ],
            ),

            // Botones flotantes SOLO si estamos en index=0 (Explore)
            if (_currentIndex == 0)
              Positioned(
                bottom: 100,
                left: 20,
                child: PlanActionButton(
                  heroTag: 'joinPlan',
                  label: 'Unirse a Plan',
                  iconPath: 'assets/union.png',
                  onPressed: () =>
                      JoinPlanRequestScreen.showJoinPlanDialog(context),
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
                    MaterialPageRoute(builder: (context) => NewPlanCreationScreen()),
                  ),
                  margin: const EdgeInsets.only(right: 0, bottom: 0),
                  backgroundColor: AppColors.blue,
                  borderWidth: 0,
                  textColor: Colors.white,
                  iconColor: Colors.white,
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
    );
  }
}

/// Barra inferior con efecto frosted en un contenedor fijo de 90px de alto.
/// No se utiliza forma ondulada ni `Positioned.fill`. Solo el contenedor
/// donde están los íconos para que el desenfoque afecte exclusivamente esa zona.
class DockSection extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTapIcon;
  final double iconSize;
  final Stream<int>? notificationCountStream;
  final Stream<int>? unreadMessagesCountStream;

  const DockSection({
    Key? key,
    required this.currentIndex,
    required this.onTapIcon,
    this.iconSize = 30.0,
    this.notificationCountStream,
    this.unreadMessagesCountStream,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      width: double.infinity,
      // Apilamos el BackdropFilter + fondo semitransparente + fila de íconos
      child: Stack(
        children: [
          // El BackdropFilter solo ocupa el contenedor de la barra
          ClipRRect(
            // Ajusta el radio si quieres esquinas redondeadas en la barra
            borderRadius: BorderRadius.zero,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                // Fondo semitransparente para resaltar el efecto
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          // Fila de íconos
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildIconButton(
                  index: 0,
                  asset: 'assets/casa.png',
                ),
                _buildIconButton(
                  index: 1,
                  asset: 'assets/corazon.png',
                  streamCount: notificationCountStream,
                ),
                _buildIconButton(
                  index: 2,
                  asset: 'assets/mensaje.png',
                  streamCount: unreadMessagesCountStream,
                ),
                _buildIconButton(
                  index: 3,
                  asset: 'assets/usuario.png',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required int index,
    required String asset,
    Stream<int>? streamCount,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          iconSize: iconSize,
          icon: Image.asset(
            asset,
            color: currentIndex == index ? AppColors.blue : Colors.black,
            width: 32,
            height: 32,
          ),
          onPressed: () => onTapIcon(index),
        ),
        if (streamCount != null)
          Positioned(
            right: -6,
            top: -6,
            child: StreamBuilder<int>(
              stream: streamCount,
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                if (count == 0) return const SizedBox();
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
