import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MatchesScreen extends StatefulWidget {
  final String currentUserId;

  const MatchesScreen({super.key, required this.currentUserId});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // STREAM: Solicitudes entrantes (join_request)
  Stream<QuerySnapshot> _getJoinRequests() => _firestore
      .collection('notifications')
      .where('receiverId', isEqualTo: widget.currentUserId)
      .where('type', isEqualTo: 'join_request')
      .snapshots();

  // STREAM: Respuestas (join_accepted / join_rejected)
  Stream<QuerySnapshot> _getResponses() => _firestore
      .collection('notifications')
      .where('receiverId', isEqualTo: widget.currentUserId)
      .where('type', whereIn: ['join_accepted', 'join_rejected'])
      .snapshots();

  // El creador ACEPTA la solicitud
  Future<void> _handleAccept(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final planId = data['planId'] as String;
      final senderId = data['senderId'] as String;

      // Elimina la notificación de solicitud original
      await doc.reference.delete();

      // Obtén el plan para actualizarlo
      final planRef = _firestore.collection('plans').doc(planId);
      final planDoc = await planRef.get();
      if (!planDoc.exists) return;

      // Agrega al solicitante al array 'participants'
      await planRef.update({
        'participants': FieldValue.arrayUnion([senderId]),
      });

      // (Opcional) Crea un registro en 'subscriptions'
      await _firestore.collection('subscriptions').add({
        ...planDoc.data()! as Map<String, dynamic>,
        'userId': senderId,
        'subscriptionDate': FieldValue.serverTimestamp(),
      });

      // Obtener la foto de perfil del creador
      final creatorDoc = await _firestore
          .collection('users')
          .doc(widget.currentUserId)
          .get();
      String creatorPhoto = '';
      if (creatorDoc.exists) {
        final creatorData = creatorDoc.data() as Map<String, dynamic>;
        creatorPhoto = creatorData['photoUrl'] as String? ?? '';
      }

      // Notificar al solicitante que se le ha aceptado, con la foto del creador
      await _firestore.collection('notifications').add({
        'type': 'join_accepted',
        'receiverId': senderId,    // solicitante
        'senderId': widget.currentUserId, // creador
        'planId': planId,
        'planName': data['planName'],
        'senderProfilePic': creatorPhoto,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // El creador RECHAZA la solicitud
  Future<void> _handleReject(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId'] as String;

      // Eliminar la solicitud original
      await doc.reference.delete();

      // Obtener la foto de perfil del creador
      final creatorDoc = await _firestore
          .collection('users')
          .doc(widget.currentUserId)
          .get();
      String creatorPhoto = '';
      if (creatorDoc.exists) {
        final creatorData = creatorDoc.data() as Map<String, dynamic>;
        creatorPhoto = creatorData['photoUrl'] as String? ?? '';
      }

      // Notificar al solicitante que ha sido rechazado
      // Incluimos 'senderProfilePic' para mostrar la foto del creador
      await _firestore.collection('notifications').add({
        'type': 'join_rejected',
        'receiverId': senderId,
        'senderId': widget.currentUserId,
        'planId': data['planId'],
        'planName': data['planName'],
        'senderProfilePic': creatorPhoto,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notificaciones'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.group_add), text: 'Solicitudes'),
              Tab(icon: Icon(Icons.notifications), text: 'Respuestas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRequestsList(),
            _buildResponsesList(),
          ],
        ),
      ),
    );
  }

  // Construye la lista de Solicitudes
  Widget _buildRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getJoinRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildErrorWidget();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        final docs = snapshot.data?.docs ?? [];
        return docs.isEmpty
            ? _buildEmpty('No hay solicitudes nuevas')
            : ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return ListTile(
                    leading: _buildUserAvatar(data),
                    title: Text(
                      data['requesterName'] ?? 'Usuario desconocido',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plan: ${data['planName']}'),
                        Text(
                          'ID: ${data['planId']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _handleReject(doc),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _handleAccept(doc),
                        ),
                      ],
                    ),
                  );
                },
              );
      },
    );
  }

  // Construye la lista de Respuestas
  Widget _buildResponsesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getResponses(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildErrorWidget();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        final docs = snapshot.data?.docs ?? [];
        return docs.isEmpty
            ? _buildEmpty('Sin respuestas recientes')
            : ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isAccepted = data['type'] == 'join_accepted';

                  return ListTile(
                    leading: _buildResponseAvatar(data),
                    title: Text(
                      isAccepted
                          ? 'Aceptado en ${data['planName']}'
                          : 'Rechazado en ${data['planName']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('ID: ${data['planId']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 22),
                      onPressed: () => doc.reference.delete(),
                    ),
                  );
                },
              );
      },
    );
  }

  // Construye el avatar del solicitante en la lista de Solicitudes
  Widget _buildUserAvatar(Map<String, dynamic> data) {
    final String? photoUrl = data['requesterProfilePic'] as String?;
    return CircleAvatar(
      radius: 25,
      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
          ? NetworkImage(photoUrl)
          : const NetworkImage(
              'https://cdn-icons-png.flaticon.com/512/847/847969.png',
            ),
      onBackgroundImageError: (_, __) {},
      child: (photoUrl == null || photoUrl.isEmpty)
          ? const Icon(Icons.person, size: 30)
          : null,
    );
  }

  // Construye el avatar de las notificaciones de aceptación/rechazo
  Widget _buildResponseAvatar(Map<String, dynamic> data) {
    final String? photoUrl = data['senderProfilePic'] as String?;
    final bool isAccepted = data['type'] == 'join_accepted';
    final bool isRejected = data['type'] == 'join_rejected';

    // Si es aceptado o rechazado, mostramos la foto del creador (senderProfilePic).
    // Puedes añadir un ícono de “cancel” superpuesto si quieres diferenciarlo.
    return CircleAvatar(
      radius: 25,
      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
          ? NetworkImage(photoUrl)
          : const NetworkImage(
              'https://cdn-icons-png.flaticon.com/512/847/847969.png',
            ),
      onBackgroundImageError: (_, __) {},
      // Ejemplo: icono superpuesto solo si es rechazado
      //child: isRejected
      //    ? const Icon(Icons.cancel, color: Colors.red)
      //    : null,
    );
  }

  Widget _buildLoading() => const Center(
        child: CircularProgressIndicator(
          color: Colors.blue,
          strokeWidth: 2.5,
        ),
      );

  Widget _buildErrorWidget() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 40),
            SizedBox(height: 10),
            Text(
              'Error al cargar datos',
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
          ],
        ),
      );

  Widget _buildEmpty(String text) => Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
}
