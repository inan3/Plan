//user_activity_status.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

/// Widget que muestra la actividad de un usuario usando Realtime Database.
/// - Punto verde + "En línea" si /status/{uid}/online == true
/// - Punto blanco + "Hace X..." si está offline, calculando lastSeen
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

  @override
  void initState() {
    super.initState();
    _listenToUserStatus(widget.userId);
  }

  @override
  void dispose() {
    _rtdbSubscription?.cancel();
    super.dispose();
  }

  /// Se suscribe a /status/{uid} en RTDB para detectar cambios en `online` y `lastSeen`
  void _listenToUserStatus(String uid) {
    final ref = FirebaseDatabase.instance.ref('status/$uid');
    _rtdbSubscription = ref.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      if (data is Map) {
        final onlineVal = data['online'];
        final lastSeenVal = data['lastSeen'];

        setState(() {
          _isOnline = (onlineVal == true);

          if (lastSeenVal is int) {
            // Convertimos milisegundos → DateTime
            _lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenVal);
          } else {
            _lastSeen = null;
          }
        });
      } else {
        // Si no existe la ruta o está vacía, asumimos offline sin timestamp
        setState(() {
          _isOnline = false;
          _lastSeen = null;
        });
      }
    });
  }

  /// Retorna un string estilo "Hace 5 minuto/s, Hace 2 hora/s, Hace 1 día/s", etc.
  String _formatLastActive(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);

    if (diff.inMinutes < 1) {
      return "Hace unos segundos";
    } else if (diff.inMinutes < 60) {
      return "Hace ${diff.inMinutes} minuto/s";
    } else if (diff.inHours < 24) {
      return "Hace ${diff.inHours} hora/s";
    } else {
      return "Hace ${diff.inDays} dia/s";
    }
  }

  @override
  Widget build(BuildContext context) {
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
