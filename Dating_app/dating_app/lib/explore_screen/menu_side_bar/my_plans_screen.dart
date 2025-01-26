import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/plan_model.dart';

class MyPlansScreen extends StatelessWidget {
  const MyPlansScreen({Key? key}) : super(key: key);

  void _showPlanDetails(BuildContext context, PlanModel plan) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Detalles del Plan: ${plan.type}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Descripción: ${plan.description}"),
              Text("Restricción de Edad: ${plan.minAge} - ${plan.maxAge} años"),
              Text("Máximo Participantes: ${plan.maxParticipants ?? 'Sin límite'}"),
              Text("Ubicación: ${plan.location}"),
              Text("Fecha del Evento: ${plan.formattedDate(plan.date)}"),
              Text("Creado el: ${plan.formattedDate(plan.createdAt)}"),
              Text("ID del Plan: ${plan.id}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cerrar"),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeletePlan(BuildContext context, PlanModel plan) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("¿Eliminar este plan?"),
          content: Text("Esta acción eliminará el plan ${plan.type}."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                FirebaseFirestore.instance.collection('plans').doc(plan.id).delete();
                Navigator.pop(context);
              },
              child: const Text("Eliminar"),
            ),
          ],
        );
      },
    );
  }

  @override
  @override
Widget build(BuildContext context) {
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    return const Center(
      child: Text(
        'Debes iniciar sesión para ver tus planes.',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  return Scaffold(
    appBar: AppBar(
      title: const Text('Mis Planes'),
    ),
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('plans')
          .where('createdBy', isEqualTo: currentUser.uid) // Filtra por el creador del plan
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No tienes planes aún.'));
        }

        final plans = snapshot.data!.docs
            .map((doc) => PlanModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        return ListView.builder(
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final plan = plans[index];
            return Card(
              margin: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                title: Text(plan.type, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Fecha del Evento: ${plan.formattedDate(plan.date)}"),
                    Text("Creado el: ${plan.formattedDate(plan.createdAt)}"),
                  ],
                ),
                trailing: FloatingActionButton.small(
                  heroTag: "delete_$index",
                  backgroundColor: Colors.red,
                  onPressed: () => _confirmDeletePlan(context, plan),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onTap: () => _showPlanDetails(context, plan),
              ),
            );
          },
        );
      },
    ),
  );
}
}
