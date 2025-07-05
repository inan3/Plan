import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class StripeService {
  StripeService._internal();
  static final StripeService instance = StripeService._internal();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<void> startOnboarding(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = userDoc.data() ?? {};
    String? accountId = data['stripeAccountId'] as String?;
    final String email = data['email'] as String? ?? user.email ?? '';

    try {
      if (accountId == null) {
        final result = await _functions
            .httpsCallable('createStripeAccount')
            .call({'email': email});
        accountId = result.data['accountId'] as String?;
        if (accountId != null) {
          await userDoc.reference.update({'stripeAccountId': accountId});
        }
      }

      if (accountId != null) {
        final resp = await _functions
            .httpsCallable('createAccountLink')
            .call({'accountId': accountId});
        final url = resp.data['url'] as String?;
        if (url != null) {
          await launchUrl(Uri.parse(url),
              mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al configurar la cuenta bancaria')));
    }
  }
}
