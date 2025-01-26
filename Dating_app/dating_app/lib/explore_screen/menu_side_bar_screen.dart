import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dating_app/main/colors.dart';

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
import 'menu_side_bar/subscribed_plans_screen.dart';

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
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  void toggleMenu() {
    setState(() {
      isOpen = !isOpen;
    });
    widget.onMenuToggled?.call(isOpen);
  }

  @override
  Widget build(BuildContext context) {
    final double menuHeight = MediaQuery.of(context).size.height / 2;

    return Stack(
      children: [
        if (isOpen)
          GestureDetector(
            onTap: toggleMenu,
            child: Container(color: Colors.transparent),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          left: isOpen ? sidePadding : -menuWidth,
          top: MediaQuery.of(context).padding.top + 10,
          height: menuHeight,
          width: menuWidth,
          child: Material(
            elevation: 6,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: BorderSide(color: AppColors.blue, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/plan-sin-fondo.png',
                        height: 60,
                        width: 60,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildMenuItem(
                        icon: Icons.person,
                        title: 'Perfil',
                        destination: const ProfileScreen(),
                        iconColor: AppColors.blue,
                        textColor: AppColors.black,
                      ),
                      _buildMenuItemWithBadge(
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
                        icon: Icons.image,
                        title: 'Planes Suscritos',
                        destination: SubscribedPlansScreen(userId: currentUserId!),
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
                        iconColor: Colors.red,
                        textColor: Colors.red,
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

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Widget destination,
    required Color iconColor,
    required Color textColor,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(
        title,
        style: GoogleFonts.roboto(
          color: textColor,
          fontSize: 14,
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

  Widget _buildMenuItemWithBadge({
    required IconData icon,
    required String title,
    required Widget destination,
    required Color iconColor,
    required Color textColor,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(
        title,
        style: GoogleFonts.roboto(
          color: textColor,
          fontSize: 14,
        ),
      ),
      trailing: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('plans')
            .where('createdBy', isEqualTo: currentUserId) // Filtra por el usuario actual
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const SizedBox(); // No muestra el badge si no hay planes
          }

          return Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.blue,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${snapshot.data!.docs.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
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
