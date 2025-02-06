// popular_users_section.dart
import 'dart:ui'; // para BackdropFilter
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PopularUsersSection extends StatelessWidget {
  const PopularUsersSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final users = [
      {'name': 'Usuario 1', 'stars': 20},
      {'name': 'Usuario 2', 'stars': 15},
      {'name': 'Usuario 3', 'stars': 12},
      {'name': 'Usuario 4', 'stars': 10},
      {'name': 'Usuario 5', 'stars': 8},
      {'name': 'Usuario 6', 'stars': 7},
      {'name': 'Usuario 7', 'stars': 5},
    ];

    return SizedBox(
      height: 100, // Altura general de la sección de populares
      child: Column(
        children: [
          // Encabezado (Populares + Ver Todos) con margen horizontal de 15
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Populares',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Acción "Ver Todos"
                  },
                  child: const Text(
                    'Ver Todos',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Lista horizontal de usuarios
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final String name = user['name'] as String;
                final int stars = user['stars'] as int;
                return _buildPopularUserCard(name, stars);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Construye una tarjeta con un círculo perfecto para el perfil y la información de estrellas debajo.
  Widget _buildPopularUserCard(String name, int stars) {
    // Imagen de ejemplo para el perfil.
    const exampleImage =
        'https://images.pexels.com/photos/415829/pexels-photo-415829.jpeg?auto=compress';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Círculo perfecto con la imagen de perfil
          CircleAvatar(
            radius: 30, // Diámetro de 60
            backgroundImage: CachedNetworkImageProvider(exampleImage),
            backgroundColor: Colors.grey[300],
          ),
          const SizedBox(height: 4),
          // Información de estrellas (los iconos mantienen su tamaño)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 3),
              Text(
                '$stars',
                style: const TextStyle(fontSize: 14, color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
