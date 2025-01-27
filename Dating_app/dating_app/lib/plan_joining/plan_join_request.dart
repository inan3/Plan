import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinPlanRequestScreen {
  static void showJoinPlanDialog(BuildContext context) {
    final TextEditingController _planIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Unirse a un plan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Introduce el ID del plan:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _planIdController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'ID del Plan',
                  hintText: 'Ejemplo: 12345',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final planId = _planIdController.text.trim();
                if (planId.isNotEmpty) {
                  _sendJoinRequest(context, planId);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El ID del plan no puede estar vacío.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 86, 98, 204),
              ),
              child: const Text('Enviar Solicitud'),
            ),
          ],
        );
      },
    );
  }

  static void _sendJoinRequest(BuildContext context, String planId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para unirte a un plan.')),
      );
      return;
    }

    try {
      // Obtenemos el documento del plan
      final planDoc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(planId)
          .get();

      if (!planDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El plan no existe.')),
        );
        return;
      }

      final planData = planDoc.data();
      final String creatorId = planData?['createdBy'] ?? '';
      // Supongamos que el campo "type" describe el plan (ej: 'Viaje a la playa')
      final String planName = planData?['type'] ?? 'Plan sin nombre';

      if (creatorId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El creador del plan no se encontró.')),
        );
        return;
      }

      // Enviamos la solicitud a la subcolección 'joinRequests' (opcional, si quieres llevar un control)
      await FirebaseFirestore.instance
          .collection('plans')
          .doc(planId)
          .collection('joinRequests')
          .add({
        'userId': currentUser.uid,
        'userName': currentUser.displayName ?? 'Usuario desconocido',
        'userProfilePic': currentUser.photoURL ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Creamos una notificación para el creador del plan
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'join_request',
        'receiverId': creatorId,               // B (el creador)
        'senderId': currentUser.uid,           // A (quien solicita)
        'planId': planId,
        'planName': planName,                  // Para mostrar info del plan en la notificación
        'requesterName': currentUser.displayName ?? 'Usuario desconocido',
        'requesterProfilePic': currentUser.photoURL ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada exitosamente.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar la solicitud: $e')),
      );
    }
  }
}
