import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Importa tu modelo de plan y pantallas/dialogs
import '../../models/plan_model.dart';
import '../plans_managing/frosted_plan_dialog_state.dart';
import '../users_managing/user_info_check.dart';
import '../../main/colors.dart';
import '../users_managing/block_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../users_grid/users_grid_helpers.dart';

/// Representa un resultado de búsqueda (usuario o plan).
class SearchResultItem {
  final String id;
  final String title;
  final String subtitle;
  final String avatarUrl;
  final bool isUser;
  final PlanModel? planData;
  final bool hasMatchingPlan;
  final String? upcomingPlanId;
  final String? upcomingPlanName;
  final int additionalPlans;

  SearchResultItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.isUser,
    this.planData,
    this.hasMatchingPlan = false,
    this.upcomingPlanId,
    this.upcomingPlanName,
    this.additionalPlans = 0,
  });
}

/// Widget que muestra los resultados de búsqueda debajo de un campo de texto,
/// devolviendo usuarios y/o planes que coincidan.
class Searcher extends StatefulWidget {
  final String query;
  final double maxHeight;
  final bool isVisible;
  final Future<PlanModel> Function(String planId)? fetchFullPlanById;

  const Searcher({
    Key? key,
    required this.query,
    this.maxHeight = 300.0,
    this.isVisible = true,
    this.fetchFullPlanById,
  }) : super(key: key);

  @override
  State<Searcher> createState() => _SearcherState();
}

