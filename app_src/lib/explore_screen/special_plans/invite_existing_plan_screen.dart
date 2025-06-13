import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/plan_model.dart';
import '../plans_managing/plan_card.dart';
import '../../main/colors.dart';

class InviteExistingPlanScreen extends StatefulWidget {
  final List<PlanModel> plans;
  final void Function(PlanModel plan) onPlanSelected;

  const InviteExistingPlanScreen({
    Key? key,
    required this.plans,
    required this.onPlanSelected,
  }) : super(key: key);

  @override
  State<InviteExistingPlanScreen> createState() => _InviteExistingPlanScreenState();
}

class _InviteExistingPlanScreenState extends State<InviteExistingPlanScreen> {
  String? _selectedId;

  Future<Map<String, dynamic>> _fetchCreatorUserData(String creatorUid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(creatorUid).get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      return {
        'name': data['name'] ?? 'Sin nombre',
        'photoUrl': data['photoUrl'] ?? '',
      };
    }
    return {'name': 'Usuario', 'photoUrl': ''};
  }

  Future<List<Map<String, dynamic>>> _fetchPlanParticipants(PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];
    final docPlan = await FirebaseFirestore.instance.collection('plans').doc(plan.id).get();
    if (docPlan.exists && docPlan.data() != null) {
      final data = docPlan.data()!;
      final List<dynamic> partList = data['participants'] ?? [];
      for (var uid in partList) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final uData = userDoc.data()!;
          participants.add({
            'uid': uid,
            'name': uData['name'] ?? 'Usuario',
            'photoUrl': uData['photoUrl'] ?? '',
            'age': uData['age']?.toString() ?? '',
          });
        }
      }
    }
    return participants;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecciona un plan'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: widget.plans.length,
        itemBuilder: (context, index) {
          final plan = widget.plans[index];
          final bool isSelected = _selectedId == plan.id;

          return FutureBuilder<Map<String, dynamic>>(
            future: _fetchCreatorUserData(plan.createdBy),
            builder: (ctx, userSnap) {
              final creatorData = userSnap.data ?? {
                'name': 'Usuario',
                'photoUrl': '',
              };

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                child: Stack(
                  children: [
                    PlanCard(
                      plan: plan,
                      userData: creatorData,
                      fetchParticipants: _fetchPlanParticipants,
                      hideJoinButton: true,
                    ),
                    Positioned(
                      top: 22,
                      right: 8,
                      child: Switch(
                        value: isSelected,
                        activeTrackColor: AppColors.planColor,
                        activeColor: Colors.white,
                        inactiveTrackColor: Colors.grey,
                        inactiveThumbColor: Colors.white,
                        onChanged: (value) async {
                          if (value) {
                            final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                        title: const Text('Invitar a un plan'),
                                        content: const Text('¿Estás seguro de que quieres invitarle a un plan?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Aceptar'),
                                          ),
                                        ],
                                      ));
                            if (confirm == true) {
                              setState(() => _selectedId = plan.id);
                              widget.onPlanSelected(plan);
                            } else {
                              setState(() => _selectedId = null);
                            }
                          } else {
                            setState(() => _selectedId = null);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
