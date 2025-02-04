// search_screen.dart
import 'package:flutter/material.dart';
import 'package:dating_app/main/colors.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar'),
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text(
          'Pantalla de búsqueda',
          style: TextStyle(fontSize: 18, color: Colors.grey[700]),
        ),
      ),
    );
  }
}
