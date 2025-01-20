import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main/main_app_screen.dart';
import 'welcome_screen.dart';

const Color backgroundColor = Color.fromARGB(255, 64, 224, 208); // Azul turquesa

class LoginScreen extends StatefulWidget {
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
          MaterialPageRoute(builder: (context) => MainAppScreen()),
        );
      });
    }
  }

  void login() async {
    if (!mounted || isNavigating) return;

    setState(() {
      isLoading = true;
    });

    try {
      await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (mounted && !isNavigating) {
        setState(() {
          isNavigating = true;
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainAppScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Error de inicio de sesión'),
              content: Text('Correo o contraseña incorrectos.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Aceptar'),
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 64, 224, 208), // Azul turquesa
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            'PLAN',
            style: TextStyle(
              color: Colors.black, // Letra negra
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 135, 206, 235), // Azul claro
                  Color.fromARGB(255, 64, 224, 208), // Turquesa
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          elevation: 0,
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Inicia sesión',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black, // Letra negra
                  ),
                ),
                SizedBox(height: 30),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.white, // Fondo blanco para los campos de texto
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
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
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.white, // Fondo blanco para los campos de texto
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
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
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                SizedBox(height: 30),
                isLoading
                    ? CircularProgressIndicator()
                    : GestureDetector(
                        onTap: login,
                        child: Container(
                          width: 200,
                          padding: EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color.fromARGB(255, 70, 130, 180), // Azul más oscuro
                                Color.fromARGB(255, 135, 206, 235), // Azul claro
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Center(
                            child: Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black, // Letra negra
                              ),
                            ),
                          ),
                        ),
                      ),
                SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Funcionalidad pendiente')),
                    );
                  },
                  child: Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(
                      color: Colors.black, // Letra negra
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
