import 'package:flutter/material.dart';

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
    Key? key,
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
  }) : super(key: key);

@override
Widget build(BuildContext context) {
  return Container(
    margin: margin,
    child: FloatingActionButton.extended(
      heroTag: heroTag,
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: borderColor != null
            ? BorderSide(color: borderColor!, width: borderWidth)
            : BorderSide.none,
      ),
      icon: Image.asset(
        iconPath,
        height: 24,
        width: 24,
        color: iconColor,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: textColor ?? Colors.black,
          fontSize: 14, // Añadido tamaño de fuente
        ),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce espacio interno
      onPressed: onPressed,
    ),
  );
}
}
