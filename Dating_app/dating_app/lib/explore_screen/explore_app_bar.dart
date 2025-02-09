import 'dart:ui';
import 'package:flutter/material.dart';
import '../main/colors.dart';
import 'explore_screen_filter.dart';

class ExploreAppBar extends StatelessWidget {
  final VoidCallback onMenuPressed;
  final VoidCallback onFilterPressed; // Este callback se usará para notificaciones.
  final ValueChanged<String> onSearchChanged;

  const ExploreAppBar({
    super.key,
    required this.onMenuPressed,
    required this.onFilterPressed,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0), // Ajusta según sea necesario
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón de Menú con efecto frosted glass
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30), // Bordes redondeados
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2), // Fondo con efecto frosted
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 92, 92, 92).withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(5, 5),
                      ),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero, // Elimina padding interno
                    constraints: const BoxConstraints(), // Quita constraints por defecto
                    icon: Image.asset(
                      'assets/menu.png',
                      color: AppColors.blue,
                      width: 18,
                      height: 18,
                    ),
                    onPressed: onMenuPressed,
                  ),
                ),
              ),
            ),
          ),

          // Logo "PLAN" centrado
          Image.asset(
            'assets/plan-sin-fondo.png',
            height: 80, // Ajusta la altura según sea necesario
          ),

          // Contenedor para los botones de filter y notificación
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Botón de filter (sin funcionalidad)
                ClipRRect(
                  borderRadius: BorderRadius.circular(30), // Bordes redondeados
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2), // Fondo con efecto frosted
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(255, 92, 92, 92)
                                .withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(5, 5),
                          ),
                        ],
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero, // Elimina padding interno
                        constraints: const BoxConstraints(), // Quita constraints por defecto
                        icon: Image.asset(
                          'assets/filter.png',
                          color: AppColors.blue,
                          width: 20,
                          height: 20,
                        ),
                        onPressed: () {
                          showExploreFilterDialog(context);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Botón de notificación con efecto frosted glass
                ClipRRect(
                  borderRadius: BorderRadius.circular(30), // Bordes redondeados
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2), // Fondo con efecto frosted
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(255, 92, 92, 92)
                                .withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(5, 5),
                          ),
                        ],
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero, // Elimina padding interno
                        constraints: const BoxConstraints(), // Quita constraints por defecto
                        icon: Image.asset(
                          'assets/notificacion.png',
                          color: AppColors.blue,
                          width: 20,
                          height: 20,
                        ),
                        onPressed: onFilterPressed,
                      ),
                    ),
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
