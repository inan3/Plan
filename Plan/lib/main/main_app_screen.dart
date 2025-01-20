import 'package:dating_app/main/colors.dart';
import 'package:flutter/material.dart';
import '../explore_screen/explore_screen.dart';
import 'matches_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class MainAppScreen extends StatefulWidget {
  @override
  _MainAppScreenState createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _currentIndex = 0;

  // Controla si se oculta la barra inferior
  bool _hideBottomBar = false;

  // Método para actualizar la visibilidad de la barra
  void _onMenuToggled(bool isOpen) {
    setState(() {
      _hideBottomBar = isOpen;
    });
  }

  // Lista de pantallas
  final List<Widget> _screens = [];

  // Tamaño de los íconos (puedes cambiarlo dinámicamente si quieres)
  double _iconSize = 30.0;  

  @override
  void initState() {
    super.initState();
    _screens.addAll([
      ExploreScreen(onMenuToggled: _onMenuToggled),
      MatchesScreen(),
      MessagesScreen(),
      ProfileScreen(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1) Pantalla que se está viendo (Explore, Matches, etc.)
          _screens[_currentIndex],

          // 2) Barra inferior (se muestra solo si _hideBottomBar es false)
          if (!_hideBottomBar)
           Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              // Manipulas el ancho y alto de la barra aquí
              width: 350,
              height: 60,
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all( // Añadido para el borde
                  color: AppColors.blue,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: Offset(0, 4), // Desplazamiento de la sombra
                  ),
                ],
              ),
              child: Row(
                // Si quieres que ocupe todo el ancho, no uses mainAxisSize.min
                mainAxisSize: MainAxisSize.max,
                // Cambia esto para mover los iconos
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    iconSize: _iconSize, // Escala del ícono
                    icon: Icon(
                      Icons.location_on,
                      color: _currentIndex == 0 ? AppColors.blue : const Color.fromARGB(57, 44, 43, 43),
                    ),
                    onPressed: () {
                      setState(() {
                        _currentIndex = 0;
                      });
                    },
                  ),
                  IconButton(
                    iconSize: _iconSize, // Escala del ícono
                    icon: Icon(
                      Icons.favorite,
                      color: _currentIndex == 1 ? AppColors.blue : Color.fromARGB(57, 44, 43, 43),
                    ),
                    onPressed: () {
                      setState(() {
                        _currentIndex = 1;
                      });
                    },
                  ),
                  IconButton(
                    iconSize: _iconSize, // Escala del ícono
                    icon: Icon(
                      Icons.message,
                      color: _currentIndex == 2 ? AppColors.blue : Color.fromARGB(57, 44, 43, 43),
                    ),
                    onPressed: () {
                      setState(() {
                        _currentIndex = 2;
                      });
                    },
                  ),
                  IconButton(
                    iconSize: _iconSize, // Escala del ícono
                    icon: Icon(
                      Icons.person,
                      color: _currentIndex == 3 ? AppColors.blue : Color.fromARGB(57, 44, 43, 43),
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
    );
  }
}
