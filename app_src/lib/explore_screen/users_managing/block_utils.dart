import 'package:cloud_firestore/cloud_firestore.dart';

/// Devuelve el conjunto de IDs de usuarios que han sido bloqueados por
/// [userId] o que han bloqueado a [userId].
Future<Set<String>> fetchBlockedIds(String userId) async {
  final Set<String> ids = {};

  final byMe = await FirebaseFirestore.instance
      .collection('blocked_users')
      .where('blockerId', isEqualTo: userId)
      .get();
  for (final doc in byMe.docs) {
    final id = doc.data()['blockedId'] as String?;
    if (id != null) ids.add(id);
  }

  final blockingMe = await FirebaseFirestore.instance
      .collection('blocked_users')
      .where('blockedId', isEqualTo: userId)
      .get();
  for (final doc in blockingMe.docs) {
    final id = doc.data()['blockerId'] as String?;
    if (id != null) ids.add(id);
  }

  return ids;
}

/// Verifica si existe un bloqueo en cualquier dirección entre [a] y [b].
Future<bool> areUsersBlocked(String a, String b) async {
  final doc1 = await FirebaseFirestore.instance
      .collection('blocked_users')
      .doc('${a}_$b')
      .get();
  if (doc1.exists) return true;

  final doc2 = await FirebaseFirestore.instance
      .collection('blocked_users')
      .doc('${b}_$a')
      .get();

  return doc2.exists;
}
