// privacy.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../l10n/app_localizations.dart';
import '../../users_managing/blocked_users_screen.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({Key? key}) : super(key: key);

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _isVisibilityPublic = true;
  bool _isActivityPublic = true;
  bool _loading = true;
  int _blockedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPrivacy();
  }

  Future<void> _loadPrivacy() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data();
      final isPublic = (data?['profile_privacy'] ?? 0) == 0;
      final activityPublic = data?['activityStatusPublic'];
      final blockedSnap = await FirebaseFirestore.instance
          .collection('blocked_users')
          .where('blockerId', isEqualTo: uid)
          .get();
      final blockedCount = blockedSnap.docs.length;
      if (mounted) {
        setState(() {
          _isVisibilityPublic = isPublic;
          _isActivityPublic =
              activityPublic is bool ? activityPublic : true;
          _blockedCount = blockedCount;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePrivacy(bool isPublic) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'profile_privacy': isPublic ? 0 : 1}, SetOptions(merge: true));
  }

  Future<void> _updateActivityPrivacy(bool isPublic) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'activityStatusPublic': isPublic}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.privacy),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      backgroundColor: Colors.grey.shade200,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.controlProfileVisibility,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.visibility,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      _isVisibilityPublic ? t.public : t.private,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _isVisibilityPublic,
                      onChanged: (v) async {
                        setState(() => _isVisibilityPublic = v);
                        await _updatePrivacy(v);
                      },
                      activeTrackColor: Colors.green,
                      activeColor: Colors.white,
                      inactiveTrackColor: Colors.grey,
                      inactiveThumbColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              t.activityPrivacyDesc,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.activityStatus,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      _isActivityPublic ? t.public : t.private,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _isActivityPublic,
                      onChanged: (v) async {
                        setState(() => _isActivityPublic = v);
                        await _updateActivityPrivacy(v);
                      },
                      activeTrackColor: Colors.green,
                      activeColor: Colors.white,
                      inactiveTrackColor: Colors.grey,
                      inactiveThumbColor: Colors.white,
                    ),
                  ],
                ),
            ),
          ),
            const SizedBox(height: 24),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BlockedUsersScreen()),
                    );
                    _loadPrivacy();
                  },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.blockedUsers,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      if (_blockedCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: Text(
                            '$_blockedCount',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
