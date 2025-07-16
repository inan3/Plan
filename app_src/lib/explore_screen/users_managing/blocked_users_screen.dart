import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'user_activity_status.dart';
import '../../l10n/app_localizations.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({Key? key}) : super(key: key);

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  bool _loading = true;
  List<_UserItem> _users = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('blocked_users')
          .where('blockerId', isEqualTo: uid)
          .get();

      final List<_UserItem> list = [];
      for (final doc in snap.docs) {
        final blockedId = doc.data()['blockedId'];
        if (blockedId == null) continue;
        final uDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(blockedId)
            .get();
        if (!uDoc.exists || uDoc.data() == null) continue;
        final data = uDoc.data()!;
        final planInfo = await _getNextPlanInfo(blockedId);
        list.add(_UserItem(
          uid: blockedId,
          name: data['name'] ?? 'Usuario',
          privilegeLevel: (data['privilegeLevel'] ?? 'Básico').toString(),
          photoUrl: data['photoUrl'] ?? '',
          upcomingPlanId: planInfo?.id,
          upcomingPlanName: planInfo?.name,
          additionalPlans: planInfo?.additional ?? 0,
        ));
      }

      if (mounted) {
        setState(() {
          _users = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

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

  Future<void> _unblock(String userId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final docId = '${uid}_$userId';
    await FirebaseFirestore.instance
        .collection('blocked_users')
        .doc(docId)
        .delete();
  }

  void _onUserTap(_UserItem item) {
    final t = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(t.unblockQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.no),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _unblock(item.uid);
              if (mounted) {
                setState(() => _users.removeWhere((u) => u.uid == item.uid));
              }
            },
            child: Text(t.yes),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.blockedUsers),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(child: Text(t.noResults))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final u = _users[idx];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: u.photoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(u.photoUrl)
                            : null,
                      ),
                      title: Row(
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
                        key: ValueKey('black_${u.uid}'),
                      ),
                      trailing: u.upcomingPlanName != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: Colors.blueGrey.shade700),
                              ),
                              child: Text(
                                u.additionalPlans > 0
                                    ? '${u.upcomingPlanName} +${u.additionalPlans}'
                                    : u.upcomingPlanName!,
                                style: const TextStyle(
                                    color: Colors.blueGrey, fontSize: 12),
                              ),
                            )
                          : null,
                      onTap: () => _onUserTap(u),
                    );
                  },
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
