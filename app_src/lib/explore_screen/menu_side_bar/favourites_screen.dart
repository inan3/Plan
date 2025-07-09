// favourites_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../plans_managing/plan_card.dart';
import '../../models/plan_model.dart';
import '../../main/colors.dart';
import '../../l10n/app_localizations.dart';
import '../main_screen/explore_screen.dart';

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({Key? key}) : super(key: key);

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
    final t = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    Widget content;
    if (user == null) {
      content = const Center(
        child: Text(
          'Usuario no autenticado',
          style: TextStyle(color: Colors.white),
        ),
      );
    } else {
      content = StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'No tienes planes favoritos aún.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final favouritePlanIds = List<String>.from(data['favourites'] ?? []);
          if (favouritePlanIds.isEmpty) {
            return const Center(
              child: Text(
                'No tienes planes favoritos aún.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return FutureBuilder<List<PlanModel>>(
            future: _fetchPlansFromIds(favouritePlanIds),
            builder: (context, planSnapshot) {
              if (planSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!planSnapshot.hasData || planSnapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'No tienes planes favoritos aún.',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              final plans = planSnapshot.data!;
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

                      final creatorData =
                          userSnapshot.data!.data() as Map<String, dynamic>;
                      final userData = {
                        'name': creatorData['name'] ?? 'Usuario',
                        'handle': creatorData['handle'] ?? '@usuario',
                        'photoUrl': creatorData['photoUrl'] ?? '',
                      };

                      return PlanCard(
                        plan: plan,
                        userData: userData,
                        fetchParticipants: _fetchAllPlanParticipants,
                        hideJoinButton: false,
                      );
                    },
                  );
                },
              );
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
                    t.favourites,
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
