import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LanguageService {
  static final ValueNotifier<Locale> locale =
      ValueNotifier(const Locale('es'));

  static Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    String code;
    if (prefs.containsKey('languageCode')) {
      code = prefs.getString('languageCode') ?? 'es';
    } else {
      final systemCode =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      code = systemCode.startsWith('es') ? 'es' : 'en';
    }
    locale.value = Locale(code);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .set({'languageCode': code}, SetOptions(merge: true));
    }
  }

  static Future<void> updateLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', code);
    locale.value = Locale(code);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .set({'languageCode': code}, SetOptions(merge: true));
    }
  }
}
