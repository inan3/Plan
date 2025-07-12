import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Placeholder genérico para cuando falle el loading de una imagen.
Widget buildPlaceholder() {
  return SizedBox(
    width: double.infinity,
    child: AspectRatio(
      aspectRatio: 1,
      child: Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
        ),
      ),
    ),
  );
}

/// Avatar circular dado un `photoUrl`. Si está vacío o nulo, muestra un ícono.
Widget buildProfileAvatar(String? photoUrl) {
  if (photoUrl != null && photoUrl.isNotEmpty) {
    return CircleAvatar(
      radius: 20,
      backgroundImage: NetworkImage(photoUrl),
    );
  } else {
    return const CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey,
      child: Icon(Icons.person, color: Colors.white),
    );
  }
}

/// Ordena una lista de usuarios por distancia a [usuarioActual].
///
/// Los usuarios con coordenadas (0, 0) se consideran sin ubicación válida y se
/// colocan al final de la lista. La distancia se calcula con la fórmula de
/// Haversine y la lista resultante es ascendente (más cercanos primero).
List<Map<String, dynamic>> ordenarUsuariosPorDistancia(
    List<Map<String, dynamic>> users, Map<String, dynamic> usuarioActual) {
  final refLat = (usuarioActual['latitude'] as num?)?.toDouble() ?? 0.0;
  final refLng = (usuarioActual['longitude'] as num?)?.toDouble() ?? 0.0;

  final sorted = List<Map<String, dynamic>>.from(users);

  sorted.sort((a, b) {
    final latA = (a['latitude'] as num?)?.toDouble() ?? 0.0;
    final lngA = (a['longitude'] as num?)?.toDouble() ?? 0.0;
    final latB = (b['latitude'] as num?)?.toDouble() ?? 0.0;
    final lngB = (b['longitude'] as num?)?.toDouble() ?? 0.0;

    final validA = !(latA == 0 && lngA == 0);
    final validB = !(latB == 0 && lngB == 0);

    if (!validA && !validB) return 0;
    if (!validA) return 1;
    if (!validB) return -1;

    final distA = _calcularDistancia(refLat, refLng, latA, lngA);
    final distB = _calcularDistancia(refLat, refLng, latB, lngB);
    return distA.compareTo(distB);
  });

  return sorted;
}

double _calcularDistancia(
    double lat1, double lng1, double lat2, double lng2) {
  const radioTierra = 6371; // kilómetros
  final dLat = _deg2rad(lat2 - lat1);
  final dLng = _deg2rad(lng2 - lng1);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return radioTierra * c;
}

double _deg2rad(double deg) => deg * (math.pi / 180);
