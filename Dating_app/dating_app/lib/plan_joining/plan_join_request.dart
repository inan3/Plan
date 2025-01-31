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
      // Paso 1: Obtener datos del plan
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

      final planData = planDoc.data() as Map<String, dynamic>;
      final creatorId = planData['createdBy'] as String? ?? '';
      final planName = planData['type'] as String? ?? 'Plan';

      // Paso 2: Verificar si el usuario es el creador del plan
      if (creatorId == currentUser.uid) {
        _showCreatorDialog(context);
        return;
      }

      // Paso 3: Obtener datos del usuario solicitante
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil de usuario no existe')),
        );
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] as String? ?? 'Usuario';
      final userPhoto = userData['photoUrl'] as String? ?? '';

      // Paso 4: Crear notificación para el creador del plan
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'join_request',
        'receiverId': creatorId,
        'senderId': currentUser.uid,
        'planId': planId,
        'planName': planName,
        'requesterName': userName,
        'requesterProfilePic': userPhoto,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada con éxito')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error crítico: ${e.toString()}')),
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
}
