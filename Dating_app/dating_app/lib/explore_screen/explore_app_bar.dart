import 'package:flutter/material.dart';
import '../main/colors.dart';

class ExploreAppBar extends StatelessWidget {
  final VoidCallback onMenuPressed;
  final VoidCallback onFilterPressed;
  final ValueChanged<String> onSearchChanged;

  const ExploreAppBar({
    Key? key,
    required this.onMenuPressed,
    required this.onFilterPressed,
    required this.onSearchChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Botón de Menú con su propio Container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 30),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 255, 255, 255),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.menu, color: Color.fromARGB(255, 58, 46, 239)),
            onPressed: onMenuPressed,
          ),
        ),

        // Logo "PLAN" centrado
        Image.asset(
          'assets/plan-sin-fondo.png',
          height: 80, // Ajusta la altura según sea necesario
        ),

        // Botón de Filtro con su propio Container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 30),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 255, 255, 255),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.tune, color: Color.fromARGB(255, 58, 46, 239)),
            onPressed: onFilterPressed,
          ),
        ),
      ],
    );
  }
}
