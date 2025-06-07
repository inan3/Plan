// menu_side_bar_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:dating_app/main/colors.dart';
import 'my_plans_screen.dart';
import 'favourites_screen.dart';
import 'settings/settings_screen.dart';
import 'close_session_screen.dart';
import 'subscribed_plans_screen.dart';

class MainSideBarScreen extends StatefulWidget {
  final ValueChanged<bool>? onMenuToggled;
  final Function(int)? onPageChange;

  const MainSideBarScreen({
    super.key,
    this.onMenuToggled,
    this.onPageChange,
  });

  @override
  MainSideBarScreenState createState() => MainSideBarScreenState();
}

class MainSideBarScreenState extends State<MainSideBarScreen> {
  bool isOpen = false;
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  int _pressedIndex = -1;

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
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.8),
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.fromARGB(255, 13, 32, 53),
                        Color.fromARGB(255, 72, 38, 38),
                        Color(0xFF12232E),
                      ],
                    ),
                  ),
                  // Para evitar overflows se usa ListView:
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16.0,
                          top: 40.0,
                          bottom: 16.0,
                        ),
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
                      _buildProfileHeader(),
                      _buildMenuItemWithBadge(
                        icon: 'assets/icono-calendario.svg',
                        title: 'Mis Planes',
                        destination: const MyPlansScreen(),
                        iconColor: Colors.white,
                        textColor: Colors.white,
                        index: 0,
                        stream: FirebaseFirestore.instance
                            .collection('plans')
                            .where('createdBy', isEqualTo: currentUserId)
                            .snapshots(),
                      ),
                      _buildMenuItemWithBadge(
                        icon: 'assets/union.svg',
                        title: 'Planes Suscritos',
                        destination: SubscribedPlansScreen(
                          userId: currentUserId ?? '',
                        ),
                        iconColor: Colors.white,
                        textColor: Colors.white,
                        index: 1,
                        stream: FirebaseFirestore.instance
                            .collection('subscriptions')
                            .where('userId', isEqualTo: currentUserId)
                            .snapshots(),
                      ),
                      _buildMenuItemWithBadge(
                        icon: 'assets/icono-corazon.svg',
                        title: 'Favoritos',
                        destination: const FavouritesScreen(),
                        iconColor: Colors.white,
                        textColor: Colors.white,
                        index: 2,
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUserId)
                            .snapshots(includeMetadataChanges: true),
                      ),
                      _buildMenuItem(
                        icon: 'assets/icono-ajustes.svg',
                        title: 'Ajustes',
                        destination: const SettingsScreen(),
                        iconColor: Colors.white,
                        textColor: Colors.white,
                        index: 3,
                      ),
                      _buildMenuItem(
                        icon: 'assets/icono-cerrar-sesion.svg',
                        title: 'Cerrar Sesión',
                        destination: const CloseSessionScreen(),
                        iconColor: Colors.red,
                        textColor: Colors.red,
                        index: 4,
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

  Widget _buildProfileHeader() {
    return GestureDetector(
      onTap: () {
        toggleMenu();
        widget.onPageChange?.call(3);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUserId)
                    .get(),
                builder: (context, snapshot) {
                  String profileImageUrl = "https://via.placeholder.com/150";
                  String userName = "Cargando...";

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      children: [
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey,
                          child: CircularProgressIndicator(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          userName,
                          style: GoogleFonts.roboto(
                            color: AppColors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  }

                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data == null) {
                    userName = "Error";
                    return Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: NetworkImage(profileImageUrl),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          userName,
                          style: GoogleFonts.roboto(
                            color: AppColors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  }

                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>?;
                  profileImageUrl = userData?['photoUrl'] ?? profileImageUrl;
                  userName = userData?['name'] ?? "Usuario";

                  return Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: NetworkImage(profileImageUrl),
                        backgroundColor: Colors.grey.shade200,
                        onBackgroundImageError: (_, __) => const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userName,
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required dynamic icon,
    required String title,
    required Widget destination,
    required Color iconColor,
    required Color textColor,
    required int index,
  }) {
    final bool isPressed = _pressedIndex == index;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressedIndex = index),
      onTapUp: (_) => setState(() => _pressedIndex = -1),
      onTapCancel: () => setState(() => _pressedIndex = -1),
      onTap: () {
        toggleMenu();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      },
      child: ListTile(
        dense: true,
        leading: icon is String
            ? SvgPicture.asset(
                icon,
                width: 28,
                height: 28,
                color: isPressed ? AppColors.planColor : iconColor,
                colorBlendMode: BlendMode.srcIn,
              )
            : Icon(icon,
                color: isPressed ? AppColors.planColor : iconColor, size: 24),
        title: Text(
          title,
          style: GoogleFonts.roboto(
            color: isPressed ? AppColors.planColor : textColor,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItemWithBadge({
    required dynamic icon,
    required String title,
    required Widget destination,
    required Color iconColor,
    required Color textColor,
    required Stream stream,
    required int index,
  }) {
    return StreamBuilder(
      stream: stream,
      builder: (context, AsyncSnapshot snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          if (title == 'Favoritos') {
            final data = (snapshot.data as DocumentSnapshot?)?.data()
                as Map<String, dynamic>?;
            count = (data?['favourites'] as List<dynamic>?)?.length ?? 0;
          } else {
            count = (snapshot.data as QuerySnapshot?)?.docs.length ?? 0;
          }
        }
        final bool isPressed = _pressedIndex == index;
        return GestureDetector(
            onTapDown: (_) => setState(() => _pressedIndex = index),
            onTapUp: (_) => setState(() => _pressedIndex = -1),
            onTapCancel: () => setState(() => _pressedIndex = -1),
            child: ListTile(
              dense: true,
              leading: icon is String
                  ? SvgPicture.asset(
                      icon,
                      width: 28,
                      height: 28,
                      color: isPressed ? AppColors.planColor : iconColor,
                      colorBlendMode: BlendMode.srcIn,
                    )
                  : Icon(icon,
                      color: isPressed ? AppColors.planColor : iconColor,
                      size: 24),
              title: Text(
                title,
                style: GoogleFonts.roboto(
                  color: isPressed ? AppColors.planColor : textColor,
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
            ));
      },
    );
  }
}
