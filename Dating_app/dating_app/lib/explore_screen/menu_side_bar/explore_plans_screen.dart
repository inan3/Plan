import 'package:flutter/material.dart';
// import 'package:tu_app/theme/app_colors.dart'; // si corresponde

class ExplorePlansScreen extends StatelessWidget {
  const ExplorePlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Botón flotante con "X" para salir
          Positioned(
            top: 45,
            left: 30,
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white, 
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.blue,
                  size: 28,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 50),
                // Logo en la parte superior
                Image.asset(
                  'assets/plan-sin-fondo.png',
                  height: 100,
                  fit: BoxFit.contain,
                ),
                // El contenido previo del body
                const Expanded(
                  child: Center(
                    child: Text('Esta es la pantalla de Explorar Planes'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
