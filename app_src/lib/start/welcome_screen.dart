// welcome_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login/login_screen.dart';
import 'registration/register_screen.dart';
import '../explore_screen/main_screen/explore_screen.dart';
import 'registration/user_registration_screen.dart';
import 'registration/verification_provider.dart';
import 'registration/email_verification_screen.dart';
import '../../explore_screen/users_managing/presence_service.dart';
import '../services/location_update_service.dart';
import '../l10n/app_localizations.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  /* ------------------------------------------------------------------ */
  /* ------------------  CONFIGURACIÓN DEL CARRUSEL  ------------------ */
  /* ------------------------------------------------------------------ */
  final List<String> _backgroundImages = [
    'assets/image-meeting.png',
    'assets/image-padel.png',
    'assets/image-pool-party.png',
    'assets/image-cycling.png',
  ];
  late final PageController _pageController;
  Timer? _timer;
  final int _totalPages = 10000;
  int _currentPage = 5000;

  /* ------------------------------------------------------------------ */
  bool _isLoading = true;
  StreamSubscription<User?>? _authSub;

  void _cancelAuthListener() {
    _authSub?.cancel();
    _authSub = null;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);

    // Asegurarnos de que el PageView esté montado antes de iniciar el timer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSlideBackground();
    });

    _listenAuthChanges(); // Escuchamos la sesión de Firebase
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _authSub?.cancel();
    super.dispose();
  }

  /* --------------------------- LISTENER --------------------------- */
  void _listenAuthChanges() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(
      (user) async {
        if (user == null) {
          // Sin sesión → mostramos bienvenida
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        // Recargamos info para asegurar que emailVerified y providerData están actualizados
        await user.reload();

        final providers = user.providerData.map((p) => p.providerId).toList();
        final isGoogle = providers.contains('google.com');
        final isPhone = providers.contains('phone');
        final provider = isGoogle
            ? VerificationProvider.google
            : (isPhone
                ? VerificationProvider.phone
                : VerificationProvider.password);

        // Si el correo NO está verificado y no es usuario de Google, pedimos verificación
        if (!user.emailVerified && !isGoogle && !isPhone) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => EmailVerificationScreen(
                  email: user.email ?? '',
                  password: null,
                  provider: provider,
                ),
              ),
            );
          }
          return;
        }

        // Si está verificado, revisamos si el perfil está completo
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .catchError((_) => null);

        final hasProfile =
            doc != null && doc.exists && (doc.data()?['name'] ?? '').toString().isNotEmpty;

        if (!hasProfile) {
          // Perfil incompleto → vamos a UserRegistrationScreen
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => UserRegistrationScreen(
                  provider: provider,
                  firebaseUser: user,
                ),
              ),
            );
          }
          return;
        }

        // Todo OK → ir a ExploreScreen
        if (mounted) {
          await PresenceService.init(user);
          await LocationUpdateService.init(user);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ExploreScreen()),
          );
        }
      },
    );
  }

  /* -------------------- CARRUSEL “INFINITO” -------------------- */
  void _autoSlideBackground() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      // Solo animar si el PageView está listo
      if (!_pageController.hasClients) return;

      _currentPage++;
      if (_currentPage == _totalPages - 1) {
        _currentPage = _totalPages ~/ 2;
        _pageController.jumpToPage(_currentPage);
      } else {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /* --------------------------- UI --------------------------- */
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final t = AppLocalizations.of(context);

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _totalPages,
            itemBuilder: (_, index) {
              final img = _backgroundImages[index % _backgroundImages.length];
              return Image.asset(img, fit: BoxFit.cover);
            },
          ),
          Container(color: Colors.black.withOpacity(0.3)),
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Image.asset('assets/plan-sin-fondo.png', height: 150),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        Text(
                          t.welcomeSlogan,
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          t.welcomeQuestion,
                          style: GoogleFonts.roboto(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: () async {
                        _cancelAuthListener();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                        if (mounted) _listenAuthChanges();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color.fromARGB(236, 0, 4, 227),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        shadowColor: Colors.black.withOpacity(0.2),
                        elevation: 10,
                      ),
                      child: Text(
                        t.login,
                        style: GoogleFonts.roboto(
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 200,
                    child: OutlinedButton(
                      onPressed: () async {
                        _cancelAuthListener();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen()),
                        );
                        if (mounted) _listenAuthChanges();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        side: const BorderSide(
                          color: Color.fromARGB(236, 0, 4, 227),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        t.register,
                        style: GoogleFonts.roboto(
                          fontSize: 20,
                          color: const Color.fromARGB(236, 0, 4, 227),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
