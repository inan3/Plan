import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../users_grid/plan_card.dart';
import '../../models/plan_model.dart';

class PlanMemoriesScreen extends StatelessWidget {
  final PlanModel plan;
  final Future<List<Map<String, dynamic>>> Function(PlanModel plan) fetchParticipants;

  const PlanMemoriesScreen({
    Key? key,
    required this.plan,
    required this.fetchParticipants,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Plan y Memorias"),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SingleChildScrollView(
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(plan.createdBy)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Cargando datos del creador
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
              // Si hay error o el doc no existe, ponemos un fallback
              return Column(
                children: [
                  // PlanCard con datos mínimos
                  PlanCard(
                    plan: plan,
                    userData: {
                      'name': 'Usuario',
                      'handle': '@desconocido',
                      'photoUrl': '',
                    },
                    fetchParticipants: fetchParticipants,
                    hideJoinButton: true,
                  ),
                  const SizedBox(height: 16),
                  _buildMemoriesSection(),
                ],
              );
            }

            // Datos reales del creador
            final creatorData = snapshot.data!.data() as Map<String, dynamic>;
            final name = creatorData['name']?.toString() ?? 'Usuario';
            final handle = creatorData['handle']?.toString() ?? '@usuario';
            final photoUrl = creatorData['photoUrl']?.toString() ?? '';

            return Column(
              children: [
                // PlanCard con creador real, sin botón "Unirse"
                PlanCard(
                  plan: plan,
                  userData: {
                    'name': name,
                    'handle': handle,
                    'photoUrl': photoUrl,
                  },
                  fetchParticipants: fetchParticipants,
                  hideJoinButton: true,
                ),
                const SizedBox(height: 16),
                _buildMemoriesSection(),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Sección con título "Memorias", línea divisoria, texto central y botón
  Widget _buildMemoriesSection() {
    return Column(
      children: [
        // Título "Memorias"
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Memorias",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Línea divisoria
        const SizedBox(height: 8),
        const Divider(thickness: 1),
        const SizedBox(height: 16),

        // Contenedor con el texto
        Container(
          height: 150,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: const Text(
            "Añade fotos y videos para rememorar este plan.",
            style: TextStyle(
              color: Colors.black54,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Botón para añadir fotos/videos
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () {
              // Sin efecto por ahora
            },
            icon: const Icon(Icons.add_a_photo),
            label: const Text("Añadir fotos o videos"),
          ),
        ),
      ],
    );
  }
}
