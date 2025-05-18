import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinPlanRequestScreen {
  static void showJoinPlanDialog(BuildContext context) {
    final TextEditingController planIdController = TextEditingController();

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
                controller: planIdController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'ID del Plan',
                  hintText: 'Ejemplo: FxR9XMQ3xP',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final planId = planIdController.text.trim();
                if (planId.isNotEmpty) {
                  _sendJoinRequest(context, planId);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID del plan requerido')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 86, 98, 204),
              ),
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _sendJoinRequest(BuildContext context, String planId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario no autenticado')),
      );
      return;
    }

    try {
      // 1) Verificar que el plan exista
      final planDoc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(planId)
          .get();

      if (!planDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan no encontrado')),
        );
        return;
      }

      // Extraer datos del plan
      final planData = planDoc.data() as Map<String, dynamic>;
      final String creatorId = planData['createdBy'] ?? '';
      final String planName = planData['type'] ?? 'Plan';

      // 2) Verificar si el usuario es el creador
      if (creatorId == currentUser.uid) {
        _showCreatorDialog(context);
        return;
      }

      // 3) (Opcional) Verificar si el usuario ya estaba en el plan (por si acaso)
      final List<dynamic> participants = planData['participants'] ?? [];
      if (participants.contains(currentUser.uid)) {
        _showAlreadySubscribedDialog(context, planName);
        return;
      }

      // 4) (Opcional) Checar límite de participantes
      final int maxParticipants = planData['maxParticipants'] ?? 99999;
      if (participants.length >= maxParticipants) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('El plan "$planName" ya está completo.'),
          ),
        );
        return;
      }

      // NOTA:
      // Aquí *NO* agregamos el uid a 'participants' todavía.
      // Eso se hará solo cuando el creador acepte la solicitud en MatchesScreen.

      // -- Obtenemos datos del solicitante para ponerlos en la notificación --
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data() ?? {};
      final String requesterName = userData['name'] ?? 'Sin nombre';
      final String requesterProfilePic = userData['photoUrl'] ?? '';

      // 5) Crear la notificación "join_request"
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'join_request',
        'receiverId': creatorId,       // A quién se le notifica (creador)
        'senderId': currentUser.uid,   // Quién envía la solicitud
        'planId': planId,
        'planName': planName,
        'requesterName': requesterName,
        'requesterProfilePic': requesterProfilePic,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada al creador')),
      );

      // Cerrar el diálogo
      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error crítico: $e')),
      );
    }
  }

  static void _showCreatorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acción no permitida'),
        content: const Text('¡No puedes unirte a tu propio plan!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  static void _showAlreadySubscribedDialog(BuildContext context, String planName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Plan ya suscrito'),
        content: Text(
          'Ya formas parte del plan "$planName".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
