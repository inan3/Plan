import 'package:dating_app/main/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Quita o ajusta los imports de widgets/pantallas que ya no uses,
// si no quieres cargar "MatchesScreen", "MessagesScreen", etc.
// En este ejemplo los removemos para dejar solo ExploreScreen
import 'explore_app_bar.dart';
import 'popular_users_section.dart';
import 'plan_action_button.dart'; // Widget modularizado
import 'filter_screen.dart';
import '../plan_creation/new_plan_creation_screen.dart';
import '../plan_joining/plan_join_request.dart';
import 'users_grid.dart';
import 'menu_side_bar_screen.dart'; // Menú lateral

/// En esta versión solo hay UNA clase principal: ExploreScreen.
/// Aquí combinamos:
/// 1) El contenido del antiguo MainAppScreen (bottom bar con 4 íconos)
/// 2) El contenido original de ExploreScreen (barra lateral, etc.)
/// para que se vean todos los widgets al mismo tiempo.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  ExploreScreenState createState() => ExploreScreenState();
}

class ExploreScreenState extends State<ExploreScreen> {
  // Para la barra inferior
  int _currentIndex = 0;
  final double _iconSize = 30.0;

  // Para el Explore original
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

  // Lógica de búsqueda
  void _onSearchChanged(String value) {
    // Aquí tu código de filtrado/búsqueda
  }

  // Lógica de filtro
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
            // CONTENIDO PRINCIPAL (columna con la AppBar de "explore", usuarios, etc.)
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

            // MENU LATERAL DESPLEGABLE
            MainSideBarScreen(
              key: _menuKey,
              onMenuToggled: (bool open) {
                setState(() {
                  isMenuOpen = open;
                });
              },
            ),

            // BOTTOM BAR SIEMPRE VISIBLE
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 350,
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Botón 1: Ejemplo "ubicación"
                    IconButton(
                      iconSize: _iconSize,
                      icon: Icon(
                        Icons.location_on,
                        color: _currentIndex == 0
                            ? AppColors.blue
                            : const Color.fromARGB(57, 44, 43, 43),
                      ),
                      onPressed: () {
                        setState(() {
                          _currentIndex = 0;
                        });
                        // Aquí tu lógica si quieres cambiar algo en la pantalla
                      },
                    ),
                    // Botón 2: Ejemplo "favoritos"
                    IconButton(
                      iconSize: _iconSize,
                      icon: Icon(
                        Icons.favorite,
                        color: _currentIndex == 1
                            ? AppColors.blue
                            : const Color.fromARGB(57, 44, 43, 43),
                      ),
                      onPressed: () {
                        setState(() {
                          _currentIndex = 1;
                        });
                      },
                    ),
                    // Botón 3: Ejemplo "mensajes"
                    IconButton(
                      iconSize: _iconSize,
                      icon: Icon(
                        Icons.message,
                        color: _currentIndex == 2
                            ? AppColors.blue
                            : const Color.fromARGB(57, 44, 43, 43),
                      ),
                      onPressed: () {
                        setState(() {
                          _currentIndex = 2;
                        });
                      },
                    ),
                    // Botón 4: Ejemplo "perfil"
                    IconButton(
                      iconSize: _iconSize,
                      icon: Icon(
                        Icons.person,
                        color: _currentIndex == 3
                            ? AppColors.blue
                            : const Color.fromARGB(57, 44, 43, 43),
                      ),
                      onPressed: () {
                        setState(() {
                          _currentIndex = 3;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // BOTONES FLOTANTES (Unirse a plan / Crear plan)
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
              borderColor: const Color.fromARGB(236, 0, 4, 227), // Borde azul
              borderWidth: 1,
              textColor: AppColors.blue,
              iconColor: AppColors.blue,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),

            // Botón "Crear Plan"
            PlanActionButton(
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
              backgroundColor: AppColors.blue, // Fondo azul
              borderColor: Colors.transparent,
              borderWidth: 0,
              textColor: Colors.white,
              iconColor: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget para los botones flotantes (unirse/crear plan).
/// Aunque aquí sigue siendo otra clase, no es una "pantalla" separada.
/// Es un simple widget de soporte, si lo prefieres, podrías incrustarlo
/// directamente en ExploreScreen. 
class PlanActionButton extends StatelessWidget {
  final String heroTag;
  final String label;
  final String iconPath;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry? margin;
  final Color backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final Color? textColor;
  final Color? iconColor;
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
    this.borderWidth = 0,
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
          color: borderColor ?? Colors.transparent,
          width: borderWidth,
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
              color: iconColor ?? Colors.black,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: textColor ?? Colors.black),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
