// privacy.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({Key? key}) : super(key: key);

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _isVisibilityPublic = true;
  bool _isActivityPublic = true;
  bool _loading = true;

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
      if (mounted) {
        setState(() {
          _isVisibilityPublic = isPublic;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacidad'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      backgroundColor: Colors.grey.shade200,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Controla quién puede ver tu perfil.',
              style: TextStyle(
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
                        'Visibilidad',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      _isVisibilityPublic ? 'Público' : 'Privado',
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
            const Text(
              'Permite que otros vean si estás en línea o tu última conexión.',
              style: TextStyle(
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
                        'Estado de actividad',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      _isActivityPublic ? 'Público' : 'Privado',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _isActivityPublic,
                      onChanged: (v) => setState(() => _isActivityPublic = v),
                      activeTrackColor: Colors.green,
                      activeColor: Colors.white,
                      inactiveTrackColor: Colors.grey,
                      inactiveThumbColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
