// lib/explore_screen/follow/followers_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Muestra la lista de usuarios que siguen al [userId].
class FollowersScreen extends StatelessWidget {
  final String userId;

  const FollowersScreen({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Consulta a la colección 'followers' para obtener quiénes siguen a userId.
    final followersQuery = FirebaseFirestore.instance
        .collection('followers')
        .where('userId', isEqualTo: userId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguidores'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: followersQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar los seguidores'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay seguidores'));
          }

          // Tenemos documentos con { userId, followerId }
          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final followerId = data['followerId'] as String?;

              if (followerId == null) {
                return const ListTile(
                  title: Text('ID de seguidor no encontrado'),
                );
              }

              // Hacemos un FutureBuilder para cargar los datos de ese seguidor
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(followerId)
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
