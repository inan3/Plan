// lib/explore_screen/follow/followed_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Muestra la lista de usuarios que [userId] está siguiendo (followed).
class FollowedScreen extends StatelessWidget {
  final String userId;

  const FollowedScreen({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Consulta a la colección 'followed' para obtener a quién sigue userId.
    final followedQuery = FirebaseFirestore.instance
        .collection('followed')
        .where('userId', isEqualTo: userId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Siguiendo'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: followedQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar los seguidos'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No sigues a nadie'));
          }

          // Tenemos documentos con { userId, followedId }
          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final followedId = data['followedId'] as String?;

              if (followedId == null) {
                return const ListTile(
                  title: Text('ID de seguido no encontrado'),
                );
              }

              // Obtenemos datos del usuario seguido
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(followedId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('Cargando...'),
                    );
                  }
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const ListTile(
                      title: Text('Usuario no encontrado'),
                    );
                  }
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final name = userData['name'] ?? 'Usuario sin nombre';
                  final photoUrl = userData['photoUrl'] ?? '';
                  final bio = userData['bio'] ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(name),
                    subtitle: Text(bio),
                    onTap: () {
                      // Aquí podrías navegar a la pantalla de detalle de ese usuario, etc.
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
