import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import '../explore_screen/main_screen/explore_screen.dart';
import 'welcome_screen.dart';
import '../main/colors.dart';

const Color backgroundColor = AppColors.background; // Azul turquesa

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool isNavigating = false;

  @override
  void initState() {
    super.initState();
    _checkIfUserIsLoggedIn();
  }

  void _checkIfUserIsLoggedIn() async {
    User? user = _auth.currentUser;
    if (user != null) {
      Future.delayed(Duration.zero, () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ExploreScreen()),
        );
      });
    }
  }

  /// Verifica si el usuario tiene documento en la colección "users"
  Future<bool> _checkUserDocExists(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.exists; // true si existe el documento
  }

  void loginEmailPassword() async {
    if (!mounted || isNavigating) return;

    setState(() {
      isLoading = true;
    });

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = credential.user;
      if (user == null) {
        // Algo raro, no hay usuario
        throw FirebaseAuthException(code: 'USER_NULL');
      }

      // Verificamos si existe en la colección 'users'
      final existsInUsers = await _checkUserDocExists(user.uid);
      if (!existsInUsers) {
        await _auth.signOut();
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('No estás registrado'),
              content: const Text(
                  'No hay ningún perfil en la base de datos para este usuario. Debes registrarte primero.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Aceptar'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Si todo está bien
      if (mounted && !isNavigating) {
        setState(() {
          isNavigating = true;
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ExploreScreen()),
        );
      }
    } on FirebaseAuthException catch (_) {
      // Error de email/contraseña
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error de inicio de sesión'),
              content: const Text('Correo o contraseña incorrectos.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isNavigating = false;
        });
      }
    }
  }

  /// Inicio de sesión con Google y validación de doc en "users"
  Future<void> loginWithGoogle() async {
    if (!mounted || isNavigating) return;

    setState(() => isLoading = true);

    try {
      // Forzamos selección de cuenta localmente
      await GoogleSignIn().signOut();

      final GoogleSignInAccount? acc = await GoogleSignIn().signIn();
      if (acc == null) {
        // Usuario canceló
        return;
      }
      final googleAuth = await acc.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(cred);
      final user = userCred.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'USER_NULL');
      }

      // Verificamos si existe en la colección 'users'
      final existsInUsers = await _checkUserDocExists(user.uid);
      if (!existsInUsers) {
        await _auth.signOut();
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('No estás registrado'),
              content: const Text(
                  'No hay ningún perfil en la base de datos para este usuario. Debes registrarte primero.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Aceptar'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Si sí existe en "users", continuamos
      if (mounted && !isNavigating) {
        setState(() {
          isNavigating = true;
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ExploreScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de inicio de sesión con Google.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isNavigating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    SizedBox(
                      height: 150,
                      child: Image.asset(
                        'assets/plan-sin-fondo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Título "Inicia sesión"
                    Text(
                      'Inicio de sesión',
                      style: GoogleFonts.roboto(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Botón "Continuar con Google"
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: loginWithGoogle,
                        icon: Image.asset(
                          'assets/google_logo.png',
                          height: 24,
                          width: 24,
                        ),
                        label: Text(
                          'Continuar con Google',
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color.fromARGB(236, 0, 4, 227),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          shadowColor: Colors.black.withOpacity(0.2),
                          elevation: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // separador
                    Text(
                      '- o -',
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Campo de texto para Correo
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Correo electrónico',
                          hintStyle: GoogleFonts.roboto(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Campo de texto para Contraseña
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Contraseña',
                          hintStyle: GoogleFonts.roboto(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Botón "Iniciar sesión"
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: loginEmailPassword,
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
                          'Iniciar sesión',
                          style: GoogleFonts.roboto(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Funcionalidad pendiente'),
                          ),
                        );
                      },
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                color: AppColors.blue,
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
