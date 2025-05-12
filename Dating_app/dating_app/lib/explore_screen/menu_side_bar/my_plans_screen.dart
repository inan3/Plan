// my_plans_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../models/plan_model.dart';
import '../../main/colors.dart';
import '../../utils/plans_list.dart' as plansData;
import '../../plan_creation/new_plan_creation_screen.dart';
import '../plans_managing/plan_card.dart';
import '../plans_managing/frosted_plan_dialog_state.dart' as new_frosted;

class MyPlansScreen extends StatelessWidget {
  const MyPlansScreen({Key? key}) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(
    PlanModel plan,
  ) async {
    final doc = await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .get();
    final List<Map<String, dynamic>> participants = [];
    if (!doc.exists || doc.data() == null) return participants;

    final data = doc.data()!;
    final participantUids = List<String>.from(data['participants'] ?? []);
    for (String uid in participantUids) {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final uData = userDoc.data()!;
        participants.add({
          'uid': uid,
          'name': uData['name'] ?? 'Sin nombre',
          'age': uData['age']?.toString() ?? '',
          'photoUrl': uData['photoUrl'] ?? uData['profilePic'] ?? '',
          'isCreator': (plan.createdBy == uid),
        });
      }
    }
    return participants;
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

    // ListView con shrinkWrap para que se ajuste al espacio del Dialog
    return Container(
      color: Colors.transparent,
      child: StreamBuilder<QuerySnapshot>(
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
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final plans = snapshot.data!.docs.map((doc) {
            final pData = doc.data() as Map<String, dynamic>;
            pData['id'] = doc.id;
            return PlanModel.fromMap(pData);
          }).toList();

          return ListView.builder(
            shrinkWrap: true,
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return _buildPlanTile(context, plan);
            },
          );
        },
      ),
    );
  }

  Widget _buildPlanTile(BuildContext context, PlanModel plan) {
    if (plan.special_plan == 1) {
      // Plan especial
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchAllPlanParticipants(plan),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSpecialPlanLoading();
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar participantes: ${snapshot.error}'),
            );
          }
          final participants = snapshot.data ?? [];

          String iconPath = plan.iconAsset ?? '';
          for (var item in plansData.plans) {
            if (plan.iconAsset == item['icon']) {
              iconPath = item['icon'];
              break;
            }
          }

          final creatorAvatar = participants.isNotEmpty &&
                  (participants[0]['photoUrl'] ?? '').isNotEmpty
              ? CircleAvatar(
                  backgroundImage: NetworkImage(participants[0]['photoUrl']),
                  radius: 20,
                )
              : const CircleAvatar(radius: 20);

          final participantAvatar = (participants.length > 1 &&
                  (participants[1]['photoUrl'] ?? '').isNotEmpty)
              ? CircleAvatar(
                  backgroundImage: NetworkImage(participants[1]['photoUrl']),
                  radius: 20,
                )
              : const SizedBox();

          return GestureDetector(
            onTap: () => _openFrostedPlanDialog(context, plan),
            child: Center(
              child: Container(
                width: double.infinity,
                height: 80,
                margin: const EdgeInsets.only(
                  bottom: 15,
                  left: 8,
                  right: 8,
                ),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(color: Colors.blueAccent, width: 2),
                ),
                child: Row(
                  children: [
                    Row(
                      children: [
                        if (iconPath.isNotEmpty)
                          SvgPicture.asset(
                            iconPath,
                            width: 40,
                            height: 40,
                            color: Colors.amber,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          plan.type,
                          style:
                              const TextStyle(fontSize: 20, color: Colors.white),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        creatorAvatar,
                        const SizedBox(width: 8),
                        participantAvatar,
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } else {
      // Plan normal
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 330,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            final fallbackData = {
              'name': 'Tú',
              'handle': '@creador',
              'photoUrl': '',
            };
            return _buildMyPlanCard(context, plan, fallbackData);
          }
          final data = snap.data!.data() as Map<String, dynamic>;
          final userData = {
            'name': data['name'] ?? 'Tú',
            'handle': data['handle'] ?? '@creador',
            'photoUrl': data['photoUrl'] ?? '',
          };
          return _buildMyPlanCard(context, plan, userData);
        },
      );
    }
  }

  Widget _buildMyPlanCard(
    BuildContext context,
    PlanModel plan,
    Map<String, dynamic> userData,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PlanCard(
          plan: plan,
          userData: userData,
          fetchParticipants: _fetchAllPlanParticipants,
          hideJoinButton: true,
        ),
        Positioned(
          top: 14,
          right: 14,
          child: GestureDetector(
            onTap: () => _confirmDeletePlan(context, plan),
            child: ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 14,
          right: 60,
          child: GestureDetector(
            onTap: () => _openEditPlanPopup(context, plan),
            child: ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDeletePlan(BuildContext context, PlanModel plan) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("¿Eliminar este plan?"),
          content: Text(
            "Esta acción eliminará el plan ${plan.type} de forma permanente.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('plans')
                    .doc(plan.id)
                    .delete();
                final subs = await FirebaseFirestore.instance
                    .collection('subscriptions')
                    .where('id', isEqualTo: plan.id)
                    .get();
                for (var doc in subs.docs) {
                  await doc.reference.delete();
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Plan ${plan.type} eliminado.')),
                );
              },
              child: const Text("Eliminar"),
            ),
          ],
        );
      },
    );
  }

  void _openEditPlanPopup(BuildContext context, PlanModel plan) {
    NewPlanCreationScreen.showPopup(
      context,
      planToEdit: plan,
      isEditMode: true,
    );
  }

  void _openFrostedPlanDialog(BuildContext context, PlanModel plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.transparent,
          body: new_frosted.FrostedPlanDialog(
            plan: plan,
            fetchParticipants: _fetchAllPlanParticipants,
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialPlanLoading() {
    return Center(
      child: Container(
        width: 300,
        height: 100,
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blueAccent, width: 2),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
