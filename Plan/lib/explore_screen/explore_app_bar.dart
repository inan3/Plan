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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.tealAccent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón de Menú
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: onMenuPressed,
          ),
          // Campo de Búsqueda
          Expanded(
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const Icon(Icons.search, color: Colors.tealAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Buscar...',
                        hintStyle: TextStyle(color: AppColors.black),
                      ),
                      style: const TextStyle(color: AppColors.black),
                      onChanged: onSearchChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Botón de Filtro
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white),
            onPressed: onFilterPressed,
          ),
        ],
      ),
    );
  }
}
