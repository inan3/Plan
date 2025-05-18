// subscribed_plans_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/plan_model.dart';
import '../../main/colors.dart';
import '../../utils/plans_list.dart' as plansData;
import '../plans_managing/frosted_plan_dialog_state.dart' as new_frosted;
import '../plans_managing/plan_card.dart';

class SubscribedPlansScreen extends StatelessWidget {
  final String userId;

  const SubscribedPlansScreen({Key? key, required this.userId})
      : super(key: key);

  void _showFrostedPlanDialog(BuildContext context, PlanModel plan) {
    showDialog(
      context: context,
      barrierDismissible: true,
      useSafeArea: false,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: SizedBox(
            width: MediaQuery.of(ctx).size.width,
            height: MediaQuery.of(ctx).size.height,
            child: new_frosted.FrostedPlanDialog(
              plan: plan,
              fetchParticipants: _fetchAllPlanParticipants,
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(
    PlanModel plan,
  ) async {
    final List<Map<String, dynamic>> participants = [];
    final planDoc =
        await FirebaseFirestore.instance.collection('plans').doc(plan.id).get();
    if (!planDoc.exists) return participants;

    final planData = planDoc.data()!;
    final participantUids = List<String>.from(planData['participants'] ?? []);
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

  void _confirmDeletePlan(BuildContext context, PlanModel plan) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("¿Quieres abandonar este plan?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("No"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final subs = await FirebaseFirestore.instance
                    .collection('subscriptions')
                    .where('userId', isEqualTo: userId)
                    .where('id', isEqualTo: plan.id)
                    .get();
                for (var doc in subs.docs) {
                  await doc.reference.delete();
                }
                await FirebaseFirestore.instance
                    .collection('plans')
                    .doc(plan.id)
                    .update({
                  'participants': FieldValue.arrayRemove([userId])
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Has abandonado el plan ${plan.type}.'),
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text("Sí"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlanTile(
    BuildContext context,
    Map<String, dynamic> userData,
    PlanModel plan,
  ) {
    if (plan.special_plan == 1) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchAllPlanParticipants(plan),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
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
          final participants = snapshot.data!;
          final Widget creatorAvatar = participants.isNotEmpty &&
                  (participants[0]['photoUrl'] ?? '').isNotEmpty
              ? CircleAvatar(
                  backgroundImage: NetworkImage(participants[0]['photoUrl']),
                  radius: 20,
                )
              : const CircleAvatar(radius: 20);
          final Widget participantAvatar = (participants.length > 1 &&
                  (participants[1]['photoUrl'] ?? '').isNotEmpty)
              ? CircleAvatar(
                  backgroundImage: NetworkImage(participants[1]['photoUrl']),
                  radius: 20,
                )
              : const SizedBox();

          String iconPath = plan.iconAsset ?? '';
          for (var item in plansData.plans) {
            if (plan.iconAsset == item['icon']) {
              iconPath = item['icon'];
              break;
            }
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showFrostedPlanDialog(context, plan),
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: 80,
                margin: const EdgeInsets.only(bottom: 15),
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
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
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
            right: 12,
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
                    child: const Icon(
                      Icons.exit_to_app,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Igualmente hacemos un ListView con shrinkWrap en caso de uso en Dialog:
    return Container(
      color: Colors.transparent,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('subscriptions')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No tienes planes suscritos aún.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          final planIds = snapshot.data!.docs
              .map((doc) => (doc.data() as Map<String, dynamic>)['id'] as String?)
              .where((id) => id != null && id.isNotEmpty)
              .cast<String>()
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
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(plan.createdBy)
                        .get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SizedBox(
                          height: 330,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (userSnapshot.hasError ||
                          !userSnapshot.hasData ||
                          !userSnapshot.data!.exists) {
                        return const SizedBox(
                          height: 330,
                          child: Center(
                            child: Text(
                              'Error al cargar creador del plan',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        );
                      }
                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>;
                      return _buildPlanTile(context, userData, plan);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
