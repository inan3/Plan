import 'dart:math';
import 'package:flutter/material.dart';
import 'username_screen.dart'; // Asegúrate de que la ruta sea correcta

class HeartsAnimationScreen extends StatefulWidget {
  @override
  _HeartsAnimationScreenState createState() => _HeartsAnimationScreenState();
}

class _HeartsAnimationScreenState extends State<HeartsAnimationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3), // Duración de la animación
    )..forward(); // Inicia la animación automáticamente

    // Navegar a la siguiente pantalla después de 3 segundos
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => UsernameScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[50], // Fondo de la animación
      body: Stack(
        children: List.generate(20, (index) {
          // Genera 20 corazones animados
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final position = _controller.value * MediaQuery.of(context).size.height;
              final random = Random();
              final size = random.nextInt(30) + 20.0; // Tamaño aleatorio para cada corazón
              final xPos = random.nextDouble() * MediaQuery.of(context).size.width;

              return Positioned(
                bottom: position,
                left: xPos,
                child: Opacity(
                  opacity: 1.0 - _controller.value,
                  child: Icon(
                    Icons.favorite,
                    color: Colors.redAccent.withOpacity(0.6),
                    size: size,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
