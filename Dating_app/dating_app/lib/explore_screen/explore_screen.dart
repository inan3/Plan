// explore_screen.dart
import 'dart:ui'; // Para BackdropFilter, ImageFilter, etc.
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
import 'chats/chats_screen.dart'; // Se importa la pantalla de mensajes actualizada
import 'users_managing/user_info_check.dart';
import 'search_screen.dart'; // Nuevo fichero para la pantalla de búsqueda
import 'profile_screen.dart'; // Importamos el fichero de gestión del perfil

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
  int selectedSearchIndex = 0; // 0: Hombres, 1: Mujeres, 2: Todo el mundo

  late List<Widget> _otherPages;

  @override
  void initState() {
    super.initState();
    _setStatusBarDark();
    _otherPages = [
      const SearchScreen(), // Nuevo: pantalla de búsqueda
      MatchesScreen(currentUserId: currentUser?.uid ?? ''),
      const ChatsScreen(), // Ahora no requiere 'chatPartnerId'
      ProfileScreen(),       // Gestión del perfil
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
    // Implementa la búsqueda si es necesario
  }

  // Carga la preferencia de "interest" del usuario actual para definir el filtro por defecto
  void _loadUserInterest() async {
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();

        if (userDoc.exists) {
          // Se asume que el campo 'interest' tiene valores "Hombres", "Mujeres" o "Todo el mundo"
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

  /// Construye la página de exploración usando una Column con Expanded
  Widget _buildExplorePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        children: [
          const SizedBox(height: 10),
          ExploreAppBar(
            onMenuPressed: () => _menuKey.currentState?.toggleMenu(),
            onFilterPressed: _onFilterPressed,
            onSearchChanged: _onSearchChanged,
          ),
          // Sección de usuarios populares
          _buildPopularSection(),
          // Sección "Cercanos" se expande para ocupar el espacio restante
          Expanded(child: _buildNearbySection()),
        ],
      ),
    );
  }

  /// Se envuelve PopularUsersSection en un Padding para aplicar el mismo margen lateral que "Cercanos"
  Widget _buildPopularSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: const SizedBox(
        height: 140,
        child: PopularUsersSection(),
      ),
    );
  }

  /// Se elimina el uso de SizedBox con altura fija y se utiliza Flexible para la grilla de usuarios
  Widget _buildNearbySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Flexible(
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

                // Excluir al usuario actual verificando el campo 'uid'
                final validUsers = snapshot.data!.docs.where((doc) {
                  final uid = doc.data() is Map<String, dynamic>
                      ? (doc.data() as Map<String, dynamic>)['uid']
                      : null;
                  return uid != null && uid != currentUser?.uid;
                }).toList();

                // Filtrar por género según selectedSearchIndex:
                List<QueryDocumentSnapshot> filteredUsers = validUsers;
                if (selectedSearchIndex == 0) { // Mostrar solo hombres
                  filteredUsers = validUsers
                      .where((doc) =>
                          (doc.data() as Map<String, dynamic>)['gender'] ==
                          'Hombre')
                      .toList();
                } else if (selectedSearchIndex == 1) { // Mostrar solo mujeres
                  filteredUsers = validUsers
                      .where((doc) =>
                          (doc.data() as Map<String, dynamic>)['gender'] ==
                          'Mujer')
                      .toList();
                }
                // Si selectedSearchIndex == 2 se muestran todos, sin filtrar por género.

                // Aplicar filtro por edad
                filteredUsers = filteredUsers.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final int userAge = int.tryParse(data['age'].toString()) ?? 0;
                  return userAge >= selectedAgeRange.start.round() &&
                      userAge <= selectedAgeRange.end.round();
                }).toList();

                // Convertir la lista de usuarios reales a una lista dinámica
                List<dynamic> allUsers = List.from(filteredUsers);

                // Crear 20 usuarios dummy
                List<Map<String, dynamic>> dummyUsers = List.generate(20, (index) {
                  return {
                    'uid': 'dummy_$index',
                    'gender': index % 2 == 0 ? 'Hombre' : 'Mujer',
                    'age': ((selectedAgeRange.start + selectedAgeRange.end) / 2).round(),
                    'name': 'Usuario Dummy $index',
                  };
                });

                // Añadir los usuarios dummy a la lista total
                allUsers.addAll(dummyUsers);

                return UsersGrid(
                  users: allUsers,
                  onUserTap: (userDoc) {
                    // Extraer datos comprobando si se trata de un QueryDocumentSnapshot o de un Map (dummy)
                    final Map<String, dynamic> data = userDoc is QueryDocumentSnapshot
                        ? (userDoc.data() as Map<String, dynamic>)
                        : userDoc as Map<String, dynamic>;
                    if (data['uid'].toString().startsWith('dummy_')) {
                      // Acción para usuario dummy: por ejemplo, mostrar un mensaje
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Usuario dummy: ${data['name']}")),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserInfoCheck(userId: userDoc.id),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
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
                // Si _currentIndex es 0 se muestra la página de exploración;
                // de lo contrario, se muestra la correspondiente de _otherPages
                Expanded(
                  child: _currentIndex == 0
                      ? _buildExplorePage()
                      : _otherPages[_currentIndex - 1],
                ),
                // La DockSection se coloca dentro de la Column para estar siempre visible
                DockSection(
                  currentIndex: _currentIndex,
                  onTapIcon: (index) => setState(() => _currentIndex = index),
                  notificationCountStream: _notificationCountStream(),
                  unreadMessagesCountStream: _unreadMessagesCountStream(),
                ),
              ],
            ),
            // Botones flotantes solo en la pestaña Explore
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
                    MaterialPageRoute(
                        builder: (context) => NewPlanCreationScreen()),
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

/// Barra inferior con efecto frosted (80px de alto) y 5 iconos de navegación.
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
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20), // Bordes redondeados como en la captura
        topRight: Radius.circular(20),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 80,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2), // Más translúcido
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.3), // Bordes más suaves
              width: 1,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildIconButton(index: 0, asset: 'assets/casa.png'),
                _buildIconButton(index: 1, asset: 'assets/lupa.png'),
                _buildIconButton(index: 2, asset: 'assets/corazon.png', streamCount: notificationCountStream),
                _buildIconButton(index: 3, asset: 'assets/mensaje.png', streamCount: unreadMessagesCountStream),
                _buildIconButton(index: 4, asset: 'assets/usuario.png'),
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

