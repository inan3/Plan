import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Ajusta estos imports a tus rutas reales
import '../main/colors.dart';
import 'explore_app_bar.dart';
import 'popular_users_section.dart';
import 'plan_action_button.dart'; // Widget modularizado
import 'filter_screen.dart';
import '../plan_creation/new_plan_creation_screen.dart';
import '../plan_joining/plan_join_request.dart';
import 'users_grid.dart'; 

// Importa tu Sidebar (fíjate en la ruta que tengas)
import 'menu_side_bar_screen.dart'; 

class ExploreScreen extends StatefulWidget {
  final ValueChanged<bool>? onMenuToggled;

  const ExploreScreen({Key? key, this.onMenuToggled}) : super(key: key);

  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Cambiamos a MainSideBarScreenState para que coincida con la definición en menu_side_bar_screen.dart
  final GlobalKey<MainSideBarScreenState> _menuKey =
      GlobalKey<MainSideBarScreenState>();

  bool isMenuOpen = false;

  // Filtros
  RangeValues selectedAgeRange = const RangeValues(18, 40);
  double selectedDistance = 50;
  int selectedSearchIndex = 0; // 0: Hombres, 1: Mujeres, 2: Todo el mundo

  @override
  void initState() {
    super.initState();
    _setStatusBarDark();
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
    // Lógica de búsqueda o filtrado
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

    // Maneja el resultado de FilterScreen
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        selectedAgeRange = result['ageRange'];
        selectedDistance = result['distance'];
        selectedSearchIndex = result['selection'];
      });
      _setStatusBarDark();
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
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 40),

                // Barra superior
                ExploreAppBar(
                  onMenuPressed: () => _menuKey.currentState?.toggleMenu(),
                  onFilterPressed: _onFilterPressed,
                  onSearchChanged: _onSearchChanged,
                ),

                const SizedBox(height: 10),

                // Sección de usuarios populares
                const PopularUsersSection(),
                const SizedBox(height: 10),

                // StreamBuilder para mostrar usuarios
                Expanded(
                  child: StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .snapshots(),
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

                      // Filtra para no incluirte a ti mismo
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
                widget.onMenuToggled?.call(open);
              },
            ),
          ],
        ),

        // Botones flotantes personalizados
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Botón para UNIRSE A PLAN (lado izquierdo)
            PlanActionButton(
              heroTag: 'joinPlan',
              label: 'Unirse a Plan',
              iconPath: 'assets/boton-union.png',
              onPressed: () {
                // Muestra un diálogo para unirse a un plan
                JoinPlanRequestScreen.showJoinPlanDialog(context);
              },
              margin: const EdgeInsets.only(left: 32, bottom: 70),
              backgroundColor: const Color(0xFF2ECC71),
            ),

            // Botón para CREAR PLAN (lado derecho)
            PlanActionButton(
              heroTag: 'createPlan',
              label: 'Crear Plan',
              iconPath: 'assets/boton-editar.png',
              onPressed: () {
                // Muestra un diálogo para crear un plan
                NewPlanCreationScreen.showNewPlanDialog(context);
              },
              margin: const EdgeInsets.only(right: 8, bottom: 70),
              backgroundColor: const Color(0xFF3498DB),
            ),
          ],
        ),
      ),
    );
  }
}