class _SearcherState extends State<Searcher> {
  bool _isLoading = false;
  List<SearchResultItem> _results = [];
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.query.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.query);
      });
    }
  }

  @override
  void didUpdateWidget(covariant Searcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.query);
      });
    }
  }

  /// Realiza la búsqueda de usuarios y planes en Firestore.
  Future<void> _performSearch(String rawQuery) async {

    final cleanedQuery = rawQuery.trim();
    if (cleanedQuery.isEmpty) {
      setState(() => _results = []);
      return;
    }

    // Quitamos espacios internos para buscar ID exacto
    final idCandidate = cleanedQuery.replaceAll(RegExp(r'\s+'), '');

    setState(() {
      _isLoading = true;
      _lastQuery = cleanedQuery;
    });

    try {
      final queryLower = cleanedQuery.toLowerCase();
      final List<SearchResultItem> finalResults = [];

      final Set<String> matchingPlanCreators = {};
      final Set<String> allPlanCreators = {};
      final Map<String, List<Map<String, dynamic>>> upcomingPlansByCreator = {};

      final now = DateTime.now();

      // Buscar plan por ID exacto
      final planDocRef =
          FirebaseFirestore.instance.collection('plans').doc(idCandidate);
      final planDocSnap = await planDocRef.get();
      if (planDocSnap.exists) {
        final data = planDocSnap.data() as Map<String, dynamic>?;
        final creator = data?['createdBy']?.toString();
        final ts = data?['start_timestamp'] as Timestamp?;
        if (creator != null && creator.isNotEmpty && ts != null && ts.toDate().isAfter(now)) {
          matchingPlanCreators.add(creator);
          allPlanCreators.add(creator);
          upcomingPlansByCreator.putIfAbsent(creator, () => []).add({
            'id': planDocSnap.id,
            'type': data?['type'] ?? '',
            'start': ts.toDate(),
          });
        }
      }

      // Buscar plan por nombre (coincidencia parcial) y registrar futuros
      final plansSnap =
          await FirebaseFirestore.instance.collection('plans').get();
      for (var planDoc in plansSnap.docs) {
        final pData = planDoc.data() as Map<String, dynamic>;
        final creator = pData['createdBy']?.toString();
        final ts = pData['start_timestamp'] as Timestamp?;
        if (creator != null && creator.isNotEmpty && ts != null && ts.toDate().isAfter(now)) {
          allPlanCreators.add(creator);
          final typeLower =
              (pData['typeLowercase'] ?? pData['type']?.toString().toLowerCase() ?? '')
                  .toString();
          if (typeLower.contains(queryLower)) {
            matchingPlanCreators.add(creator);
          }
          upcomingPlansByCreator.putIfAbsent(creator, () => []).add({
            'id': planDoc.id,
            'type': pData['type'] ?? '',
            'start': ts.toDate(),
          });
        }
      }

      // Buscar usuarios por nombre y/o por planes
      final usersSnap =
          await FirebaseFirestore.instance.collection('users').get();

      for (var doc in usersSnap.docs) {
        final data = doc.data();
        final userId = data['uid'] ?? doc.id;
        final userName = data['name'] ?? 'Usuario';
        final nameLower =
            (data['nameLowercase'] ?? userName.toString().toLowerCase())
                .toString();

        final bool nameMatches = nameLower.contains(queryLower);
        final bool planMatches = matchingPlanCreators.contains(userId);
        final bool hasPlan = allPlanCreators.contains(userId);

        if (!nameMatches && !planMatches) continue;

        final userAge = data['age']?.toString() ?? '';
        final photoUrl = data['photoUrl'] ?? '';

        final userPlans = upcomingPlansByCreator[userId] ?? [];
        userPlans.sort((a, b) => (a['start'] as DateTime)
            .compareTo(b['start'] as DateTime));
        String? nextPlanId;
        String? nextPlanName;
        int additional = 0;
        if (userPlans.isNotEmpty) {
          nextPlanId = userPlans.first['id'] as String?;
          nextPlanName = userPlans.first['type'] as String?;
          additional = userPlans.length - 1;
        }

        finalResults.add(
          SearchResultItem(
            id: userId,
            title: userName,
            subtitle: 'Edad: $userAge',
            avatarUrl: photoUrl,
            isUser: true,
            hasMatchingPlan: hasPlan,
            upcomingPlanId: nextPlanId,
            upcomingPlanName: nextPlanName,
            additionalPlans: additional,
          ),
        );
      }

      final current = FirebaseAuth.instance.currentUser;
      if (current != null) {
        final blockedIds = await fetchBlockedIds(current.uid);
        finalResults.removeWhere((r) => r.isUser && blockedIds.contains(r.id));
      }

      if (mounted && _lastQuery == cleanedQuery) {
        setState(() {
          _results = finalResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Construye un [SearchResultItem] a partir de un DocumentSnapshot de 'plans'.
  Future<SearchResultItem?> _buildSearchItemFromPlan(
      DocumentSnapshot planDoc) async {
    final data = planDoc.data() as Map<String, dynamic>?;
    if (data == null) return null;

    final planMap = {
      'id': planDoc.id,
      ...data,
    };

    // Cargar el PlanModel
    PlanModel planModel;
    if (widget.fetchFullPlanById != null) {
      planModel = await widget.fetchFullPlanById!(planDoc.id);
    } else {
      planModel = PlanModel.fromMap(planMap);
    }

    // Recuperar info del creador
    final creatorId = planModel.createdBy;
    if (creatorId.isNotEmpty) {
      try {
        final creatorSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(creatorId)
            .get();
        if (creatorSnap.exists && creatorSnap.data() != null) {
          final cData = creatorSnap.data()!;
          planModel.creatorName = cData['name'] ?? planModel.creatorName;
          planModel.creatorProfilePic =
              cData['photoUrl'] ?? planModel.creatorProfilePic;
        }
      } catch (_) {
        // Ignoramos errores de carga de usuario
      }
    }

    String startDateString = '';
    if (planModel.startTimestamp != null) {
      final d = planModel.startTimestamp!;
      startDateString = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }

    return SearchResultItem(
      id: planModel.id,
      title: planModel.type,
      subtitle: 'Inicia: $startDateString',
      avatarUrl: planModel.creatorProfilePic ?? '',
      isUser: false,
      planData: planModel,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si no hay texto o no es visible, nada que mostrar
    if (!widget.isVisible || widget.query.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.popularBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade400,
            blurRadius: 5,
            spreadRadius: 2,
          ),
        ],
      ),
      child: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.black),
              ),
            )
          : _results.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "No se han encontrado resultados.",
                    style: TextStyle(color: Colors.black87),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _results.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final item = _results[index];

                    Widget tile = ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                      leading: buildProfileAvatar(
                        item.avatarUrl,
                        radius: 20,
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(color: Colors.black),
                      ),
                      subtitle: Text(
                        item.subtitle,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      trailing: item.upcomingPlanId != null
                          ? InkWell(
                              onTap: () => _onPlanTap(item.upcomingPlanId!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.planColor),
                                ),
                                child: Text(
                                  item.additionalPlans > 0
                                      ? '${item.upcomingPlanName} +${item.additionalPlans}'
                                      : item.upcomingPlanName!,
                                  style: const TextStyle(
                                    color: AppColors.planColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                          : null,
                      onTap: () => _onTapSearchItem(item),
                    );
                    return tile;
                  },
                ),
    );
  }

  /// Maneja el tap en un resultado de la lista.
  void _onTapSearchItem(SearchResultItem item) {
    if (item.isUser) {
      // Ir a la pantalla de info de usuario
      UserInfoCheck.open(context, item.id);
    } else {
      final plan = item.planData;
      if (plan == null) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FrostedPlanDialog(
            plan: plan,
            fetchParticipants: _fetchAllPlanParticipants,
          ),
        ),
      );
    }
  }

  /// Abre el detalle del plan a partir de su id
  Future<void> _onPlanTap(String planId) async {
    PlanModel plan;
    if (widget.fetchFullPlanById != null) {
      plan = await widget.fetchFullPlanById!(planId);
    } else {
      final doc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(planId)
          .get();
      if (!doc.exists || doc.data() == null) return;
      plan = PlanModel.fromMap({'id': doc.id, ...doc.data()!});
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FrostedPlanDialog(
          plan: plan,
          fetchParticipants: _fetchAllPlanParticipants,
        ),
      ),
    );
  }

  /// Carga participantes de un plan
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(PlanModel plan) async {
    final List<Map<String, dynamic>> res = [];
    final uids = plan.participants ?? [];
    for (final uid in uids) {
      final uDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (uDoc.exists) {
        final d = uDoc.data()!;
        res.add({
          'uid': uid,
          'name': d['name'] ?? 'Usuario',
          'age': d['age']?.toString() ?? '',
          'photoUrl': d['photoUrl'] ?? '',
          'isCreator': uid == plan.createdBy,
        });
      }
    }
    return res;
  }
}
