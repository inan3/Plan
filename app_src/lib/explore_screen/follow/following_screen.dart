import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Eliminamos import innecesario de campanas:
// import 'package:flutter_svg/flutter_svg.dart';

import '../../models/plan_model.dart';
import '../plans_managing/frosted_plan_dialog_state.dart' as new_frosted;
import '../users_managing/user_info_check.dart';
import '../users_managing/user_activity_status.dart';
import '../../main/colors.dart';
import '../../l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Pantalla de seguidores/seguidos.
/// Se muestra como un modal a pantalla casi completa (deja libre el 10 % superior)
/// y permite alternar entre las dos listas además de filtrar por nombre.
class FollowingScreen extends StatefulWidget {
  /// UID del usuario cuyas listas se mostrarán
  final String userId;

  /// `true` => abre inicialmente en la pestaña de seguidores,
  /// `false` => abre inicialmente en la pestaña de seguidos
  final bool showFollowersFirst;

  const FollowingScreen({
    Key? key,
    required this.userId,
    this.showFollowersFirst = true,
  }) : super(key: key);

  /// Atajo estático para lanzar el modal con la animación típica de BottomSheet
  /// y dejando un margen del 10 % en la parte superior.
  static Future<void> show({
    required BuildContext context,
    required String userId,
    bool showFollowersFirst = true,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final height = MediaQuery.of(context).size.height;
        return Container(
          height: height * 0.9, // 90 % de la pantalla
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: FollowingScreen(
            userId: userId,
            showFollowersFirst: showFollowersFirst,
          ),
        );
      },
    );
  }

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  late bool _showFollowers;
  final TextEditingController _searchCtl = TextEditingController();

  /// Lista completa de usuarios
  List<_UserItem> _all = [];

  /// Lista filtrada según el buscador
  List<_UserItem> _filtered = [];

  bool _loading = true;

  Future<_PlanInfo?> _getNextPlanInfo(String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('plans')
          .where('createdBy', isEqualTo: userId)
          .where('special_plan', isEqualTo: 0)
          .get();

      final now = DateTime.now();
      final futures = snap.docs
          .map((d) {
            final data = d.data() as Map<String, dynamic>;
            final ts = data['start_timestamp'];
            if (ts is Timestamp && ts.toDate().isAfter(now)) {
              return {
                'id': d.id,
                'type': data['type'] ?? '',
                'start': ts.toDate(),
              };
            }
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      if (futures.isEmpty) return null;

      futures.sort((a, b) => (a['start'] as DateTime)
          .compareTo(b['start'] as DateTime));

      return _PlanInfo(
        id: futures.first['id'] as String,
        name: futures.first['type'] as String,
        additional: futures.length - 1,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _showFollowers = widget.showFollowersFirst;
    _loadData();
    _searchCtl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final List<_UserItem> items = [];
      // Colección y campo cambian según pestaña
      final isFollowers = _showFollowers;
      final collection = isFollowers ? 'followers' : 'followed';
      final queryField = isFollowers ? 'userId' : 'userId';
      final linkField = isFollowers ? 'followerId' : 'followedId';

      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .where(queryField, isEqualTo: widget.userId)
          .get();

      for (final doc in snap.docs) {
        final relatedUid = doc.data()[linkField];

        final uDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(relatedUid)
            .get();
        if (!uDoc.exists || uDoc.data() == null) continue;

        final data = uDoc.data()!;
        final planInfo = await _getNextPlanInfo(relatedUid);

        items.add(
          _UserItem(
            uid: relatedUid,
            name: data['name'] ?? 'Usuario',
            privilegeLevel: (data['privilegeLevel'] ?? 'Básico').toString(),
            photoUrl: data['photoUrl'] ?? '',
            upcomingPlanId: planInfo?.id,
            upcomingPlanName: planInfo?.name,
            additionalPlans: planInfo?.additional ?? 0,
          ),
        );
      }

      setState(() {
        _all = items;
        _filtered = List.from(_all);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final query = _searchCtl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = List.from(_all);
      } else {
        _filtered =
            _all.where((u) => u.name.toLowerCase().contains(query)).toList();
      }
    });
  }

  void _switchTab(bool followers) {
    if (_showFollowers == followers) return;
    setState(() {
      _showFollowers = followers;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Indicador tipo draggable
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
        // Título principal dinámico
        Text(
          _showFollowers
              ? AppLocalizations.of(context).followers
              : AppLocalizations.of(context).following,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        // Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TabButton(
              label: AppLocalizations.of(context).followers,
              selected: _showFollowers,
              onTap: () => _switchTab(true),
            ),
            const SizedBox(width: 16),
            _TabButton(
              label: AppLocalizations.of(context).following,
              selected: !_showFollowers,
              onTap: () => _switchTab(false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Buscador
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchCtl,
            decoration: InputDecoration(
              hintText: '${AppLocalizations.of(context).search}…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        // Lista
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(child: Text(AppLocalizations.of(context).noResults))
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const _ThinDivider(),
                      itemBuilder: (_, idx) {
                        final u = _filtered[idx];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: CachedNetworkImageProvider(
                                u.photoUrl.isNotEmpty
                                    ? u.photoUrl
                                    : 'https://via.placeholder.com/150'),
                          ),
                          title: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(u.name),
                              const SizedBox(width: 2),
                              Image.asset(
                                _getPrivilegeIcon(u.privilegeLevel),
                                width: 14,
                                height: 14,
                              ),
                            ],
                          ),
                          subtitle: UserActivityStatus(
                            userId: u.uid,
                            // Forzamos color negro en este contexto
                            key: ValueKey('black_${u.uid}'),
                          ),
                          trailing: u.upcomingPlanId != null
                              ? InkWell(
                                  onTap: () => _onPlanTap(u.upcomingPlanId!),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border:
                                          Border.all(color: AppColors.planColor),
                                    ),
                                    child: Text(
                                      u.additionalPlans > 0
                                          ? '${u.upcomingPlanName} +${u.additionalPlans}'
                                          : u.upcomingPlanName!,
                                      style: const TextStyle(
                                        color: AppColors.planColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () {
                            // 1) Cerramos primero el modal
                            Navigator.of(context).pop();

                            // 2) Lanzamos la pantalla de perfil usando el rootNavigator
                            Future.microtask(() {
                              Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute(
                                  builder: (_) => UserInfoCheck(userId: u.uid),
                                ),
                              );
                            });
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _onPlanTap(String planId) async {
    final doc = await FirebaseFirestore.instance
        .collection('plans')
        .doc(planId)
        .get();
    if (!doc.exists || doc.data() == null) return;
    final plan = PlanModel.fromMap({'id': doc.id, ...doc.data()!});

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => new_frosted.FrostedPlanDialog(
          plan: plan,
          fetchParticipants: _fetchAllPlanParticipants,
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(
      PlanModel plan) async {
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
          'photoUrl': d['photoUrl'] ?? '',
          'privilegeLevel': (d['privilegeLevel'] ?? 'Básico').toString(),
          'isCreator': uid == plan.createdBy,
        });
      }
    }
    return res;
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton({
    Key? key,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: selected ? Colors.black : Colors.grey,
        ),
      ),
    );
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: 0.5,
        color: Colors.grey[300],
      ),
    );
  }
}

class _UserItem {
  final String uid;
  final String name;
  final String privilegeLevel;
  final String photoUrl;
  final String? upcomingPlanId;
  final String? upcomingPlanName;
  final int additionalPlans;

  _UserItem({
    required this.uid,
    required this.name,
    required this.privilegeLevel,
    required this.photoUrl,
    this.upcomingPlanId,
    this.upcomingPlanName,
    this.additionalPlans = 0,
  });
}

class _PlanInfo {
  final String id;
  final String name;
  final int additional;

  _PlanInfo({required this.id, required this.name, required this.additional});
}

String _getPrivilegeIcon(String level) {
  final normalized = level.toLowerCase().replaceAll('á', 'a');
  switch (normalized) {
    case 'premium':
      return 'assets/icono-usuario-premium.png';
    case 'golden':
      return 'assets/icono-usuario-golden.png';
    case 'vip':
      return 'assets/icono-usuario-vip.png';
    default:
      return 'assets/icono-usuario-basico.png';
  }
}
