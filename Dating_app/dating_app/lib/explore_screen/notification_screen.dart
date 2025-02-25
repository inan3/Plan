import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/plan_model.dart';
import 'package:flutter/services.dart'; // Para Clipboard
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NotificationScreen extends StatefulWidget {
  final String currentUserId;
  const NotificationScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Unifica la lectura de notificaciones: join_request, join_accepted, join_rejected
  Stream<QuerySnapshot> _getAllNotifications() {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: widget.currentUserId)
        .where('type', whereIn: ['join_request', 'join_accepted', 'join_rejected'])
        .snapshots();
  }

  /// Maneja la aceptación de la invitación
  Future<void> _handleAccept(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final planId = data['planId'] as String;
      final senderId = data['senderId'] as String;

      // 1) Elimina la notificación original (join_request)
      await doc.reference.delete();

      // 2) Agrega al invitado en 'participants' del plan
      final planRef = _firestore.collection('plans').doc(planId);
      final planDoc = await planRef.get();
      if (!planDoc.exists) return;

      await planRef.update({
        'participants': FieldValue.arrayUnion([senderId]),
      });

      // 3) (Opcional) Crea un registro en 'subscriptions'
      await _firestore.collection('subscriptions').add({
        ...planDoc.data()!,
        'userId': senderId,
        'subscriptionDate': FieldValue.serverTimestamp(),
      });

      // 4) Obtener la foto de perfil del usuario actual (quien acepta)
      final acceptorDoc = await _firestore.collection('users').doc(widget.currentUserId).get();
      String acceptorPhoto = '';
      if (acceptorDoc.exists) {
        final creatorData = acceptorDoc.data() as Map<String, dynamic>;
        acceptorPhoto = creatorData['photoUrl'] as String? ?? '';
      }

      // 5) Crear notificación de 'join_accepted'
      await _firestore.collection('notifications').add({
        'type': 'join_accepted',
        'receiverId': senderId,            // El que invitó recibe esta notificación
        'senderId': widget.currentUserId,  // Quien acepta es el actual
        'planId': planId,
        'planName': data['planName'] ?? 'Plan',
        'senderProfilePic': acceptorPhoto,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aceptar: $e')),
      );
    }
  }

  /// Maneja el rechazo de la invitación
  Future<void> _handleReject(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final planId = data['planId'] as String;
      final senderId = data['senderId'] as String;

      // 1) Elimina la notificación original (join_request)
      await doc.reference.delete();

      // 2) Obtener la foto de perfil del usuario actual (quien rechaza)
      final rejectorDoc = await _firestore.collection('users').doc(widget.currentUserId).get();
      String rejectorPhoto = '';
      if (rejectorDoc.exists) {
        final creatorData = rejectorDoc.data() as Map<String, dynamic>;
        rejectorPhoto = creatorData['photoUrl'] as String? ?? '';
      }

      // 3) Crear notificación de 'join_rejected'
      await _firestore.collection('notifications').add({
        'type': 'join_rejected',
        'receiverId': senderId,
        'senderId': widget.currentUserId,
        'planId': planId,
        'planName': data['planName'] ?? 'Plan',
        'senderProfilePic': rejectorPhoto,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar: $e')),
      );
    }
  }

  /// Elimina una notificación (por ejemplo, join_accepted o join_rejected) al pulsar la papelera
  Future<void> _handleDeleteNotification(DocumentSnapshot doc) async {
    await doc.reference.delete();
  }

  /// Al pulsar en la notificación => ver detalles del plan
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Detalles del Plan: ${plan.type}",
            style: const TextStyle(color: Colors.black),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child: SingleChildScrollView(
              child: _buildPlanDetailsContent(plan),
            ),
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

  /// Estructura de detalles (similar a MyPlansScreen)
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
        // Imagen
        _buildBackgroundImage(plan),
        // Ubicación
        _buildReadOnlyLocationMap(plan),
        const SizedBox(height: 10),
        Text("Fecha del Evento: ${plan.formattedDate(plan.date)}",
            style: const TextStyle(color: Colors.black)),
        Text("Creado el: ${plan.formattedDate(plan.createdAt)}",
            style: const TextStyle(color: Colors.black)),
        const SizedBox(height: 10),
        // Visibilidad
        _buildVisibilityField(plan),
        const SizedBox(height: 10),
        // Creador
        if (plan.createdBy.isNotEmpty) ...[
          const Text("Creador del Plan:",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(plan.createdBy).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox();
              }
              final creatorData = snapshot.data!.data() as Map<String, dynamic>;
              final photo = creatorData['photoUrl'] ?? '';
              final name = creatorData['name'] ?? 'Usuario';
              final age = creatorData['age']?.toString() ?? '';
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: (photo.isNotEmpty) ? NetworkImage(photo) : null,
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
    if (plan.latitude == null || plan.longitude == null) {
      return const SizedBox();
    }
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
                )
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
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
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
            // Título "Notificaciones"
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Notificaciones",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
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

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final planName = data['planName'] ?? 'Plan';
                      final planId = data['planId'] ?? '';
                      final senderId = data['senderId'] ?? '';
                      final senderPhoto = data['senderProfilePic'] ?? '';
                      final type = data['type'] as String? ?? '';

                      // 1) Obtenemos nombre/foto del usuario que envía la noti
                      return FutureBuilder<DocumentSnapshot>(
                        future: _firestore.collection('users').doc(senderId).get(),
                        builder: (context, snap) {
                          String userName = "Desconocido";
                          String userPhoto = senderPhoto; // fallback
                          if (snap.connectionState == ConnectionState.done && snap.hasData) {
                            final userData = snap.data?.data() as Map<String, dynamic>?;
                            if (userData != null) {
                              userName = userData['name'] ?? 'Desconocido';
                              if (userPhoto.isEmpty) {
                                userPhoto = userData['photoUrl'] ?? '';
                              }
                            }
                          }

                          // 2) Construimos distinto según el type
                          if (type == 'join_request') {
                            // a) INVITACIÓN: mostrar botones aceptar/rechazar
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 25,
                                backgroundImage: (userPhoto.isNotEmpty)
                                    ? NetworkImage(userPhoto)
                                    : const NetworkImage('https://cdn-icons-png.flaticon.com/512/847/847969.png'),
                                onBackgroundImageError: (_, __) {},
                              ),
                              title: Text(
                                "¡$userName te ha invitado a un plan!",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text("Plan: $planName", style: const TextStyle(color: Colors.black54)),
                              onTap: () => _showPlanDetails(context, planId),
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
                          } else if (type == 'join_accepted') {
                            // b) TE HAN ACEPTADO OTRA PERSONA
                            // => "X-usuario ha aceptado unirse a tu plan"
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 25,
                                backgroundImage: (userPhoto.isNotEmpty)
                                    ? NetworkImage(userPhoto)
                                    : const NetworkImage('https://cdn-icons-png.flaticon.com/512/847/847969.png'),
                              ),
                              title: Text(
                                "$userName ha aceptado unirse a tu plan",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text("Plan: $planName", style: const TextStyle(color: Colors.black54)),
                              onTap: () => _showPlanDetails(context, planId),
                              // Botón de basura para eliminar la notificación
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _handleDeleteNotification(doc),
                              ),
                            );
                          } else if (type == 'join_rejected') {
                            // c) TE HAN RECHAZADO
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 25,
                                backgroundImage: (userPhoto.isNotEmpty)
                                    ? NetworkImage(userPhoto)
                                    : const NetworkImage('https://cdn-icons-png.flaticon.com/512/847/847969.png'),
                              ),
                              title: Text(
                                "$userName ha rechazado tu plan",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text("Plan: $planName", style: const TextStyle(color: Colors.black54)),
                              onTap: () => _showPlanDetails(context, planId),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _handleDeleteNotification(doc),
                              ),
                            );
                          } else {
                            // Notificación desconocida
                            return const SizedBox();
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
