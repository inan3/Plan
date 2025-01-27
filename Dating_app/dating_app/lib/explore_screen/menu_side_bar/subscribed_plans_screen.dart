import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/plan_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscribedPlansScreen extends StatelessWidget {
  final String userId; // ID del usuario para filtrar sus planes suscritos

  const SubscribedPlansScreen({Key? key, required this.userId}) : super(key: key);

  /// Combina al creador + suscriptores de un plan
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];

    // 1) planDoc para saber createdBy
    final planDoc = await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .get();
    if (planDoc.exists) {
      final planData = planDoc.data();
      final creatorId = planData?['createdBy'];
      if (creatorId != null) {
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

    // 2) suscripciones
    final subsSnap = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('id', isEqualTo: plan.id)
        .get();
    for (var sDoc in subsSnap.docs) {
      final sData = sDoc.data();
      final uid = sData['userId'];
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
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
            child: Container(
              color: Colors.white,
              child: FutureBuilder<List<Map<String, dynamic>>>(
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

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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

                        // Creador
                        if (creator is Map && creator.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Creador del Plan:",
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: (creator['photoUrl'] as String).isNotEmpty
                                      ? NetworkImage(creator['photoUrl'])
                                      : null,
                                  backgroundColor: Colors.purple[100],
                                ),
                                title: Text(
                                  '${creator['name']}, ${creator['age']}',
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),

                        // Participantes
                        const Text("Participantes:",
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),

                        if (participants.isEmpty)
                          const Text(
                            'No hay participantes en este plan.',
                            style: TextStyle(color: Colors.black),
                          )
                        else
                          ListView.builder(
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
                          ),
                      ],
                    ),
                  );
                },
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

  void _confirmLeavePlan(BuildContext context, PlanModel plan) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("¿Salir del plan?"),
          content: Text("¿Estás seguro de que deseas salir del plan ${plan.type}?"),
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
                await FirebaseFirestore.instance
                    .collection('subscriptions')
                    .where('userId', isEqualTo: userId)
                    .where('id', isEqualTo: plan.id)
                    .get()
                    .then((querySnapshot) {
                  for (var doc in querySnapshot.docs) {
                    doc.reference.delete();
                  }
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Te has salido del plan ${plan.type}')),
                );
              },
              child: const Text("Salir del Plan"),
            ),
          ],
        );
      },
    );
  }

  void _viewUserProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planes Suscritos'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('subscriptions')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No tienes planes suscritos aún.'));
          }

          final subscribedPlans = snapshot.data!.docs
              .map((doc) => PlanModel.fromMap(doc.data() as Map<String, dynamic>))
              .toList();

          return ListView.builder(
            itemCount: subscribedPlans.length,
            itemBuilder: (context, index) {
              final plan = subscribedPlans[index];
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
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.exit_to_app, color: Colors.red),
                    onPressed: () => _confirmLeavePlan(context, plan),
                    tooltip: 'Salir del Plan',
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

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Usuario'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No se encontró información del usuario.'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;

          return Column(
            children: [
              Expanded(
                child: Image.network(
                  userData['photoUrl'] ?? userData['profilePic'] ?? 'https://via.placeholder.com/150',
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${userData['name']}, ${userData['age']}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Email: ${userData['email'] ?? 'Desconocido'}'),
                    const SizedBox(height: 8),
                    Text('Descripción: ${userData['description'] ?? 'Sin descripción'}'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          );
        },
      ),
    );
  }
}
