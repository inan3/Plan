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
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Botón de Menú en la izquierda
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
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
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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

          // Logo desplazado hacia la derecha
          Transform.translate(
            offset: const Offset(34, 0), // Ajusta este valor para desplazar el logo a la derecha
            child: Image.asset(
              'assets/plan-sin-fondo.png',
              height: 80,
            ),
          ),

          // Contenedor para los botones de filtro y notificación en la derecha
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Botón de filtro
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
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
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
                // Botón de notificación
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
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
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
