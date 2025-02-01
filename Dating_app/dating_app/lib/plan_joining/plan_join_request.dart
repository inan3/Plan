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
                final planId = _planIdController.text.trim();
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

      // 3) Construir un ID único para la suscripción
      //    Documento en la colección "subscriptions" => "planId_userId"
      final String subscriptionDocId = '${planId}_${currentUser.uid}';

      // 4) Verificar si ya existe ese documento (lo que indicaría suscripción previa)
      final subscriptionRef = FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(subscriptionDocId);

      final subscriptionDoc = await subscriptionRef.get();

      if (subscriptionDoc.exists) {
        // Si el documento ya existe, significa que el usuario YA está suscrito
        _showAlreadySubscribedDialog(context, planName);
        return;
      }

      // 5) Crear la suscripción o solicitud en la colección "subscriptions"
      //    (ajusta los campos según tu modelo de datos)
      await subscriptionRef.set({
        'planId': planId,
        'userId': currentUser.uid,
        'planName': planName,
        'createdBy': creatorId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 6) (Opcional) Crear también la notificación para el creador del plan
      //    si deseas que se entere de que alguien se quiere unir
      //    OJO: Si tu flujo maneja "solicitud" vs. "aprobación", quizás quieras
      //    guardar el "estado" de la solicitud (pending/approved/rejected).
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'join_request',
        'receiverId': creatorId,
        'senderId': currentUser.uid,
        'planId': planId,
        'planName': planName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada con éxito')),
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
          'Ya formas parte del plan $planName. '
          'Echa un vistazo a tus Planes Suscritos.',
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
