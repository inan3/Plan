import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

/// Obtiene de forma síncrona hasta dos iniciales del [nombre].
String getInitialsSync(String nombre) => _computeInitials(nombre);

/// Calcula y cachea hasta dos iniciales del [nombre] utilizando
/// [SharedPreferences].
Future<String> getInitials(String nombre) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'initials_${nombre.hashCode}';
  final cached = prefs.getString(key);
  if (cached != null) return cached;

  final initials = _computeInitials(nombre);
  await prefs.setString(key, initials);
  return initials;
}

String _computeInitials(String nombre) {
  final partes =
      nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '';
  if (partes.length == 1) {
    final palabra = partes.first;
    return palabra.isNotEmpty ? palabra.substring(0, 1).toUpperCase() : '';
  }
  final primera = partes[0].isNotEmpty ? partes[0][0] : '';
  final segunda = partes[1].isNotEmpty ? partes[1][0] : '';
  return (primera + segunda).toUpperCase();
}

/// Genera un color de fondo a partir del [nombre] para que cada usuario tenga
/// un color consistente.
Color avatarColor(String nombre) {
  final idx = nombre.hashCode.abs() % Colors.primaries.length;
  return Colors.primaries[idx];
}

/// Construye un avatar mostrando las iniciales cuando no hay foto disponible.
Widget buildInitialsAvatar(String nombre, double radius) {
  return CircleAvatar(
    radius: radius,
    backgroundColor: avatarColor(nombre),
    child: Text(
      getInitialsSync(nombre),
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.8,
      ),
    ),
  );
}

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

/// Avatar circular a partir de la foto de perfil. Si no existe, se intenta
/// utilizar la imagen de fondo como alternativa. Si tampoco hay imagen de
/// fondo, se muestra un placeholder con silueta.
Widget buildProfileAvatar(String? photoUrl,
    {String? coverUrl, double radius = 20, String? userName}) {
  String? finalUrl;
  if (photoUrl != null && photoUrl.isNotEmpty) {
    finalUrl = photoUrl;
  } else if (coverUrl != null && coverUrl.isNotEmpty) {
    finalUrl = coverUrl;
  }

  if (finalUrl != null) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: CachedNetworkImageProvider(finalUrl),
    );
  } else if (userName != null && userName.trim().isNotEmpty) {
    return buildInitialsAvatar(userName, radius);
  } else {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      child: SvgPicture.asset('assets/usuario.svg',
          width: radius, height: radius),
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
