import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Ajusta estas rutas a tu estructura:
import '../plan_creation/new_plan_creation_screen.dart';
import '../plan_joining/plan_join_request.dart';
import '../explore_screen/menu_side_bar/subscribed_plans_screen.dart';

class MatchesScreen extends StatefulWidget {
  final String currentUserId;

  const MatchesScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  MatchesScreenState createState() => MatchesScreenState();
}

class MatchesScreenState extends State<MatchesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Notificaciones de 'join_request' (cuando alguien pide unirse a un plan creado por este usuario B)
  Stream<QuerySnapshot> _joinRequestsStream() {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: widget.currentUserId)
        .where('type', isEqualTo: 'join_request')
        .snapshots();
  }

  /// Notificaciones de 'join_accepted' o 'join_rejected' (cuando a este usuario A le aceptan o rechazan en un plan)
  Stream<QuerySnapshot> _responseNotificationsStream() {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: widget.currentUserId)
        .where('type', whereIn: ['join_accepted', 'join_rejected'])
        .snapshots();
  }

  /// Aceptar la solicitud (B acepta a A)
  Future<void> _acceptRequest(DocumentSnapshot notificationDoc) async {
    try {
      final data = notificationDoc.data() as Map<String, dynamic>;
      final planId = data['planId'];
      final planName = data['planName'] ?? 'Plan';
      final senderId = data['senderId']; // A (quien solicitó unirse)

      // 1) Eliminar la notificación de tipo 'join_request'
      await notificationDoc.reference.delete();

      // 2) Obtener el documento completo del plan para duplicar sus datos en 'subscriptions'
      final planSnap = await _firestore.collection('plans').doc(planId).get();
      if (!planSnap.exists) {
        throw Exception('El plan con ID $planId ya no existe.');
      }
      final planData = planSnap.data() as Map<String, dynamic>;

      // Convertir posibles Timestamps a String (para que PlanModel.fromMap no falle)
      String? dateIso;
      if (planData['date'] != null) {
        // Puede ser String o Timestamp
        if (planData['date'] is Timestamp) {
          dateIso = (planData['date'] as Timestamp).toDate().toIso8601String();
        } else if (planData['date'] is String) {
          dateIso = planData['date'];
        }
      }
      String? createdAtIso;
      if (planData['createdAt'] != null) {
        if (planData['createdAt'] is Timestamp) {
          createdAtIso =
              (planData['createdAt'] as Timestamp).toDate().toIso8601String();
        } else if (planData['createdAt'] is String) {
          createdAtIso = planData['createdAt'];
        }
      }

      // 3) Crear documento en 'subscriptions' con todos los campos que PlanModel necesita
      await _firestore.collection('subscriptions').add({
        // Campos del plan (coinciden con PlanModel):
        'id': planData['id'],                        // planId
        'type': planData['type'],
        'description': planData['description'],
        'minAge': planData['minAge'],
        'maxAge': planData['maxAge'],
        'maxParticipants': planData['maxParticipants'],
        'location': planData['location'],
        'latitude': planData['latitude'],
        'longitude': planData['longitude'],
        'date': dateIso,                             // String
        'createdBy': planData['createdBy'],
        'creatorName': planData['creatorName'],
        'creatorProfilePic': planData['creatorProfilePic'],
        'createdAt': createdAtIso,                   // String

        // Campos adicionales de la suscripción
        'userId': senderId, // El usuario que se suscribe
        'subscriptionCreatedAt': FieldValue.serverTimestamp(),
      });

      // 4) Crear la notificación 'join_accepted' para el usuario A
      await _firestore.collection('notifications').add({
        'type': 'join_accepted',
        'receiverId': senderId,                  // A recibe
        'senderId': widget.currentUserId,        // B envía
        'planId': planId,
        'planName': planName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Has aceptado la solicitud para el plan "$planName"')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aceptar la solicitud: $e')),
      );
    }
  }

  /// Rechazar la solicitud (B rechaza a A)
  Future<void> _rejectRequest(DocumentSnapshot notificationDoc) async {
    try {
      final data = notificationDoc.data() as Map<String, dynamic>;
      final planId = data['planId'];
      final planName = data['planName'] ?? 'Plan';
      final senderId = data['senderId']; // A

      // 1) Eliminar la notificación de join_request
      await notificationDoc.reference.delete();

      // 2) Crear notificación 'join_rejected' para A
      await _firestore.collection('notifications').add({
        'type': 'join_rejected',
        'receiverId': senderId,             // A recibe
        'senderId': widget.currentUserId,   // B envía
        'planId': planId,
        'planName': planName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Has rechazado la solicitud para el plan "$planName"')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar la solicitud: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usamos un TabController para separar:
    // Tab 1: Solicitudes (join_request)
    // Tab 2: Respuestas (join_accepted / join_rejected)
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notificaciones'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Solicitudes'),         // B ve y acepta/rechaza
              Tab(text: 'Mis Notificaciones'),  // A ve si fue aceptado/rechazado
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ================= TAB 1: JOIN REQUESTS =================
            StreamBuilder<QuerySnapshot>(
              stream: _joinRequestsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar solicitudes'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No hay solicitudes pendientes.'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final requesterName = data['requesterName'] ?? 'Desconocido';
                    final requesterPic = data['requesterProfilePic'] ?? '';
                    final planName = data['planName'] ?? '(Plan)';
                    final planId = data['planId'] ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(
                          requesterPic.isNotEmpty
                              ? requesterPic
                              : 'https://via.placeholder.com/150',
                        ),
                      ),
                      title: Text('$requesterName quiere unirse al plan "$planName" (ID: $planId)'),
                      subtitle: const Text('Pulsa Aceptar o Rechazar'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Rechazar',
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _rejectRequest(doc),
                          ),
                          IconButton(
                            tooltip: 'Aceptar',
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _acceptRequest(doc),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            // ================= TAB 2: JOIN ACCEPTED / JOIN REJECTED =================
            StreamBuilder<QuerySnapshot>(
              stream: _responseNotificationsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar notificaciones'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No tienes notificaciones nuevas.'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final type = data['type'] as String;
                    final planName = data['planName'] ?? '(Plan)';
                    final planId = data['planId'] ?? '';

                    // Distintos textos para aceptado o rechazado
                    String contentText;
                    if (type == 'join_accepted') {
                      contentText = '¡Te han aceptado en el plan "$planName" (ID: $planId)!';
                    } else {
                      contentText = 'Lo sentimos, te han rechazado en el plan "$planName" (ID: $planId).';
                    }

                    return ListTile(
                      title: Text(contentText),
                      onTap: () async {
                        // Eliminamos la notificación al pulsarla
                        await doc.reference.delete();

                        if (type == 'join_accepted') {
                          // Redirigimos a Planes Suscritos
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SubscribedPlansScreen(
                                userId: widget.currentUserId,
                              ),
                            ),
                          );
                        } else {
                          // Rechazado: simplemente avisamos
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Has sido rechazado para el plan "$planName" (ID: $planId)'),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
