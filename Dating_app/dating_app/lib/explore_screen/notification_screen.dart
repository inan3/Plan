import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/plan_model.dart';
import '../main/colors.dart';

// Importaciones necesarias:
import 'users_managing/user_info_check.dart';
import '../models/plan_model.dart';
import 'users_grid/plan_card.dart';             // <--- Asegúrate de importar tu PlanCard
import 'users_grid/firebase_services.dart';    // <--- Para fetchPlanParticipants, si lo tienes

class NotificationScreen extends StatefulWidget {
  final String currentUserId;
  const NotificationScreen({Key? key, required this.currentUserId})
      : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Trae todas las notificaciones de interés
  Stream<QuerySnapshot> _getAllNotifications() {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: widget.currentUserId)
        .where('type', whereIn: [
          // Tipos de notificación que nos interesan
          'join_request',
          'invitation',
          'join_accepted',
          'join_rejected',
          'follow_request',
          'follow_accepted',
          'follow_rejected',
        ])
        .snapshots();
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    final dateTime = (timestamp as Timestamp).toDate();
    return DateFormat('HH:mm').format(dateTime);
  }

  //-----------------------------------------------------------------------
  // Aceptar join_request
  //-----------------------------------------------------------------------
  Future<void> _handleAcceptJoinRequest(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final planId = data['planId'] as String;
      final senderId = data['senderId'] as String;
      final planType = data['planType'] ?? data['planName'] ?? 'Plan';

      // Elimina notificación
      await doc.reference.delete();

      // Agrega el sender a la lista de participantes
      final planRef = _firestore.collection('plans').doc(planId);
      final planDoc = await planRef.get();
      if (!planDoc.exists) return;

      await planRef.update({
        'participants': FieldValue.arrayUnion([senderId]),
      });

      // Crea la suscripción
      await _firestore.collection('subscriptions').add({
        ...planDoc.data()!,
        'userId': senderId,
        'subscriptionDate': FieldValue.serverTimestamp(),
      });

      // Notifica al sender
      final acceptorDoc = await _firestore.collection('users')
          .doc(widget.currentUserId).get();
      final acceptorPhoto = acceptorDoc.exists
          ? (acceptorDoc.data()!['photoUrl'] ?? '')
          : '';

      await _firestore.collection('notifications').add({
        'type': 'join_accepted',
        'receiverId': senderId,
        'senderId': widget.currentUserId,
        'planId': planId,
        'planName': planType,
        'senderProfilePic': acceptorPhoto,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aceptar solicitud: $e')),
      );
    }
  }

  //-----------------------------------------------------------------------
  // Rechazar join_request
  //-----------------------------------------------------------------------
  Future<void> _handleRejectJoinRequest(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final planId = data['planId'] as String;
      final senderId = data['senderId'] as String;
      final planType = data['planType'] ?? data['planName'] ?? 'Plan';

      // Elimina la notificación
      await doc.reference.delete();

      // Notifica al que pidió unirse
      final rejectorDoc = await _firestore.collection('users')
          .doc(widget.currentUserId).get();
      final rejectorPhoto = rejectorDoc.exists
          ? (rejectorDoc.data()!['photoUrl'] ?? '')
          : '';
      final rejectorName = rejectorDoc.exists
          ? (rejectorDoc.data()!['name'] ?? '')
          : '';

      await _firestore.collection('notifications').add({
        'type': 'join_rejected',
        'receiverId': senderId,
        'senderId': widget.currentUserId,
        'planId': planId,
        'planName': planType,
        'senderProfilePic': rejectorPhoto,
        'senderName': rejectorName,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar solicitud: $e')),
      );
    }
  }

  //-----------------------------------------------------------------------
  // Aceptar invitación
  //-----------------------------------------------------------------------
  Future<void> _handleAcceptInvitation(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final planId = data['planId'] as String;
      final creatorId = data['senderId'] as String;
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final planType = data['planType'] ?? data['planName'] ?? 'Plan';

      // Elimina la notificación
      await doc.reference.delete();

      // Agrega al usuario actual al plan
      final planRef = _firestore.collection('plans').doc(planId);
      final planDoc = await planRef.get();
      if (!planDoc.exists) return;

      await planRef.update({
        'participants': FieldValue.arrayUnion([currentUserId]),
      });

      // Crea suscripción
      await _firestore.collection('subscriptions').add({
        ...planDoc.data()!,
        'userId': currentUserId,
        'subscriptionDate': FieldValue.serverTimestamp(),
      });

      // Notifica al creador
      await _firestore.collection('notifications').add({
        'type': 'join_accepted',
        'receiverId': creatorId,
        'senderId': currentUserId,
        'planId': planId,
        'planName': planType,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aceptar invitación: $e')),
      );
    }
  }

  //-----------------------------------------------------------------------
  // Rechazar invitación
  //-----------------------------------------------------------------------
  Future<void> _handleRejectInvitation(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final planId = data['planId'] as String;
      final creatorId = data['senderId'] as String;
      final planType = data['planType'] ?? data['planName'] ?? 'Plan';

      // Elimina la notificación
      await doc.reference.delete();

      // Notifica al creador
      final inviteeDoc = await _firestore.collection('users')
          .doc(widget.currentUserId).get();
      final inviteePhoto = inviteeDoc.exists
          ? (inviteeDoc.data()!['photoUrl'] ?? '')
          : '';
      final inviteeName = inviteeDoc.exists
          ? (inviteeDoc.data()!['name'] ?? '')
          : '';

      await _firestore.collection('notifications').add({
        'type': 'join_rejected',
        'receiverId': creatorId,
        'senderId': widget.currentUserId,
        'planId': planId,
        'planName': planType,
        'senderProfilePic': inviteePhoto,
        'senderName': inviteeName,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar invitación: $e')),
      );
    }
  }

  //-----------------------------------------------------------------------
  // Eliminar notificación
  //-----------------------------------------------------------------------
  Future<void> _handleDeleteNotification(DocumentSnapshot doc) async {
    await doc.reference.delete();
  }

  //-----------------------------------------------------------------------
  // Aceptar solicitud de seguimiento (follow_request)
  //-----------------------------------------------------------------------
  Future<void> _handleAcceptFollowRequest(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId'] as String;
      final receiverId = data['receiverId'] as String;

      // Elimina la notificación de follow_request
      await doc.reference.delete();

      // Actualiza las colecciones 'followers' y 'followed'
      await _firestore.collection('followers').add({
        'userId': receiverId,
        'followerId': senderId,
      });
      await _firestore.collection('followed').add({
        'userId': senderId,
        'followedId': receiverId,
      });

      // Notifica al sender que ha sido aceptado
      final acceptorDoc = await _firestore.collection('users')
          .doc(receiverId).get();
      final acceptorPhoto = acceptorDoc.exists
          ? (acceptorDoc.data()!['photoUrl'] ?? '')
          : '';
      final acceptorName = acceptorDoc.exists
          ? (acceptorDoc.data()!['name'] ?? '')
          : '';

      await _firestore.collection('notifications').add({
        'type': 'follow_accepted',
        'receiverId': senderId,
        'senderId': receiverId,
        'senderProfilePic': acceptorPhoto,
        'senderName': acceptorName,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aceptar solicitud de follow: $e')),
      );
    }
  }

  //-----------------------------------------------------------------------
  // Rechazar solicitud de seguimiento
  //-----------------------------------------------------------------------
  Future<void> _handleRejectFollowRequest(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId'] as String;
      final receiverId = data['receiverId'] as String;

      // Elimina la notificación de follow_request
      await doc.reference.delete();

      // Notifica al que pidió follow que fue rechazado
      final rejectorDoc = await _firestore.collection('users')
          .doc(receiverId).get();
      final rejectorPhoto = rejectorDoc.exists
          ? (rejectorDoc.data()!['photoUrl'] ?? '')
          : '';
      final rejectorName = rejectorDoc.exists
          ? (rejectorDoc.data()!['name'] ?? '')
          : '';

      await _firestore.collection('notifications').add({
        'type': 'follow_rejected',
        'receiverId': senderId,
        'senderId': receiverId,
        'senderProfilePic': rejectorPhoto,
        'senderName': rejectorName,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar solicitud de follow: $e')),
      );
    }
  }

  //-----------------------------------------------------------------------
  // Al pulsar una notificación, abrimos la PlanCard con UI coherente
  //-----------------------------------------------------------------------
  Future<void> _showPlanDetails(BuildContext context, String planId) async {
    final planDoc = await _firestore.collection('plans').doc(planId).get();
    if (!planDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El plan ya no existe.')),
      );
      return;
    }
    final planData = planDoc.data() as Map<String, dynamic>;
    final plan = PlanModel.fromMap(planData);

    // Obtenemos el "userData" del creador, para pasárselo a PlanCard
    final creatorDoc = await _firestore.collection('users')
        .doc(plan.createdBy).get();
    final Map<String, dynamic> creatorData = creatorDoc.exists
        ? creatorDoc.data() as Map<String, dynamic>
        : {};

    // Navegar a una pantalla con PlanCard
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const ui.Color.fromARGB(255, 255, 255, 255),
          appBar: AppBar(
            title: const Text("Detalle del Plan"),
            backgroundColor: const ui.Color.fromARGB(221, 255, 255, 255),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                PlanCard(
                  plan: plan,
                  userData: creatorData,
                  fetchParticipants: fetchPlanParticipants,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //-----------------------------------------------------------------------
  // BUILD principal
  //-----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text("Debes iniciar sesión para ver notificaciones"),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título y botón atrás
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Notificaciones",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _getAllNotifications(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _buildErrorWidget();
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoading();
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return _buildEmpty("No tienes notificaciones nuevas");
                      }

                      // Ordenar manualmente por timestamp descendente
                      docs.sort((a, b) {
                        final dataA = a.data() as Map<String, dynamic>;
                        final dataB = b.data() as Map<String, dynamic>;
                        final Timestamp tA =
                            dataA['timestamp'] as Timestamp? ?? Timestamp(0, 0);
                        final Timestamp tB =
                            dataB['timestamp'] as Timestamp? ?? Timestamp(0, 0);
                        return tB.compareTo(tA);
                      });

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final planType =
                              data['planType'] ?? data['planName'] ?? 'Plan';
                          final planId = data['planId'] ?? '';
                          final senderId = data['senderId'] ?? '';
                          final senderPhoto = data['senderProfilePic'] ?? '';
                          final senderName = data['senderName'] ?? '';
                          final type = data['type'] as String? ?? '';
                          final timestamp = data['timestamp'];
                          final timeString = _formatTimestamp(timestamp);

                          // Subtítulo con la hora
                          Widget buildSubtitle(String primaryText) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  primaryText,
                                  style:
                                      const TextStyle(color: AppColors.blue),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeString,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            );
                          }

                          // Botones [✗] y [✓]
                          Widget acceptRejectButtons({
                            required VoidCallback onAccept,
                            required VoidCallback onReject,
                          }) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  onPressed: onReject,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check,
                                      color: Colors.green),
                                  onPressed: onAccept,
                                ),
                              ],
                            );
                          }

                          // Avatar del sender
                          Widget leadingAvatar = GestureDetector(
                            onTap: () {
                              // Ir al perfil del sender
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      UserInfoCheck(userId: senderId),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              radius: 25,
                              backgroundImage: senderPhoto.isNotEmpty
                                  ? NetworkImage(senderPhoto)
                                  : const NetworkImage(
                                      'https://cdn-icons-png.flaticon.com/512/847/847969.png',
                                    ),
                            ),
                          );

                          // Tipo de notificación
                          switch (type) {
                            case 'join_request':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  "¡$senderName se quiere unir a un plan tuyo!",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: acceptRejectButtons(
                                  onAccept: () =>
                                      _handleAcceptJoinRequest(doc),
                                  onReject: () =>
                                      _handleRejectJoinRequest(doc),
                                ),
                              );
                            case 'join_accepted':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  "¡$senderName ha aceptado que te unas a su plan!",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _handleDeleteNotification(doc),
                                ),
                              );
                            case 'join_rejected':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  "¡$senderName ha rechazado tu solicitud para unirte!",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _handleDeleteNotification(doc),
                                ),
                              );
                            case 'invitation':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  "$senderName te ha invitado a un plan especial de $planType",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: acceptRejectButtons(
                                  onAccept: () =>
                                      _handleAcceptInvitation(doc),
                                  onReject: () =>
                                      _handleRejectInvitation(doc),
                                ),
                              );
                            case 'follow_request':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  "¡$senderName quiere seguirte!",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: buildSubtitle("Solicitud de Follow"),
                                onTap: () {
                                  // Ir al perfil del sender
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          UserInfoCheck(userId: senderId),
                                    ),
                                  );
                                },
                                trailing: acceptRejectButtons(
                                  onAccept: () =>
                                      _handleAcceptFollowRequest(doc),
                                  onReject: () =>
                                      _handleRejectFollowRequest(doc),
                                ),
                              );
                            case 'follow_accepted':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  "¡$senderName ha aceptado tu solicitud de seguimiento!",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: buildSubtitle(
                                    "Ahora puedes ver su perfil"),
                                onTap: () {
                                  // Ir al perfil de quien te aceptó
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          UserInfoCheck(userId: senderId),
                                    ),
                                  );
                                },
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _handleDeleteNotification(doc),
                                ),
                              );
                            case 'follow_rejected':
                              return ListTile(
                                leading: leadingAvatar,
                                title: Text(
                                  "¡$senderName ha rechazado tu solicitud de seguimiento!",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle:
                                    buildSubtitle("Perfil privado"),
                                onTap: () {
                                  // Ir al perfil de quien te rechazó
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          UserInfoCheck(userId: senderId),
                                    ),
                                  );
                                },
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _handleDeleteNotification(doc),
                                ),
                              );
                            default:
                              return const SizedBox();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  //-----------------------------------------------------------------------
  // Widgets auxiliares
  //-----------------------------------------------------------------------
  Widget _buildLoading() => const Center(
        child: CircularProgressIndicator(color: Colors.blue, strokeWidth: 2.5),
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
