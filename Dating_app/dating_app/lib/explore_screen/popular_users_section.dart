import 'dart:math';
import 'dart:ui'; // para BackdropFilter
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PopularUsersSection extends StatelessWidget {
  final double topSpacing; // Espacio superior configurable

  const PopularUsersSection({Key? key, this.topSpacing = 0}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Lista dummy para determinar la cantidad de elementos.
    final users = [
      {'name': 'Usuario 1'},
      {'name': 'Usuario 2'},
      {'name': 'Usuario 3'},
      {'name': 'Usuario 4'},
      {'name': 'Usuario 5'},
      {'name': 'Usuario 6'},
      {'name': 'Usuario 7'},
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Espacio superior (si es necesario).
        SizedBox(height: topSpacing),
        // Lista horizontal de usuarios (altura ajustada a 90 para dar espacio al nombre).
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: users.length,
            itemBuilder: (context, index) {
              return _buildPopularUserCard();
            },
          ),
        ),
      ],
    );
  }

  /// Construye una tarjeta con un avatar y un nombre debajo.
  Widget _buildPopularUserCard() {
    const exampleImage =
        'https://images.pexels.com/photos/415829/pexels-photo-415829.jpeg?auto=compress';

    // Lista de nombres aleatorios.
    const randomNames = [
      "Juan",
      "Pedro",
      "María",
      "Ana",
      "Luis",
      "Sofía",
      "Carlos",
      "Elena",
      "Miguel",
      "Lucía"
    ];

    final random = Random();
    final randomName = randomNames[random.nextInt(randomNames.length)];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar con radio reducido para liberar espacio.
          CircleAvatar(
            radius: 30, // Diámetro de 50.
            backgroundImage: CachedNetworkImageProvider(exampleImage),
            backgroundColor: Colors.grey[300],
          ),
          const SizedBox(height: 4),
          // Nombre debajo; se usa Flexible para evitar overflow.
          Flexible(
            child: Text(
              randomName,
              style: const TextStyle(fontSize: 12, color: Colors.black),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
