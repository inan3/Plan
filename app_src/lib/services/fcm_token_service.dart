import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmTokenService {
  FcmTokenService._();

  static Future<void> register(User user) async {
    final db = FirebaseFirestore.instance;
    final doc = await db.doc('users/${user.uid}').get();
    final hasProfile = doc.exists && (doc.data()?['name'] ?? '').toString().isNotEmpty;
    if (!hasProfile) return;

    final fcm = FirebaseMessaging.instance;
    final perm = await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (perm.authorizationStatus != AuthorizationStatus.authorized) return;

    Future<void> save(String token) async {
      final batch = db.batch();

      final q = await db.collection('users').where('tokens', arrayContains: token).get();
      for (final d in q.docs) {
        if (d.id != user.uid) {
          batch.update(d.reference, {
            'tokens': FieldValue.arrayRemove([token])
          });
        }
      }

      batch.set(
        db.doc('users/${user.uid}'),
        {
          'tokens': FieldValue.arrayUnion([token])
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    }

    String? token = await fcm.getToken();
    token ??= await fcm.onTokenRefresh.first;
    await save(token);

    fcm.onTokenRefresh.listen(save);
  }
}
