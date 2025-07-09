// subscribed_plans_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/plan_model.dart';
import '../../main/colors.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/plans_list.dart' as plansData;
import '../plans_managing/frosted_plan_dialog_state.dart' as new_frosted;
import '../plans_managing/plan_card.dart';

import '../main_screen/explore_screen.dart';
import '../../plan_creation/new_plan_creation_screen.dart';

class _ExploreScreenWithNewPlan extends StatefulWidget {
  const _ExploreScreenWithNewPlan();

  @override
  State<_ExploreScreenWithNewPlan> createState() => _ExploreScreenWithNewPlanState();
}

class _ExploreScreenWithNewPlanState extends State<_ExploreScreenWithNewPlan> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NewPlanCreationScreen.showPopup(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const ExploreScreen();
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          message,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const _ExploreScreenWithNewPlan(),
              ),
            );
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

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
    final Set<String> processed = {};

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
        processed.add(uid);
      }
    }

    if (!processed.contains(plan.createdBy)) {
      final creatorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(plan.createdBy)
          .get();
      if (creatorDoc.exists && creatorDoc.data() != null) {
        final cData = creatorDoc.data()!;
        participants.add({
          'uid': plan.createdBy,
          'name': cData['name'] ?? 'Sin nombre',
          'age': cData['age']?.toString() ?? '',
          'photoUrl': cData['photoUrl'] ?? cData['profilePic'] ?? '',
          'isCreator': true,
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
        final List<dynamic> participants = planData['participants'] ?? [];
        if (participants.contains(userId)) {
          planData['id'] = planDoc.id;
          plans.add(PlanModel.fromMap(planData));
        } else {
          final subs = await FirebaseFirestore.instance
              .collection('subscriptions')
              .where('userId', isEqualTo: userId)
              .where('id', isEqualTo: planId)
              .get();
          for (var doc in subs.docs) {
            await doc.reference.delete();
          }
        }
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
                try {
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
                    'participants': FieldValue.arrayRemove([userId]),
                    'invitedUsers': FieldValue.arrayRemove([userId])
                  });

                  try {
                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .get();
                    final String leaverName =
                        userDoc.data()?['name'] ?? 'Usuario';
                    final String leaverPhoto =
                        userDoc.data()?['photoUrl'] ?? '';

                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .add({
                      'type': 'special_plan_left',
                      'receiverId': plan.createdBy,
                      'senderId': userId,
                      'senderName': leaverName,
                      'senderProfilePic': leaverPhoto,
                      'planId': plan.id,
                      'planType': plan.type,
                      'timestamp': FieldValue.serverTimestamp(),
                      'read': false,
                    });
                  } catch (_) {}

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Has abandonado el plan ${plan.type}.'),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error al abandonar el plan.')),
                  );
                } finally {
                  Navigator.pop(context);
                }
              },
              child: const Text("Sí"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOverlappingAvatars(
    List<Map<String, dynamic>> participants,
    String currentUid,
  ) {
    if (participants.isEmpty) return const SizedBox.shrink();

    Widget buildAvatar(Map<String, dynamic> data) {
      final url = data['photoUrl'] ?? '';
      return CircleAvatar(
        radius: 20,
        backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      );
    }

    if (participants.length == 1) {
      return buildAvatar(participants.first);
    }

    Map<String, dynamic>? me;
    Map<String, dynamic>? other;
    for (var p in participants) {
      if (p['uid'] == currentUid && me == null) {
        me = p;
      } else if (other == null && p['uid'] != currentUid) {
        other = p;
      }
    }

    if (me == null || other == null) {
      return Row(
        children: participants.take(2).map(buildAvatar).toList(),
      );
    }

    return SizedBox(
      width: 64,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, child: buildAvatar(me)),
          Positioned(left: 24, child: buildAvatar(other)),
        ],
      ),
    );
  }

  Widget _buildPlanTile(
    BuildContext context,
    Map<String, dynamic> userData,
    PlanModel plan,
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    Widget content = StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
              context, 'No te has unido a ningún plan aún...');
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
              return _buildEmptyState(
                  context, 'No te has unido a ningún plan aún...');
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
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
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
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t.subscribedPlans,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ExploreScreen(initiallyOpenSidebar: true),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
