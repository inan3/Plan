import 'package:flutter/material.dart';

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
