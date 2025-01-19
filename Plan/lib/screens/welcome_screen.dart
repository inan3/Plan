import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo morado
          Container(
            color: Colors.black,
          ),
          // Corazones animados
          AnimatedHeartsLayer(),
          // Contenido principal con desplazamiento y centrado
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 40), // Espacio superior
                  // Reemplazo del título "PLAN" con el logo
                  Center(
                    child: Image.asset(
                      'assets/launcher_icon.png', // Ruta del logo
                      height: 150, // Ajusta el tamaño según lo necesites
                    ),
                  ),
                  SizedBox(height: 20),
                  // Contenedor para centrar el texto
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 40), // Márgenes laterales
                    child: Column(
                      children: [
                        Text(
                          '¡PLAN es la plataforma donde los intereses comunes se fusionan!',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '¿Y tú? ¿Qué PLAN propones?',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                  // Botones
                  Column(
                    children: [
                      // Botón "Inicia sesión"
                      SizedBox(
                        width: 250, // Tamaño fijo para ambos botones
                        child: ElevatedButton(
                          onPressed: () {
                            // Navegar a la pantalla de inicio de sesión
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LoginScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.white, // Fondo blanco
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Iniciar sesión',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.black, // Texto negro
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      // Botón "Regístrate ahora"
                      SizedBox(
                        width: 250, // Tamaño fijo para ambos botones
                        child: ElevatedButton(
                          onPressed: () {
                            // Navegar a la pantalla de registro
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RegisterScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.white, // Fondo blanco
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Registrarse',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.black, // Texto negro
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 40), // Espacio inferior
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedHeartsLayer extends StatefulWidget {
  @override
  _AnimatedHeartsLayerState createState() => _AnimatedHeartsLayerState();
}

class _AnimatedHeartsLayerState extends State<AnimatedHeartsLayer> {
  final Random _random = Random();
  final List<Widget> _hearts = [];
  late Timer _timer;

  @override
  void initState() {
    super.initState();

    // Crear corazones en intervalos aleatorios
    _timer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _hearts.add(
            AnimatedHeart(
              key: UniqueKey(), // Asegura que cada corazón sea único
              startX: _random.nextDouble(),
              size: _random.nextDouble() * 30 + 20, // Tamaño entre 20 y 50
              duration: Duration(seconds: _random.nextInt(5) + 3),
            ),
          );

          // Limitar la cantidad de corazones en pantalla
          if (_hearts.length > 10) {
            _hearts.removeAt(0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _hearts,
    );
  }
}

class AnimatedHeart extends StatefulWidget {
  final double startX;
  final double size;
  final Duration duration;

  AnimatedHeart({
    required Key key,
    required this.startX,
    required this.size,
    required this.duration,
  }) : super(key: key);

  @override
  _AnimatedHeartState createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<AnimatedHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _verticalAnimation;
  late Animation<double> _horizontalAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..forward();

    // Animación vertical (sube desde abajo hacia arriba)
    _verticalAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Animación horizontal (movimiento aleatorio hacia los lados)
    _horizontalAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Remover el corazón después de que termina su animación
        if (mounted) {
          setState(() {
            _controller.dispose();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final xOffset = widget.startX * size.width +
            _horizontalAnimation.value * size.width;
        return Positioned(
          bottom: _verticalAnimation.value * size.height, // Movimiento ascendente
          left: xOffset.clamp(0.0, size.width - widget.size),
          child: Icon(
            Icons.favorite,
            color: Colors.redAccent.withAlpha(180),
            size: widget.size,
          ),
        );
      },
    );
  }
}
