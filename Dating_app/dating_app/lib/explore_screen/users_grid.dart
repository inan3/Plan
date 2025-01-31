import 'package:dating_app/main/colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsersGrid extends StatelessWidget {
  final List<QueryDocumentSnapshot> users;

  const UsersGrid({
    Key? key,
    required this.users,
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
        final userData = users[index].data() as Map<String, dynamic>;
        return _buildUserCard(userData);
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> userData) {
    final name = userData['name']?.toString().trim() ?? 'Usuario';
    final age = userData['age']?.toString() ?? '--';
    final photoUrl = userData['photoUrl']?.toString();
    final distance = userData['distance']?.toStringAsFixed(1) ?? '0.0';
    final stars = userData['stars']?.toString() ?? '0';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sección de imagen
          Container(
            height: 100,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildProfileImage(photoUrl),
                  _buildImageOverlay(),
                ],
              ),
            ),
          ),
          
          // Sección de información
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserInfo(name, age),
                const SizedBox(height: 4),
                _buildAdditionalInfo(distance, stars),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(String? photoUrl) {
    return photoUrl != null && photoUrl.isNotEmpty
        ? Image.network(
            photoUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          )
        : _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.person, size: 40, color: Colors.grey),
      ),
    );
  }

  Widget _buildImageOverlay() {
    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
          stops: const [0.6, 1],
        ).createShader(rect);
      },
      blendMode: BlendMode.darken,
      child: Container(color: Colors.transparent),
    );
  }

  Widget _buildUserInfo(String name, String age) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$age años',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfo(String distance, String stars) {
    return Row(
      children: [
        _buildInfoItem(Icons.location_on, '$distance km'),
        const SizedBox(width: 12),
        _buildInfoItem(Icons.star, stars),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.blue),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}