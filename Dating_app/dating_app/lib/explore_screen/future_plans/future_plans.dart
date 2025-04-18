// lib/explore_screen/future_plans/future_plans.dart

import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/plan_model.dart';
import '../users_grid/plan_card.dart';

class FuturePlansScreen extends StatefulWidget {
  final String userId;
  final bool isFollowing;
  final void Function(PlanModel plan) onPlanSelected;

  const FuturePlansScreen({
    Key? key,
    required this.userId,
    required this.isFollowing,
    required this.onPlanSelected,
  }) : super(key: key);

  static Future<void> show({
    required BuildContext context,
    required String userId,
    required bool isFollowing,
    required void Function(PlanModel plan) onPlanSelected,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final h = MediaQuery.of(context).size.height;
        return Container(
          height: h * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: FuturePlansScreen(
            userId: userId,
            isFollowing: isFollowing,
            onPlanSelected: onPlanSelected,
          ),
        );
      },
    );
  }

  @override
  State<FuturePlansScreen> createState() => _FuturePlansScreenState();
}

class _FuturePlansScreenState extends State<FuturePlansScreen> {
//─────────────────────────── Helpers ───────────────────────────
  Future<Map<String, dynamic>?> _userData() async =>
      (await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get())
          .data();

  Future<List<PlanModel>> _futurePlans() async {
    final now = DateTime.now();
    final snap = await FirebaseFirestore.instance
        .collection('plans')
        .where('createdBy', isEqualTo: widget.userId)
        .where('special_plan', isEqualTo: 0)
        .get();

    final List<PlanModel> list = [];
    for (final d in snap.docs) {
      final data = d.data();
      final ts = data['start_timestamp'] as Timestamp?;
      if (ts != null && ts.toDate().isAfter(now)) {
        data['id'] = d.id;
        list.add(PlanModel.fromMap(data));
      }
    }
    list.sort((a, b) => a.startTimestamp!.compareTo(b.startTimestamp!));
    return list;
  }

  Future<List<Map<String, dynamic>>> _participants(PlanModel p) async {
    final res = <Map<String, dynamic>>[];
    final doc =
        await FirebaseFirestore.instance.collection('plans').doc(p.id).get();
    for (final uid in List<String>.from(doc['participants'] ?? [])) {
      final u = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (u.exists) {
        final d = u.data()!;
        res.add({
          'uid': uid,
          'name': d['name'] ?? 'Usuario',
          'age': d['age']?.toString() ?? '',
          'photoUrl': d['photoUrl'] ?? '',
          'isCreator': uid == p.createdBy,
        });
      }
    }
    return res;
  }

//─────────────────────────── UI ────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Planes futuros',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Divider(height: 1),

          Expanded(
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _userData(),
              builder: (_, uSnap) {
                if (uSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final userData = uSnap.data ?? {};

                return FutureBuilder<List<PlanModel>>(
                  future: _futurePlans(),
                  builder: (_, pSnap) {
                    if (pSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!pSnap.hasData || pSnap.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'Este usuario no ha creado planes futuros aún...',
                          style: TextStyle(fontSize: 16),
                        ),
                      );
                    }

                    final plans = pSnap.data!;
                    return ListView.separated(
                      itemCount: plans.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: Colors.grey[300], height: 1),
                      itemBuilder: (_, i) {
                        final plan = plans[i];

                        final card = GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onPlanSelected(plan);
                          },
                          child: PlanCard(
                            plan: plan,
                            userData: userData,
                            fetchParticipants: _participants,
                          ),
                        );

                        final locked = (plan.visibility?.toLowerCase() ==
                                'solo para mis seguidores') &&
                            !widget.isFollowing;

                        if (!locked) return card;

                        // ────────── Tarjeta bloqueada ──────────
                        return Stack(
                          children: [
                            IgnorePointer(child: card),

                            // RepaintBoundary evita parpadeos al hacer scroll
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Desenfoque
                                      BackdropFilter(
                                        filter: ui.ImageFilter.blur(
                                            sigmaX: 20, sigmaY: 20),
                                        child: const SizedBox.expand(),
                                      ),

                                      // Capa opaca (75 % negro)
                                      Container(
                                        color: Colors.black.withOpacity(0.75),
                                      ),

                                      // Contenido centrado
                                      Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SvgPicture.asset(
                                              'assets/icono-candado.svg',
                                              width: 48,
                                              height: 48,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(height: 12),
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 24),
                                              child: Text(
                                                'Debes seguir a esta cuenta para ver sus planes futuros',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
