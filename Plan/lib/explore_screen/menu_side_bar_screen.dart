// menu_side_bar_screen.dart
import 'package:flutter/material.dart';

// Importa aquí las pantallas que quieras mostrar al navegar
import 'menu_side_bar/profile_screen.dart';
import 'menu_side_bar/my_plans_screen.dart';
import 'menu_side_bar/explore_plans_screen.dart';
import 'menu_side_bar/notifications_screen.dart';
import 'menu_side_bar/chat_screen.dart';
import 'menu_side_bar/valorations_screen.dart';
import 'menu_side_bar/create_plan_screen.dart';
import 'menu_side_bar/favourites_screen.dart';
import 'menu_side_bar/settings_screen.dart';
import 'menu_side_bar/help_center_screen.dart';
import 'menu_side_bar/close_session_screen.dart';

class MainSideBarScreen extends StatefulWidget {
  final ValueChanged<bool>? onMenuToggled;

  const MainSideBarScreen({
    Key? key,
    this.onMenuToggled,
  }) : super(key: key);

  @override
  MainSideBarScreenState createState() => MainSideBarScreenState();
}

class MainSideBarScreenState extends State<MainSideBarScreen> {
  bool isOpen = false;
  final double menuWidth = 240;
  final double sidePadding = 10;
  final double bottomPadding = 20;

  /// Alterna el estado del menú
  void toggleMenu() {
    setState(() {
      isOpen = !isOpen;
    });
    widget.onMenuToggled?.call(isOpen);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Capa transparente para cerrar el menú si se toca fuera de él
        if (isOpen)
          GestureDetector(
            onTap: toggleMenu,
            child: Container(color: Colors.transparent),
          ),

        // Menú lateral con animación
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          left: isOpen ? sidePadding : -menuWidth,
          top: MediaQuery.of(context).padding.top + 40,
          bottom: bottomPadding,
          width: menuWidth,
          child: Material(
            elevation: 6,
            color: const Color(0xFF1E1E2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo y título
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 16.0,
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.circle, // Aquí podrías poner tu propio logo
                          color: Colors.blue,
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'PLAN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white54),

                  // Opciones del menú
                  Expanded(
                    child: ListView(
                      children: [
                        _buildMenuItem(
                          icon: Icons.person,
                          title: 'Perfil',
                          destination: const ProfileScreen(),
                        ),
                        _buildMenuItem(
                          icon: Icons.event,
                          title: 'Mis Planes',
                          destination: const MyPlansScreen(),
                        ),
                        _buildMenuItem(
                          icon: Icons.search,
                          title: 'Explorar Planes',
                          destination: const ExplorePlansScreen(),
                        ),
                        _buildMenuItem(
                          icon: Icons.notifications,
                          title: 'Notificaciones',
                          destination: const NotificationsScreen(),
                        ),
                        _buildMenuItem(
                          icon: Icons.chat,
                          title: 'Chat',
                          destination: const ChatScreen(),
                        ),
                        _buildMenuItem(
                          icon: Icons.star,
                          title: 'Valoraciones',
                          destination: const ValorationsScreen(),
                        ),
                        _buildMenuItem(
                          icon: Icons.add_circle_outline,
                          title: 'Crear Plan',
                          destination: const CreatePlanScreen(),
                        ),
                        _buildMenuItem(
                          icon: Icons.favorite,
                          title: 'Favoritos',
                          destination: const FavouritesScreen(),
                        ),
                        _buildMenuItem(
                          icon: Icons.settings,
                          title: 'Ajustes',
                          destination: const SettingsScreen(),
                        ),
                        _buildMenuItem(
                          icon: Icons.help_outline,
                          title: 'Centro de Ayuda',
                          destination: const HelpCenterScreen(),
                        ),
                        _buildMenuItem(
                          icon: Icons.logout,
                          title: 'Cerrar Sesión',
                          destination: const CloseSessionScreen(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Construye cada ListTile del menú, navegando a la pantalla respectiva
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Widget destination,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      onTap: () {
        // Navega a la pantalla sin cerrar el menú
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      },
    );
  }
}
