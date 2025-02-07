// search_screen.dart
import 'package:flutter/material.dart';
import 'package:dating_app/main/colors.dart';
import 'filter_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _searchText = '';

  /// Función que navega a la pantalla de filtros.
  /// Se pasan unos valores por defecto, pero podrías adaptarlos según tu lógica.
  void _onFilterPressed() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilterScreen(
          initialAgeRange: const RangeValues(18, 40),
          initialDistance: 50,
          initialSelection: 0,
        ),
      ),
    );
    // Aquí podrías manejar el resultado de la pantalla de filtros, si es necesario.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Espaciado para bajar los elementos
          const SizedBox(height: 50),
          // Entrada de texto con ícono de lupa y botón de filtro
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Campo de búsqueda con ícono de lupa a la izquierda
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchText = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar...',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Image.asset(
                          'assets/lupa.png',
                          width: 24,
                          height: 24,
                          color: AppColors.blue,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Ícono de filtro que abre la pantalla de filtros
                IconButton(
                  icon: Image.asset(
                    'assets/filter.png',
                    width: 24,
                    height: 24,
                    color: AppColors.blue,
                  ),
                  onPressed: _onFilterPressed,
                ),
              ],
            ),
          ),
          // Resto del contenido de la pantalla de búsqueda
          Expanded(
            child: Center(
              child: Text(
                'Pantalla de búsqueda\nTexto ingresado: $_searchText',
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
