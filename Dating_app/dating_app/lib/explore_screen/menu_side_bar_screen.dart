import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dating_app/main/colors.dart';
import 'dart:ui';

// Importaciones de pantallas
import 'menu_side_bar/profile_screen.dart';
import 'menu_side_bar/my_plans_screen.dart';
import 'menu_side_bar/explore_plans_screen.dart';
import 'menu_side_bar/notifications_screen.dart';
import 'menu_side_bar/chat_screen.dart';
import 'menu_side_bar/valorations_screen.dart';
import 'menu_side_bar/favourites_screen.dart';
import 'menu_side_bar/settings_screen.dart';
import 'menu_side_bar/help_center_screen.dart';
import 'menu_side_bar/close_session_screen.dart';
import 'menu_side_bar/subscribed_plans_screen.dart';

class MainSideBarScreen extends StatefulWidget {
  final ValueChanged<bool>? onMenuToggled;

  const MainSideBarScreen({
    super.key,
    this.onMenuToggled,
  });

  @override
  MainSideBarScreenState createState() => MainSideBarScreenState();
}

class MainSideBarScreenState extends State<MainSideBarScreen> {
  bool isOpen = false;
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  void toggleMenu() {
    setState(() {
      isOpen = !isOpen;
    });
    widget.onMenuToggled?.call(isOpen);
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        if (isOpen)
          GestureDetector(
            onTap: toggleMenu,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.2),
              ),
            ),
          ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          left: isOpen ? 0 : -screenSize.width,
          top: 0,
          width: screenSize.width,
          height: screenSize.height,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, top: 40.0, bottom: 16.0),
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
                              stream: FirebaseFirestore.instance
                                  .collection('plans')
                                  .where('createdBy', isEqualTo: currentUserId)
                                  .snapshots(),
                            ),
                            _buildMenuItem(
                              icon: Icons.search,
                              title: 'Explorar Planes',
                              destination: const ExplorePlansScreen(),
                              iconColor: AppColors.blue,
                              textColor: AppColors.black,
                            ),
                            _buildMenuItemWithBadge(
                              icon: Icons.image,
                              title: 'Planes Suscritos',
                              destination: SubscribedPlansScreen(userId: currentUserId!),
                              iconColor: AppColors.blue,
                              textColor: AppColors.black,
                              stream: FirebaseFirestore.instance
                                  .collection('subscriptions')
                                  .where('userId', isEqualTo: currentUserId)
                                  .snapshots(),
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
                Positioned(
                  top: 40,
                  right: 16,
                  child: GestureDetector(
                    onTap: toggleMenu,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.arrow_back,
                        color: AppColors.blue,
                        size: 24,
                      ),
                    ),
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
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        title,
        style: GoogleFonts.roboto(
          color: textColor,
          fontSize: 16,
        ),
      ),
      onTap: () {
        toggleMenu();
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
    required Stream<QuerySnapshot> stream,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
        }

        return ListTile(
          dense: true,
          leading: Icon(icon, color: iconColor, size: 24),
          title: Text(
            title,
            style: GoogleFonts.roboto(
              color: textColor,
              fontSize: 16,
            ),
          ),
          trailing: count > 0
              ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : const SizedBox(),
          onTap: () {
            toggleMenu();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => destination),
            );
          },
        );
      },
    );
  }
}