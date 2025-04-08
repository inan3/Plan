import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/plan_model.dart';

class SubscribedPlansSelection extends StatelessWidget {
  final Set<String> selectedIds;
  final Function(String) onToggleSelected;

  const SubscribedPlansSelection({
    Key? key,
    required this.selectedIds,
    required this.onToggleSelected,
  }) : super(key: key);

  // Método auxiliar para obtener PlanModel a partir de ID
  Future<List<PlanModel>> _fetchPlansFromIds(List<String> planIds) async {
    if (planIds.isEmpty) return [];
    final List<PlanModel> plans = [];
    for (String planId in planIds) {
      final planDoc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(planId)
          .get();
      if (planDoc.exists) {
        final planData = planDoc.data() as Map<String, dynamic>;
        planData['id'] = planDoc.id;
        plans.add(PlanModel.fromMap(planData));
      }
    }
    return plans;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(
        child: Text('Debes iniciar sesión.'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('subscriptions')
          .where('userId', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No tienes planes suscritos aún.',
              style: TextStyle(color: Colors.black),
            ),
          );
        }
        final planIds = snapshot.data!.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['id'] as String? ?? '';
            })
            .where((id) => id.isNotEmpty)
            .toList();

        return FutureBuilder<List<PlanModel>>(
          future: _fetchPlansFromIds(planIds),
          builder: (context, planSnapshot) {
            if (!planSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final plans = planSnapshot.data!;
            if (plans.isEmpty) {
              return const Center(
                child: Text(
                  'No tienes planes suscritos aún.',
                  style: TextStyle(color: Colors.black),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                final bool isSelected = selectedIds.contains(plan.id);

                return GestureDetector(
                  onTap: () {
                    onToggleSelected(plan.id!);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: plan.special_plan == 1
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(
                          plan.special_plan == 1 ? 60 : 20),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        if (isSelected)
                          const BoxShadow(
                            color: Colors.blueAccent,
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.type,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: Colors.blue),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
