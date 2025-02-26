import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/plan_model.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MyPlansScreen extends StatelessWidget {
  const MyPlansScreen({super.key});

  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];

    final planDoc = await FirebaseFirestore.instance.collection('plans').doc(plan.id).get();
    if (planDoc.exists) {
      final planData = planDoc.data();
      final creatorId = planData?['createdBy'];
      if (creatorId != null) {
        final creatorUserDoc = await FirebaseFirestore.instance.collection('users').doc(creatorId).get();
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

    final subsSnap = await FirebaseFirestore.instance.collection('subscriptions').where('id', isEqualTo: plan.id).get();
    for (var sDoc in subsSnap.docs) {
      final sData = sDoc.data();
      final userId = sData['userId'];
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
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

  Widget _buildBackgroundImage(PlanModel plan) {
    if (plan.backgroundImage == null || plan.backgroundImage!.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(plan.backgroundImage!, fit: BoxFit.cover, height: 200, width: double.infinity)),
    );
  }

  Widget _buildReadOnlyLocationMap(PlanModel plan) {
    if (plan.latitude == null || plan.longitude == null) return const SizedBox();
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        children: [
          Container(
            height: 240,
            width: double.infinity,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: LatLng(plan.latitude!, plan.longitude!), zoom: 16),
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
              onMapCreated: (controller) {},
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  padding: const EdgeInsets.all(12),
                  child: Text(plan.location, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
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
    return Text("Visibilidad: ${plan.visibility}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold));
  }

  void _showPlanDetails(BuildContext context, PlanModel plan) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.15, left: 20, right: 20, bottom: 20),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Detalles del Plan: ${plan.type}", style: const TextStyle(color: Colors.black)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text("ID del Plan: ${plan.id}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.blue),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: plan.id));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID copiado al portapapeles')));
                        },
                        tooltip: 'Copiar ID',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text("Descripción: ${plan.description}", style: const TextStyle(color: Colors.black)),
                  Text("Restricción de Edad: ${plan.minAge} - ${plan.maxAge} años", style: const TextStyle(color: Colors.black)),
                  Text("Máximo Participantes: ${plan.maxParticipants ?? 'Sin límite'}", style: const TextStyle(color: Colors.black)),
                  const SizedBox(height: 10),
                  _buildBackgroundImage(plan),
                  _buildReadOnlyLocationMap(plan),
                  const SizedBox(height: 10),
                  Text("Fecha del Evento: ${plan.formattedDate(plan.date)}", style: const TextStyle(color: Colors.black)),
                  Text("Creado el: ${plan.formattedDate(plan.createdAt)}", style: const TextStyle(color: Colors.black)),
                  const SizedBox(height: 10),
                  _buildVisibilityField(plan),
                  const SizedBox(height: 10),
                  if (plan.createdBy.isNotEmpty)
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(plan.createdBy).get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                        final creatorData = snapshot.data!.data() as Map<String, dynamic>;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Creador del Plan:", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ListTile(
                              leading: CircleAvatar(
                                backgroundImage: (creatorData['photoUrl'] as String).isNotEmpty ? NetworkImage(creatorData['photoUrl']) : null,
                                backgroundColor: Colors.purple[100],
                              ),
                              title: Text('${creatorData['name']}, ${creatorData['age']}', style: const TextStyle(color: Colors.black)),
                            ),
                            const SizedBox(height: 10),
                          ],
                        );
                      },
                    ),
                  const Text("Participantes:", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchAllPlanParticipants(plan),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (snapshot.hasError) return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.black));
                      final all = snapshot.data ?? [];
                      final participants = all.where((p) => !p['isCreator']).toList();
                      participants.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
                      return participants.isEmpty
                          ? const Text('No hay participantes en este plan.', style: TextStyle(color: Colors.black))
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
                                  leading: CircleAvatar(backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null, backgroundColor: Colors.purple[100]),
                                  title: Text('$name, $age', style: const TextStyle(color: Colors.black)),
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar", style: TextStyle(color: Colors.blue))),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("¿Eliminar este plan?"),
          content: Text("Esta acción eliminará el plan ${plan.type}."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('plans').doc(plan.id).delete();
                final subs = await FirebaseFirestore.instance.collection('subscriptions').where('id', isEqualTo: plan.id).get();
                for (var doc in subs.docs) await doc.reference.delete();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Plan ${plan.type} eliminado correctamente.')));
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
      return const Center(child: Text('Debes iniciar sesión para ver tus planes.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Planes')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('plans').where('createdBy', isEqualTo: currentUser.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No tienes planes aún.'));

          final plans = snapshot.data!.docs.map((doc) => PlanModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
          return ListView.builder(
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return Card(
                margin: const EdgeInsets.all(8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: ListTile(
                  title: Text(plan.type, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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