import 'package:flutter/material.dart';

class PlanActionButton extends StatelessWidget {
  final String heroTag;
  final String label;
  final String iconPath;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry margin;
  final Color backgroundColor; // Color de fondo personalizado

  const PlanActionButton({
    Key? key,
    required this.heroTag,
    required this.label,
    required this.iconPath,
    required this.onPressed,
    required this.margin,
    this.backgroundColor = Colors.white, // Valor por defecto
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: FloatingActionButton.extended(
        heroTag: heroTag,
        backgroundColor: backgroundColor, // Usar el color especificado
        icon: Image.asset(
          iconPath,
          height: 24,
          width: 24,
        ),
        label: Text(
          label,
          style: const TextStyle(color: Colors.black),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30), // Bordes redondeados
        ),
        onPressed: onPressed,
      ),
    );
  }
}
