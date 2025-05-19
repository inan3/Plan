import 'dart:async';
import 'package:flutter/material.dart';
// Cambiamos esta import:
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Widget que muestra la actividad de un usuario usando Realtime Database.
class UserActivityStatus extends StatefulWidget {
  final String userId;

  const UserActivityStatus({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<UserActivityStatus> createState() => _UserActivityStatusState();
}

class _UserActivityStatusState extends State<UserActivityStatus> {
  bool _isOnline = false;
  DateTime? _lastSeen;
  StreamSubscription<DatabaseEvent>? _rtdbSubscription;
  StreamSubscription<DocumentSnapshot>? _userDocSub;
  bool _showStatus = true;

  @override
  void initState() {
    super.initState();
    _listenToUserStatus(widget.userId);
    _listenToPrivacy(widget.userId);
  }

  @override
  void dispose() {
    _rtdbSubscription?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }

  /// Se suscribe a /status/{uid} en la base “plan-social-app”
  void _listenToUserStatus(String uid) {
    // 1) Obtenemos la instancia con la URL de la base secundaria:
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://plan-social-app-default-rtdb.europe-west1.firebasedatabase.app',
    );

    // 2) Referencia a “status/{uid}”
    final ref = db.ref('status/$uid');

    // 3) Escuchamos cambios en tiempo real
    _rtdbSubscription = ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        final onlineVal = data['online'];
        final lastSeenVal = data['lastSeen'];

        setState(() {
          _isOnline = (onlineVal == true);

          if (lastSeenVal is int && lastSeenVal > 0) {
            _lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenVal);
          } else {
            _lastSeen = null;
          }
        });
      } else {
        // Si no existe la ruta, asumimos offline
        setState(() {
          _isOnline = false;
          _lastSeen = null;
        });
      }
    });
  }

  void _listenToPrivacy(String uid) {
    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data != null && data['activityStatusPublic'] is bool) {
        setState(() {
          _showStatus = data['activityStatusPublic'] as bool;
        });
      } else {
        setState(() {
          _showStatus = true;
        });
      }
    });
  }

  /// Retorna un string estilo "Hace 5 minuto/s", etc.
  String _formatLastActive(DateTime? dt) {
    if (dt == null) return "Desconectado";
    final diff = DateTime.now().difference(dt);

    if (diff.inMinutes < 1) {
      return "Hace unos segundos";
    } else if (diff.inMinutes < 60) {
      return "Hace ${diff.inMinutes} minutos";
    } else if (diff.inHours < 24) {
      return "Hace ${diff.inHours} horas";
    } else {
      return "Hace ${diff.inDays} días";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showStatus) return const SizedBox.shrink();
    if (_isOnline) {
      // Usuario conectado
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(color: Colors.green),
          const SizedBox(width: 4),
          const Text(
            "En línea",
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      );
    } else {
      // Usuario desconectado
      final info = _formatLastActive(_lastSeen);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(color: Colors.white),
          const SizedBox(width: 4),
          Text(
            info,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      );
    }
  }

  Widget _buildDot({required Color color}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
