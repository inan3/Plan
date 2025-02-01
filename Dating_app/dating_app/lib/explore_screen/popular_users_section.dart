import 'dart:ui'; // para BackdropFilter
import 'package:flutter/material.dart';

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
      height: 180,
      child: Column(
        children: [
          // Encabezado (Populares + VerTodos)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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

  /// Construye una tarjeta con imagen de fondo y la banda inferior "frosted"
  Widget _buildPopularUserCard(String name, int stars) {
    // Podrías usar la foto real del usuario si la tuvieras
    // Aquí mostramos una imagen de ejemplo
    const exampleImage =
        'https://images.pexels.com/photos/415829/pexels-photo-415829.jpeg?auto=compress';

    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Imagen de fondo
            Positioned.fill(
              child: Image.network(
                exampleImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey),
              ),
            ),
            // Solamente la banda inferior con efecto "cristal"
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildFrostedInfo(name, stars),
            ),
          ],
        ),
      ),
    );
  }

  /// El recuadro inferior translúcido y desenfocado
  Widget _buildFrostedInfo(String name, int stars) {
    return ClipRRect(
      // Ajustamos el borde inferior, si deseas más redondeo
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 50, // Altura fija para la franja de info
          color: Colors.white.withOpacity(0.2),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Nombre
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),

              // Estrellas
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 3),
                  Text(
                    '$stars',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
