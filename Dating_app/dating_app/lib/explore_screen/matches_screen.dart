import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/plan_model.dart';

class MatchesScreen extends StatelessWidget {
  final String currentUserId; // ID del usuario actual

  const MatchesScreen({Key? key, required this.currentUserId}) : super(key: key);

  /// Manejo de la aceptación de la solicitud
/// Manejo de la aceptación de la solicitud
void _acceptRequest(BuildContext context, String notificationId, String planId, String requesterId) async {
  try {
    // Actualiza la notificación como aceptada
    await FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({
      'status': 'accepted',
    });

    // Enviar notificación de aceptación al solicitante
    await FirebaseFirestore.instance.collection('notifications').add({
      'type': 'request_accepted',
      'receiverId': requesterId,
      'planId': planId,
      'message': 'Tu solicitud para unirte al plan ha sido aceptada.',
      'createdAt': DateTime.now().toIso8601String(),
    });

    // Elimina la notificación de la pantalla (Firestore)
    await FirebaseFirestore.instance.collection('notifications').doc(notificationId).delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud aceptada exitosamente.')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al aceptar la solicitud: $e')),
    );
  }
}

/// Manejo del rechazo de la solicitud
void _rejectRequest(BuildContext context, String notificationId) async {
  try {
    // Actualiza la notificación como rechazada
    await FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({
      'status': 'rejected',
    });

    // Elimina la notificación de la pantalla (Firestore)
    await FirebaseFirestore.instance.collection('notifications').doc(notificationId).delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud rechazada.')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al rechazar la solicitud: $e')),
    );
  }
}


  /// Mostrar el perfil del usuario
  void _viewUserProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
      ),
    );
  }


  /// Construir la vista de notificaciones
Widget _buildNotificationItem(BuildContext context, DocumentSnapshot notificationDoc) {
  final data = notificationDoc.data() as Map<String, dynamic>;

  return FutureBuilder<DocumentSnapshot>(
    future: FirebaseFirestore.instance.collection('plans').doc(data['planId']).get(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (!snapshot.hasData || !snapshot.data!.exists) {
        return const SizedBox(); // El plan ya no existe
      }

      // Construimos el plan desde el documento de Firestore
      final planData = snapshot.data!.data() as Map<String, dynamic>;
      final PlanModel plan = PlanModel.fromMap(planData);

      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(data['senderId']).get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const ListTile(
              title: Text('Usuario no encontrado'),
              subtitle: Text('No se pudo obtener la información del usuario.'),
            );
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final requesterName = userData['name'] ?? 'Usuario desconocido';
          final requesterProfilePic = userData['photoUrl'] ?? 'https://via.placeholder.com/150';

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(requesterProfilePic),
            ),
            title: Text('$requesterName ha solicitado unirse a tu plan de ${plan.type}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _rejectRequest(context, notificationDoc.id),
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _acceptRequest(context, notificationDoc.id, plan.id, data['senderId']),
                ),
              ],
            ),
            onTap: () => _viewUserProfile(context, data['senderId']),
          );
        },
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Botón flotante con "X" para salir
          Positioned(
            top: 45,
            left: 30,
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context); // Vuelve a la pantalla anterior
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.close, color: Colors.blue, size: 28),
              ),
            ),
          ),
          // Logo centrado en la parte superior
          Positioned(
            top: 45,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/plan-sin-fondo.png',
                height: 40,
              ),
            ),
          ),
          // Contenido principal de las notificaciones
          Positioned.fill(
            top: 120, // Ajusta el espacio debajo del logo y botón
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('receiverId', isEqualTo: currentUserId)
                  .where('type', isEqualTo: 'join_request')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No tienes notificaciones.'));
                }

                final notifications = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notificationDoc = notifications[index];
                    return _buildNotificationItem(context, notificationDoc);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No se encontró información del usuario.'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;

          return Column(
            children: [
              // AppBar personalizada
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Image.asset(
                      'assets/plan-sin-fondo.png',
                      height: 40,
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Image.network(
                        userData['profilePic'] ?? 'https://via.placeholder.com/150',
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${userData['name']}, ${userData['age']} años',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text('Email: ${userData['email']}'),
                          const SizedBox(height: 8),
                          Text('Descripción: ${userData['description'] ?? 'Sin descripción'}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
