// options_for_plans.dart
import 'dart:ui';
import 'package:flutter/material.dart';

void showPlanOptions(
  BuildContext context,
  dynamic planData,
  Offset buttonOffset,
  Size buttonSize,
) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, child) {
      final fadeAnimation = CurvedAnimation(
        parent: anim,
        curve: Curves.easeInOut,
      );

      // Medidas de pantalla para evitar que el menú se corte
      final screenWidth = MediaQuery.of(ctx).size.width;
      final screenHeight = MediaQuery.of(ctx).size.height;

      // Ancho del menú
      const double menuWidth = 180.0;
      // Margen superior extra para que no solape el botón
      const double additionalTopMargin = 4.0;

      // Queremos alinear el menú a la derecha del botón.
      // El borde derecho del botón está en: offset.dx + buttonSize.width
      // Así que el menú debe comenzar en (dx + width - menuWidth)
      double leftPos = buttonOffset.dx + buttonSize.width - menuWidth;
      // Calculamos la posición vertical: justo debajo del botón
      double topPos = buttonOffset.dy + buttonSize.height + additionalTopMargin;

      // Clamps para no salirse de la pantalla (horizontal)
      // Si leftPos < 0, lo ponemos a 0
      if (leftPos < 0) leftPos = 0;
      // Si el menú se sale por la derecha, lo movemos para que quede visible
      if (leftPos + menuWidth > screenWidth) {
        leftPos = screenWidth - menuWidth - 8; 
        // el "- 8" es por darle algo de respiro al borde
      }

      // Opcional: si topPos se acerca mucho al final de la pantalla, podrías
      // dibujar el menú hacia arriba. Aquí lo dejamos básico.
      // Ejemplo:
      // if (topPos + 200 > screenHeight) {
      //   topPos = buttonOffset.dy - 200; // hacia arriba
      // }

      return FadeTransition(
        opacity: fadeAnimation,
        child: Stack(
          children: [
            Positioned(
              top: topPos,
              left: leftPos,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      width: menuWidth,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMenuOption(
                            context,
                            icon: Icons.person_add_alt_1,
                            label: 'Unirse a Plan',
                            onTap: () {
                              Navigator.of(context).pop();
                              // TODO: Lógica para "Unirse al plan"
                            },
                          ),
                          const Divider(color: Colors.white54),
                          _buildMenuOption(
                            context,
                            icon: Icons.bookmark_border,
                            label: 'Guardar como favorito',
                            onTap: () {
                              Navigator.of(context).pop();
                              // TODO: Lógica para "Guardar como favorito"
                            },
                          ),
                          const Divider(color: Colors.white54),
                          _buildMenuOption(
                            context,
                            icon: Icons.share,
                            label: 'Compartir',
                            onTap: () {
                              Navigator.of(context).pop();
                              // TODO: Lógica para "Compartir"
                            },
                          ),
                          const Divider(color: Colors.white54),
                          _buildMenuOption(
                            context,
                            icon: Icons.info_outline,
                            label: 'Ver más detalles',
                            onTap: () {
                              Navigator.of(context).pop();
                              // TODO: Lógica para "Ver más detalles"
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildMenuOption(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Row(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
