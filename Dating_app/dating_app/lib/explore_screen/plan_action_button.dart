import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PlanActionButton extends StatelessWidget {
  final String heroTag;
  final String label;
  final String iconPath;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry margin;
  final Color backgroundColor; // Color de fondo personalizado
  final Color? borderColor; // Color del borde
  final double borderWidth; // Ancho del borde
  final Color? textColor; // Color del texto
  final Color? iconColor; // Color del icono
  final List<BoxShadow>? boxShadow; // Sombra personalizada

  const PlanActionButton({
    super.key,
    required this.heroTag,
    required this.label,
    required this.iconPath,
    required this.onPressed,
    required this.margin,
    this.backgroundColor = Colors.white, // Valor por defecto
    this.borderColor,
    this.borderWidth = 0.0, // Por defecto no hay borde
    this.textColor,
    this.iconColor,
    this.boxShadow,
  });

  // Método auxiliar para cargar el ícono según su extensión
  Widget _buildIcon() {
    if (iconPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        iconPath,
        height: 24,
        width: 24,
        color: iconColor,
      );
    } else {
      return Image.asset(
        iconPath,
        height: 24,
        width: 24,
        color: iconColor,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      // Si necesitas agregar sombra personalizada, la puedes incluir aquí usando BoxDecoration
      decoration: boxShadow != null
          ? BoxDecoration(
              boxShadow: boxShadow,
            )
          : null,
      child: FloatingActionButton.extended(
        heroTag: heroTag,
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: borderColor != null
              ? BorderSide(color: borderColor!, width: borderWidth)
              : BorderSide.none,
        ),
        icon: _buildIcon(),
        label: Text(
          label,
          style: TextStyle(
            color: textColor ?? Colors.black,
            fontSize: 14, // Tamaño de fuente
          ),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce espacio interno
        onPressed: onPressed,
      ),
    );
  }
}
