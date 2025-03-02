import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/plan_model.dart';
import '../main/colors.dart';

class NotificationScreen extends StatefulWidget {
  final String currentUserId;
  const NotificationScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Trae todas las notificaciones (join_request, invitation, join_accepted, join_rejected)
  /// (Sin orderBy para evitar error si algún documento carece de "timestamp")
  Stream<QuerySnapshot> _getAllNotifications() {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: widget.currentUserId)
        .where('type', whereIn: [
          'join_request',
          'invitation',
          'join_accepted',
          'join_rejected',
        ])
        .snapshots();
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime dateTime = (timestamp as Timestamp).toDate();
    return DateFormat('HH:mm').format(dateTime);
  }

  /// Aceptar join request
  Future<void> _handleAcceptJoinRequest(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final planId = data['planId'] as String;
      final senderId = data['senderId'] as String;
      final planType = data['planType'] ?? data['planName'] ?? 'Plan';

      // Elimina la notificación original
      await doc.reference.delete();

      // Agrega el sender a la lista de participantes del plan
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

      // Notifica al sender que ha sido aceptado
      final acceptorDoc = await _firestore.collection('users').doc(widget.currentUserId).get();
      String acceptorPhoto = acceptorDoc.exists ? (acceptorDoc.data()!['photoUrl'] ?? '') : '';

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

  /// Rechazar join request
  Future<void> _handleRejectJoinRequest(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final planId = data['planId'] as String;
      final senderId = data['senderId'] as String;
      final planType = data['planType'] ?? data['planName'] ?? 'Plan';

      // Elimina la notificación de join_request
      await doc.reference.delete();

      // Notifica al que pidió unirse que fue rechazado
      final rejectorDoc = await _firestore.collection('users').doc(widget.currentUserId).get();
      String rejectorPhoto = rejectorDoc.exists ? (rejectorDoc.data()!['photoUrl'] ?? '') : '';

      await _firestore.collection('notifications').add({
        'type': 'join_rejected',
        'receiverId': senderId,
        'senderId': widget.currentUserId,
        'planId': planId,
        'planName': planType,
        'senderProfilePic': rejectorPhoto,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar solicitud: $e')),
      );
    }
  }

  /// Aceptar invitación (invitation)
  Future<void> _handleAcceptInvitation(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final planId = data['planId'] as String;
      final creatorId = data['senderId'] as String;
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final planType = data['planType'] ?? data['planName'] ?? 'Plan';

      // Borra la notificación
      await doc.reference.delete();

      // Añade al usuario actual a participants
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

  /// Rechazar invitación
  Future<void> _handleRejectInvitation(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final planId = data['planId'] as String;
      final creatorId = data['senderId'] as String;
      final planType = data['planType'] ?? data['planName'] ?? 'Plan';

      // Elimina la notificación original
      await doc.reference.delete();

      // Notifica al creador de que fue rechazado
      final inviteeDoc = await _firestore.collection('users').doc(widget.currentUserId).get();
      String inviteePhoto = inviteeDoc.exists ? (inviteeDoc.data()!['photoUrl'] ?? '') : '';

      await _firestore.collection('notifications').add({
        'type': 'join_rejected',
        'receiverId': creatorId,
        'senderId': widget.currentUserId,
        'planId': planId,
        'planName': planType,
        'senderProfilePic': inviteePhoto,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar invitación: $e')),
      );
    }
  }

  /// Eliminar una notificación (join_accepted o join_rejected)
  Future<void> _handleDeleteNotification(DocumentSnapshot doc) async {
    await doc.reference.delete();
  }

  /// Ver detalles del plan
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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.15,
            left: 20,
            right: 20,
            bottom: 20,
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Detalles del Plan: ${plan.type}",
            style: const TextStyle(color: Colors.black),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child: SingleChildScrollView(child: _buildPlanDetailsContent(plan)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cerrar", style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlanDetailsContent(PlanModel plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "ID del Plan: ${plan.id}",
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.blue),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: plan.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ID copiado al portapapeles')),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text("Descripción: ${plan.description}", style: const TextStyle(color: Colors.black)),
        const SizedBox(height: 10),
        _buildBackgroundImage(plan),
        _buildReadOnlyLocationMap(plan),
        const SizedBox(height: 10),
        Text(
          "Fecha del Evento: ${plan.formattedDate(plan.date)}",
          style: const TextStyle(color: Colors.black),
        ),
        Text(
          "Creado el: ${plan.formattedDate(plan.createdAt)}",
          style: const TextStyle(color: Colors.black),
        ),
        const SizedBox(height: 10),
        _buildVisibilityField(plan),
        const SizedBox(height: 10),
        if (plan.createdBy.isNotEmpty) ...[
          const Text("Creador del Plan:", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('users').doc(plan.createdBy).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
              final creatorData = snapshot.data!.data() as Map<String, dynamic>;
              final photo = creatorData['photoUrl'] ?? '';
              final name = creatorData['name'] ?? 'Usuario';
              final age = creatorData['age']?.toString() ?? '';
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                  backgroundColor: Colors.purple[100],
                ),
                title: Text('$name, $age', style: const TextStyle(color: Colors.black)),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildBackgroundImage(PlanModel plan) {
    if (plan.backgroundImage == null || plan.backgroundImage!.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          plan.backgroundImage!,
          fit: BoxFit.cover,
          height: 200,
          width: double.infinity,
        ),
      ),
    );
  }

  Widget _buildReadOnlyLocationMap(PlanModel plan) {
    if (plan.latitude == null || plan.longitude == null) return const SizedBox();
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        children: [
          SizedBox(
            height: 240,
            width: double.infinity,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(plan.latitude!, plan.longitude!),
                zoom: 16,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('plan_location'),
                  position: LatLng(plan.latitude!, plan.longitude!),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                  anchor: const Offset(0.5, 0.5),
                ),
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              liteModeEnabled: true,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    plan.location,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityField(PlanModel plan) {
    if (plan.visibility == null || plan.visibility!.isEmpty) return const SizedBox();
    return Text(
      "Visibilidad: ${plan.visibility}",
      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Debes iniciar sesión para ver notificaciones"));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Notificaciones",
                style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getAllNotifications(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return _buildErrorWidget();
                  if (snapshot.connectionState == ConnectionState.waiting) return _buildLoading();
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) return _buildEmpty("No tienes notificaciones nuevas");

                  // Ordenamos manualmente los documentos por timestamp descendente
                  docs.sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>;
                    final dataB = b.data() as Map<String, dynamic>;
                    final Timestamp tA = dataA['timestamp'] as Timestamp? ?? Timestamp(0, 0);
                    final Timestamp tB = dataB['timestamp'] as Timestamp? ?? Timestamp(0, 0);
                    return tB.compareTo(tA);
                  });

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final planType = data['planType'] ?? data['planName'] ?? 'Plan';
                      final planId = data['planId'] ?? '';
                      final senderId = data['senderId'] ?? '';
                      final senderPhoto = data['senderProfilePic'] ?? '';
                      final type = data['type'] as String? ?? '';
                      final timestamp = data['timestamp'];
                      final timeString = _formatTimestamp(timestamp);

                      return FutureBuilder<DocumentSnapshot>(
                        future: _firestore.collection('users').doc(senderId).get(),
                        builder: (context, snap) {
                          String userName = "Desconocido";
                          String userPhoto = senderPhoto;
                          if (snap.connectionState == ConnectionState.done && snap.hasData) {
                            final userData = snap.data?.data() as Map<String, dynamic>?;
                            if (userData != null) {
                              userName = userData['name'] ?? 'Desconocido';
                              if (userPhoto.isEmpty) userPhoto = userData['photoUrl'] ?? '';
                            }
                          }

                          Widget buildSubtitle(String primaryText) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  primaryText,
                                  style: const TextStyle(color: AppColors.blue),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeString,
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            );
                          }

                          switch (type) {
                            case 'join_request':
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 25,
                                  backgroundImage: userPhoto.isNotEmpty
                                      ? NetworkImage(userPhoto)
                                      : const NetworkImage('https://cdn-icons-png.flaticon.com/512/847/847969.png'),
                                ),
                                title: Text(
                                  "¡$userName se quiere unir a un plan tuyo!",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () => _handleRejectJoinRequest(doc),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.check, color: Colors.green),
                                      onPressed: () => _handleAcceptJoinRequest(doc),
                                    ),
                                  ],
                                ),
                              );
                            case 'invitation':
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 25,
                                  backgroundImage: userPhoto.isNotEmpty
                                      ? NetworkImage(userPhoto)
                                      : const NetworkImage('https://cdn-icons-png.flaticon.com/512/847/847969.png'),
                                ),
                                title: Text(
                                  "$userName te ha invitado a un plan especial de $planType",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () => _handleRejectInvitation(doc),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.check, color: Colors.green),
                                      onPressed: () => _handleAcceptInvitation(doc),
                                    ),
                                  ],
                                ),
                              );
                            case 'join_accepted':
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 25,
                                  backgroundImage: userPhoto.isNotEmpty
                                      ? NetworkImage(userPhoto)
                                      : const NetworkImage('https://cdn-icons-png.flaticon.com/512/847/847969.png'),
                                ),
                                title: Text(
                                  "¡$userName ha aceptado que te unas a su plan!",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _handleDeleteNotification(doc),
                                ),
                              );
                            case 'join_rejected':
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 25,
                                  backgroundImage: userPhoto.isNotEmpty
                                      ? NetworkImage(userPhoto)
                                      : const NetworkImage('https://cdn-icons-png.flaticon.com/512/847/847969.png'),
                                ),
                                title: Text(
                                  "¡$userName ha rechazado tu solicitud para unirte a su plan!",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: buildSubtitle("Plan: $planType"),
                                onTap: () => _showPlanDetails(context, planId),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _handleDeleteNotification(doc),
                                ),
                              );
                            default:
                              return const SizedBox();
                          }
                        },
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() => const Center(
        child: CircularProgressIndicator(color: Colors.blue, strokeWidth: 2.5),
      );
  Widget _buildErrorWidget() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 40),
            SizedBox(height: 10),
            Text('Error al cargar datos', style: TextStyle(color: Colors.red, fontSize: 16)),
          ],
        ),
      );
  Widget _buildEmpty(String text) => Center(
        child: Text(
          text,
          style: const TextStyle(color: Colors.grey, fontSize: 16, fontStyle: FontStyle.italic),
        ),
      );
}
