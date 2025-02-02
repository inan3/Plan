import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/plan_model.dart';
import 'package:flutter/services.dart'; // Importar para Clipboard


class MyPlansScreen extends StatelessWidget {
  const MyPlansScreen({Key? key}) : super(key: key);

  /// Obtiene el creador y todos los suscriptores de un plan
  /// Retorna una lista con Map que tiene {name, age, photoUrl, isCreator}
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];

    // 1) Buscar el planDoc para extraer createdBy
    final planDoc = await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .get();
    if (planDoc.exists) {
      final planData = planDoc.data();
      final creatorId = planData?['createdBy'];
      if (creatorId != null) {
        // 2) Leemos su doc en 'users'
        final creatorUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(creatorId)
            .get();
        if (creatorUserDoc.exists) {
          final cdata = creatorUserDoc.data()!;
          participants.add({
            'name': cdata['name'] ?? 'Sin nombre',
            'age': cdata['age']?.toString() ?? '',
            'photoUrl': cdata['photoUrl'] ?? cdata['profilePic'] ?? '',
            'isCreator': true,
          });
        }
      }
    }

    // 3) Obtener suscripciones
    final subsSnap = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('id', isEqualTo: plan.id)
        .get();
    for (var sDoc in subsSnap.docs) {
      final sData = sDoc.data();
      final userId = sData['userId'];
      // 4) Por cada userId, consultamos 'users/{userId}'
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final uData = userDoc.data()!;
        participants.add({
          'name': uData['name'] ?? 'Sin nombre',
          'age': uData['age']?.toString() ?? '',
          'photoUrl': uData['photoUrl'] ?? uData['profilePic'] ?? '',
          'isCreator': false,
        });
      }
    }

    return participants;
  }

  void _showPlanDetails(BuildContext context, PlanModel plan) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          // Ajusta el padding interno del diálogo para desplazarlo hacia abajo
          insetPadding: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.15, // 15% desde arriba
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
            child: SingleChildScrollView( // Asegurar scroll si el contenido es largo
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mostrar el ID del Plan con botón de copiar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "ID del Plan: ${plan.id}",
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
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
                        tooltip: 'Copiar ID',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text("Descripción: ${plan.description}",
                      style: const TextStyle(color: Colors.black)),
                  Text("Restricción de Edad: ${plan.minAge} - ${plan.maxAge} años",
                      style: const TextStyle(color: Colors.black)),
                  Text("Máximo Participantes: ${plan.maxParticipants ?? 'Sin límite'}",
                      style: const TextStyle(color: Colors.black)),
                  Text("Ubicación: ${plan.location}",
                      style: const TextStyle(color: Colors.black)),
                  Text("Fecha del Evento: ${plan.formattedDate(plan.date)}",
                      style: const TextStyle(color: Colors.black)),
                  Text("Creado el: ${plan.formattedDate(plan.createdAt)}",
                      style: const TextStyle(color: Colors.black)),
                  const SizedBox(height: 10),

                  // Creador del plan
                  if (plan.createdBy.isNotEmpty)
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
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Creador del Plan:",
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ListTile(
                              leading: CircleAvatar(
                                backgroundImage: (creatorData['photoUrl'] as String).isNotEmpty
                                    ? NetworkImage(creatorData['photoUrl'])
                                    : null,
                                backgroundColor: Colors.purple[100],
                              ),
                              title: Text(
                                '${creatorData['name']}, ${creatorData['age']}',
                                style: const TextStyle(color: Colors.black),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        );
                      },
                    ),

                  // Participantes
                  const Text("Participantes:",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // Mostrar el ID de plan como parte de los detalles
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchAllPlanParticipants(plan),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.black),
                        );
                      }

                      final all = snapshot.data ?? [];

                      // 1) Creador
                      final creator = all.firstWhere(
                        (p) => p['isCreator'] == true,
                        orElse: () => {},
                      );

                      // 2) Participantes (excluyendo creador)
                      final participants = all.where((p) => p['isCreator'] == false).toList();
                      // Orden alfabético por 'name'
                      participants.sort((a, b) {
                        final nameA = (a['name'] ?? '') as String;
                        final nameB = (b['name'] ?? '') as String;
                        return nameA.compareTo(nameB);
                      });

                      return participants.isEmpty
                          ? const Text(
                              'No hay participantes en este plan.',
                              style: TextStyle(color: Colors.black),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: participants.length,
                              itemBuilder: (context, index) {
                                final part = participants[index];
                                final pic = part['photoUrl'] ?? '';
                                final name = part['name'] ?? 'Usuario';
                                final age = part['age'] ?? '';

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: pic.isNotEmpty
                                        ? NetworkImage(pic)
                                        : null,
                                    backgroundColor: Colors.purple[100],
                                  ),
                                  title: Text(
                                    '$name, $age',
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                );
                              },
                            );
                    },
                  ),
                ],
              ),
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
              onPressed: () async {
                // Elimina el plan
                await FirebaseFirestore.instance
                    .collection('plans')
                    .doc(plan.id)
                    .delete();

                // Elimina sus suscripciones asociadas
                final subs = await FirebaseFirestore.instance
                    .collection('subscriptions')
                    .where('id', isEqualTo: plan.id)
                    .get();
                for (var doc in subs.docs) {
                  await doc.reference.delete();
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Plan ${plan.type} eliminado correctamente.')),
                );
              },
              child: const Text("Eliminar"),
            ),
          ],
        );
      },
    );
  }

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
            .where('createdBy', isEqualTo: currentUser.uid)
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
                  title: Text(
                    plan.type,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Fecha del Evento: ${plan.formattedDate(plan.date)}"),
                      Text("Creado el: ${plan.formattedDate(plan.createdAt)}"),
                      Text("ID del Plan: ${plan.id}", style: TextStyle(fontSize: 12, color: Colors.grey[700])),
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
