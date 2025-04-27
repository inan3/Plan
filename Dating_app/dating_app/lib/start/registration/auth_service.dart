// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Crea un usuario con email y password
  static Future<UserCredential> createUserWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    // Enviar verificación de correo si procede
    if (cred.user != null && !cred.user!.emailVerified) {
      await cred.user!.sendEmailVerification();
    }
    return cred;
  }

  /// Realiza sign in con Google
  static Future<UserCredential> signInWithGoogle() async {
    try {
      // Importante: solo desloguea GoogleSignIn (NO FirebaseAuth)
      await GoogleSignIn().signOut();

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        throw Exception('Usuario canceló el proceso de login con Google.');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception(
            'No se obtuvo accessToken o idToken de Google (nulos).');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Error en Google Sign In: $e');
      rethrow;
    }
  }

  /// Reenvía correo de verificación (si no está verificado).
  static Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Refresca la info del user y devuelve true si el correo está verificado.
  static Future<bool> checkIfEmailVerified() async {
    final user = _auth.currentUser;
    await user?.reload();
    return user?.emailVerified ?? false;
  }

  /// Devuelve el currentUser
  static User? get currentUser => _auth.currentUser;
}
