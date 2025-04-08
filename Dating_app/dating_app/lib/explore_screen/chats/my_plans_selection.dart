import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/plan_model.dart';

class MyPlansSelection extends StatelessWidget {
  final Set<String> selectedIds;
  final Function(String) onToggleSelected;

  const MyPlansSelection({
    Key? key,
    required this.selectedIds,
    required this.onToggleSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(
        child: Text('Debes iniciar sesión para ver tus planes.'),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('plans')
          .where('createdBy', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No tienes planes aún.',
              style: TextStyle(color: Colors.black),
            ),
          );
        }

        final plans = snapshot.data!.docs
            .map((doc) => PlanModel.fromMap(
                {...(doc.data() as Map<String, dynamic>), 'id': doc.id}))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final plan = plans[index];
            final bool isSelected = selectedIds.contains(plan.id);

            // Aquí simulas la tarjeta. Puedes hacerlo más parecido a tu MyPlansScreen
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
                    // Solo texto ejemplo
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
  }
}
