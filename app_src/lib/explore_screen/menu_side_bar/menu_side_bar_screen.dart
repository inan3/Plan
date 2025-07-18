// menu_side_bar_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dating_app/main/colors.dart';
import '../../l10n/app_localizations.dart';
import 'my_plans_screen.dart';
import 'favourites_screen.dart';
import 'settings/settings_screen.dart';
import 'close_session_screen.dart';
import 'subscribed_plans_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../users_grid/users_grid_helpers.dart';

class MainSideBarScreen extends StatefulWidget {
  final ValueChanged<bool>? onMenuToggled;
  final Function(int)? onPageChange;

  /// Determina si el menú debe mostrarse abierto al iniciar.
  final bool initiallyOpenSidebar;

  const MainSideBarScreen({
    super.key,
    this.onMenuToggled,
    this.onPageChange,

    this.initiallyOpenSidebar = false,

  });

  @override
  MainSideBarScreenState createState() => MainSideBarScreenState();
}

class MainSideBarScreenState extends State<MainSideBarScreen> {
  late bool isOpen;
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  int _pressedIndex = -1;

  Future<int> _countExistingPlans(List<String> planIds) async {
    int validCount = 0;
    for (final id in planIds) {
      final doc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(id)
          .get();
      if (doc.exists) validCount++;
    }
    return validCount;
  }

  @override
  void initState() {
    super.initState();

    isOpen = widget.initiallyOpenSidebar;

  }

  void toggleMenu() {
    setState(() {
      isOpen = !isOpen;
    });
    widget.onMenuToggled?.call(isOpen);
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final t = AppLocalizations.of(context);

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
                          top: 20.0,
                          bottom: 16.0,
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/plan-sin-fondo.png',
                              height: 80,
                              width: 80,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                      _buildProfileHeader(),
                      _buildMenuItemWithBadge(
                        icon: 'assets/icono-calendario.svg',
                        title: t.myPlans,
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
                        title: t.subscribedPlans,
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
                        title: t.favourites,
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
                        title: t.settings,
                        destination: const SettingsScreen(),
                        iconColor: Colors.white,
                        textColor: Colors.white,
                        index: 3,
                      ),
                      _buildMenuItem(
                        icon: 'assets/icono-cerrar-sesion.svg',
                        title: t.closeSession,
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
                Positioned(
                  bottom: 44,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.followUsAlsoOn,
                        style: GoogleFonts.roboto(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _socialButton(
                            assetPath: 'assets/instagram.png',
                            url: 'https://www.instagram.com/plansocialappspain/',
                            tooltip: 'Instagram',
                          ),
                          _socialButton(
                            assetPath: 'assets/tiktok.png',
                            url: 'https://www.tiktok.com/@plan0525',
                            tooltip: 'TikTok',
                          ),
                          _socialButton(
                            assetPath: 'assets/linkedin.png',
                            url: 'https://www.linkedin.com/in/plan-social-app-54165536a',
                            tooltip: 'LinkedIn',
                          ),
                        ],
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

  Widget _buildProfileHeader() {
    return GestureDetector(
      onTap: () {
        toggleMenu();
        widget.onPageChange?.call(3);
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
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
                  String profileImageUrl = '';
                  String coverUrl = '';
                  String userName = "Cargando...";

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      children: [
                        const CircleAvatar(
                          radius: 50,
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
                          radius: 50,
                          backgroundColor: avatarColor(userName),
                          child: Text(
                            getInitialsSync(userName),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 30),
                          ),
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

                  final userData = snapshot.data!.data() as Map<String, dynamic>?;
                  profileImageUrl = userData?['photoUrl'] ?? '';
                  coverUrl = userData?['coverPhotoUrl'] ?? '';
                  userName = userData?['name'] ?? "Usuario";

                  final String? finalUrl = profileImageUrl.isNotEmpty
                      ? profileImageUrl
                      : (coverUrl.isNotEmpty ? coverUrl : null);

                  return Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: finalUrl != null
                            ? CachedNetworkImageProvider(finalUrl)
                            : null,
                        backgroundColor: finalUrl != null
                            ? Colors.grey.shade200
                            : avatarColor(userName),
                        child: finalUrl == null
                            ? Text(
                                getInitialsSync(userName),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 30),
                              )
                            : null,
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
        if (index == 2 && snapshot.hasData) {
          final data = (snapshot.data as DocumentSnapshot?)?.data()
              as Map<String, dynamic>?;
          final favIds =
              (data?['favourites'] as List<dynamic>?)?.cast<String>() ?? [];
          return FutureBuilder<int>(
            future: _countExistingPlans(favIds),
            builder: (context, favSnap) {
              final count = favSnap.data ?? 0;
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
                              color: AppColors.planColor,
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
        } else {
          int count = 0;
          if (snapshot.hasData) {
            count = (snapshot.data as QuerySnapshot?)?.docs.length ?? 0;
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
                          color: AppColors.planColor,
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
        }
      },
    );
  }

  Widget _socialButton({
    required String assetPath,
    required String url,
    String? tooltip,
  }) {
    return IconButton(
      icon: Image.asset(assetPath, width: 32, height: 32),
      tooltip: tooltip,
      onPressed: () async {
        final uri = Uri.parse(url);
        // Intenta abrir primero con una aplicación externa (por ejemplo,
        // la app oficial de la red social). Si no hay ninguna instalada,
        // se abre en un navegador dentro de la app.
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        }
      },
    );
  }
}
