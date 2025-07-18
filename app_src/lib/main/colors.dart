import 'package:flutter/material.dart';

class AppColors {
  // Colores principales

  static const Color planColor = Color(0xFF5D17EB);
  static const Color primary = Color(0xFF6200EA);
  static const Color primaryDark = Color(0xFF3700B3);
  static const Color primaryLight = Color.fromARGB(255, 56, 42, 255);

  // Colores secundarios
  // Nota: agregamos 'pink' para evitar errores en user_registration_screen.dart
  static const Color pink = Color(0xFFFF4081);
  
  static const Color blue = Color.fromARGB(236, 0, 4, 227);
  static const Color secondaryDark = Color(0xFF018786);

  // Colores de fondo
  static const Color background = Color(0xFFFEF7FF);
  static const Color black = Color.fromARGB(255, 0, 0, 0);

  // Colores de texto
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;

  // Colores de error
  static const Color error = Color(0xFFCF6679);

  // Colores personalizados
  static const Color createPlanButton = Color.fromARGB(255, 197, 38, 38);
  static const Color joinPlanButton = Color.fromARGB(255, 38, 61, 236);

  // Nuevos colores para filtros
  static const Color lightLilac = Color.fromARGB(255, 247, 241, 254);
  static const Color searchLilac = Color(0xFFE6D3FF);
  static const Color lightTurquoise = Color(0xFFCCF1F0);
  static const Color shareSheetBackground = Color.fromARGB(255, 35, 57, 80);
  static const Color greyBorder = Color(0xFFCCCCCC);

  // Color blanco (faltante)
  static const Color white = Color(0xFFFFFFFF);
  static const Color popularBackground = Color(0xFFF3F4F6); // Gris claro
  static const Color nearbyBackground = Color(0xFFFFFFFF); // Blanco
}
