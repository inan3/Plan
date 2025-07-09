// my_plans_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';

import '../../models/plan_model.dart';
import '../../main/colors.dart';
import '../../utils/plans_list.dart' as plansData;
import '../../plan_creation/new_plan_creation_screen.dart';
import '../plans_managing/plan_card.dart';
import '../plans_managing/frosted_plan_dialog_state.dart' as new_frosted;

import '../main_screen/explore_screen.dart';


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

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    Widget content;
    if (currentUser == null) {
      content = const Center(
        child: Text(
          'Debes iniciar sesión para ver tus planes.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      content = StreamBuilder<QuerySnapshot>(
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
      );
    }

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
                    AppLocalizations.of(context).myPlans,
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



Widget _buildPlanTile(BuildContext context, PlanModel plan) {
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
                try {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) return;

                  final planDoc = await FirebaseFirestore.instance
                      .collection('plans')
                      .doc(plan.id)
                      .get();
                  final participantUids = List<String>.from(
                      planDoc.data()?['participants'] ?? []);
                  participantUids.remove(currentUser.uid);

                  final userSnap = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.uid)
                      .get();
                  final senderName = userSnap.data()?['name'] ?? 'Usuario';
                  final senderPhoto = userSnap.data()?['photoUrl'] ?? '';

                  for (final uid in participantUids) {
                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .add({
                      'type': 'special_plan_deleted',
                      'receiverId': uid,
                      'senderId': currentUser.uid,
                      'senderName': senderName,
                      'senderProfilePic': senderPhoto,
                      'planId': plan.id,
                      'planType': plan.type,
                      'timestamp': FieldValue.serverTimestamp(),
                      'read': false,
                    });
                  }

                  final subs = await FirebaseFirestore.instance
                      .collection('subscriptions')
                      .where('id', isEqualTo: plan.id)
                      .get();
                  for (var doc in subs.docs) {
                    await doc.reference.delete();
                  }

                  await FirebaseFirestore.instance
                      .collection('plans')
                      .doc(plan.id)
                      .delete();

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Plan ${plan.type} eliminado.')),
                  );
                } catch (e) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Error al eliminar el plan.')),
                  );
                }
              },
              child: const Text("Eliminar"),
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
}
