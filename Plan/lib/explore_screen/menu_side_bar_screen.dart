import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Importación para Roboto
import 'package:dating_app/main/colors.dart'; // Asegúrate de importar AppColors

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

  /// Alterna el estado del menú
  void toggleMenu() {
    setState(() {
      isOpen = !isOpen;
    });
    widget.onMenuToggled?.call(isOpen);
  }

  @override
  Widget build(BuildContext context) {
    final double menuHeight = MediaQuery.of(context).size.height / 2; // Mitad de la pantalla

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
          top: MediaQuery.of(context).padding.top + 10, // Ajusta la posición superior del menú
          height: menuHeight,
          width: menuWidth,
          child: Material(
            elevation: 6,
            color: Colors.white, // Fondo blanco
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: BorderSide(color: AppColors.blue, width: 2), // Bordes de color AppColors.blue
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    top: 8.0, // Espacio superior reducido para acercar el logo al borde
                    bottom: 8.0, // Reduce el espacio entre el logo y los íconos
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/plan-sin-fondo.png', // Ruta del logo
                        height: 60, // Tamaño ajustado para ahorrar espacio
                        width: 60,
                        fit: BoxFit.contain, // Asegura que el logo se ajuste correctamente
                      ),
                    ],
                  ),
                ),

                // Opciones del menú
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero, // Sin espacios adicionales
                    children: [
                      _buildMenuItem(
                        icon: Icons.person,
                        title: 'Perfil',
                        destination: const ProfileScreen(),
                        iconColor: AppColors.blue,
                        textColor: AppColors.black,
                      ),
                      _buildMenuItem(
                        icon: Icons.event,
                        title: 'Mis Planes',
                        destination: const MyPlansScreen(),
                        iconColor: AppColors.blue,
                        textColor: AppColors.black,
                      ),
                      _buildMenuItem(
                        icon: Icons.search,
                        title: 'Explorar Planes',
                        destination: const ExplorePlansScreen(),
                        iconColor: AppColors.blue,
                        textColor: AppColors.black,
                      ),
                      _buildMenuItem(
                        icon: Icons.notifications,
                        title: 'Notificaciones',
                        destination: const NotificationsScreen(),
                        iconColor: AppColors.blue,
                        textColor: AppColors.black,
                      ),
                      _buildMenuItem(
                        icon: Icons.chat,
                        title: 'Chat',
                        destination: const ChatScreen(),
                        iconColor: AppColors.blue,
                        textColor: AppColors.black,
                      ),
                      _buildMenuItem(
                        icon: Icons.star,
                        title: 'Valoraciones',
                        destination: const ValorationsScreen(),
                        iconColor: AppColors.blue,
                        textColor: AppColors.black,
                      ),
                      _buildMenuItem(
                        icon: Icons.add_circle_outline,
                        title: 'Crear Plan',
                        destination: const CreatePlanScreen(),
                        iconColor: AppColors.blue,
                        textColor: AppColors.black,
                      ),
                      _buildMenuItem(
                        icon: Icons.favorite,
                        title: 'Favoritos',
                        destination: const FavouritesScreen(),
                        iconColor: AppColors.blue,
                        textColor: AppColors.black,
                      ),
                      _buildMenuItem(
                        icon: Icons.settings,
                        title: 'Ajustes',
                        destination: const SettingsScreen(),
                        iconColor: AppColors.blue,
                        textColor: AppColors.black,
                      ),
                      _buildMenuItem(
                        icon: Icons.help_outline,
                        title: 'Centro de Ayuda',
                        destination: const HelpCenterScreen(),
                        iconColor: AppColors.blue,
                        textColor: AppColors.black,
                      ),
                      _buildMenuItem(
                        icon: Icons.logout,
                        title: 'Cerrar Sesión',
                        destination: const CloseSessionScreen(),
                        iconColor: Colors.red, // Ícono rojo
                        textColor: Colors.red, // Texto rojo
                      ),
                    ],
                  ),
                ),
              ],
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
    required Color iconColor,
    required Color textColor,
  }) {
    return ListTile(
      dense: true, // Reduce el espacio vertical entre elementos
      leading: Icon(icon, color: iconColor, size: 20), // Ícono con color personalizado
      title: Text(
        title,
        style: GoogleFonts.roboto(
          color: textColor, // Texto con color personalizado
          fontSize: 14, // Texto más pequeño para ahorrar espacio
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      },
    );
  }
}
