import 'dart:ui'; // para BackdropFilter
import 'package:dating_app/main/colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsersGrid extends StatelessWidget {
  final void Function(QueryDocumentSnapshot userDoc)? onUserTap;
  final List<QueryDocumentSnapshot> users;

  const UsersGrid({
    Key? key,
    required this.users,
    this.onUserTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.65,
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final userDoc = users[index];
        final userData = userDoc.data() as Map<String, dynamic>;

        return GestureDetector(
          onTap: () => onUserTap?.call(userDoc),
          child: _buildUserCard(userData),
        );
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> userData) {
    final name = userData['name']?.toString().trim() ?? 'Usuario';
    final age = userData['age']?.toString() ?? '--';
    final photoUrl = userData['photoUrl']?.toString();
    final distance = userData['distance']?.toStringAsFixed(1) ?? '0.0';
    final stars = userData['stars']?.toString() ?? '0';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // Imagen de fondo
          Positioned.fill(
            child: _buildProfileImage(photoUrl),
          ),

          // Banda inferior con los datos y el efecto “cristal”
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildFrostedInfo(
              name: name,
              age: age,
              distance: distance,
              stars: stars,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else {
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.person, size: 40, color: Colors.grey),
      ),
    );
  }

  /// Construye la franja inferior con desenfoque y datos
  Widget _buildFrostedInfo({
    required String name,
    required String age,
    required String distance,
    required String stars,
  }) {
    return ClipRRect(
      // Redondea la parte de arriba (el borde superior de la franja)
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 50,
          color: Colors.white.withOpacity(0.2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Fila de nombre + edad
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[200]?.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$age años',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Fila de ubicación + estrellas
              Row(
                children: [
                  _buildInfoItem(Icons.location_on, '$distance km'),
                  const SizedBox(width: 8),
                  _buildInfoItem(Icons.star, stars),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
