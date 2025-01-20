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
import 'menu_side_bar_screen.dart'; // Menú lateral

class ExploreScreen extends StatefulWidget {
  final ValueChanged<bool>? onMenuToggled;

  const ExploreScreen({Key? key, this.onMenuToggled}) : super(key: key);

  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<MainSideBarScreenState> _menuKey =
      GlobalKey<MainSideBarScreenState>();

  bool isMenuOpen = false;

  // Filtros
  RangeValues selectedAgeRange = const RangeValues(18, 40);
  double selectedDistance = 50;
  int selectedSearchIndex = 0;

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

                      final validUsers = snapshot.data!.docs
                          .where((doc) => doc['uid'] != currentUser?.uid)
                          .toList();

                      return UsersGrid(users: validUsers);
                    },
                  ),
                ),
              ],
            ),
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
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Botón "Unirse a Plan"
            PlanActionButton(
              heroTag: 'joinPlan',
              label: 'Unirse a Plan',
              iconPath: 'assets/boton-union.png',
              onPressed: () {
                JoinPlanRequestScreen.showJoinPlanDialog(context);
              },
              margin: const EdgeInsets.only(left: 32, bottom: 70),
              backgroundColor: Colors.white,
              borderColor: const Color.fromARGB(236, 0, 4, 227), // Color azul
              borderWidth: 1, // Grosor del borde ajustable
              textColor: AppColors.blue,
              iconColor: AppColors.blue,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),

            // Botón "Crear Plan"
            PlanActionButton(
              heroTag: 'createPlan',
              label: 'Crear Plan',
              iconPath: 'assets/boton-editar.png',
              onPressed: () {
                NewPlanCreationScreen.showNewPlanDialog(context);
              },
              margin: const EdgeInsets.only(right: 8, bottom: 70),
              backgroundColor: AppColors.blue, // Fondo azul
              borderColor: Colors.transparent, // Sin borde
              borderWidth: 0,
              textColor: Colors.white, // Texto blanco
              iconColor: Colors.white, // Icono blanco
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PlanActionButton extends StatelessWidget {
  final String heroTag;
  final String label;
  final String iconPath;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry? margin;
  final Color backgroundColor;
  final Color? borderColor; // Nuevo parámetro para el borde
  final double borderWidth; // Nuevo parámetro para el grosor del borde
  final Color? textColor; // Nuevo parámetro para el texto
  final Color? iconColor; // Nuevo parámetro para el color del icono
  final List<BoxShadow>? boxShadow;

  const PlanActionButton({
    Key? key,
    required this.heroTag,
    required this.label,
    required this.iconPath,
    required this.onPressed,
    this.margin,
    required this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0, // Valor por defecto
    this.textColor,
    this.iconColor,
    this.boxShadow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: borderColor ?? Colors.transparent, // Color del borde
          width: borderWidth, // Grosor del borde
        ),
        boxShadow: boxShadow ?? [],
      ),
      child: FloatingActionButton.extended(
        heroTag: heroTag,
        onPressed: onPressed,
        label: Row(
          children: [
            Image.asset(
              iconPath,
              height: 20,
              width: 20,
              color: iconColor ?? Colors.black, // Color del icono personalizado
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: textColor ?? Colors.black), // Texto personalizado
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
