// init_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'welcome_screen.dart';
import '../explore_screen/main_screen/explore_screen.dart';

class InitScreen extends StatefulWidget {
  const InitScreen({super.key});
  @override
  State<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (!mounted) return;
      if (user == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      final requiredFields = ['name', 'age', 'photoUrl'];
      bool valid = true;
      for (final f in requiredFields) {
        final val = data?[f];
        if (val == null || (val is String && val.trim().isEmpty)) {
          valid = false;
          break;
        }
      }

      if (!valid) {
        await doc.reference.delete().catchError((_) {});
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      } else {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ExploreScreen()),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(body: Center(child: Text('Error: \$_error')));
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
