// plan_card.dart
import 'dart:ui' as ui;
import 'dart:math' as math; // Para min() si quieres dejarlo más robusto.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../models/plan_model.dart';
import '../../main/colors.dart';
import '../users_grid/users_grid_helpers.dart'; // buildPlaceholder, buildProfileAvatar, etc.
import 'plan_share_sheet.dart';
import '../users_managing/user_info_check.dart';
import 'frosted_plan_dialog_state.dart';

// Importamos el widget de estado de actividad:
import '../users_managing/user_activity_status.dart';
import '../profile/profile_screen.dart';

/// Tarjeta que muestra cada Plan en la lista
class PlanCard extends StatefulWidget {
  final PlanModel plan;
  final Map<String, dynamic> userData;
  final Future<List<Map<String, dynamic>>> Function(PlanModel plan)
      fetchParticipants;
  final bool hideJoinButton;

  const PlanCard({
    Key? key,
    required this.plan,
    required this.userData,
    required this.fetchParticipants,
    this.hideJoinButton = false,
  }) : super(key: key);

  @override
  State<PlanCard> createState() => PlanCardState();
}

enum JoinState { none, requested, rejoin }

class PlanCardState extends State<PlanCard> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  bool _liked = false;
  int _likeCount = 0;

  // Chat
  final TextEditingController _chatController = TextEditingController();

  // Participantes
  late Future<List<Map<String, dynamic>>> _futureParticipants;
  late List<Map<String, dynamic>> _participants;

  // Manejo de la solicitud de unirse
  JoinState _joinState = JoinState.none;
  String? _pendingNotificationId;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.plan.likes;
    _participants = [];
    _futureParticipants = widget.fetchParticipants(widget.plan);

    _checkIfLiked();
    _checkIfPendingJoinRequest();
  }

  // ─────────────────────────────────────────────────────────────
  // (1) Verificar si ya le di "like" a este plan
  // ─────────────────────────────────────────────────────────────
  Future<void> _checkIfLiked() async {
    if (_currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .get();
    if (!userDoc.exists) return;

    final data = userDoc.data()!;
    final favs = data['favourites'] as List<dynamic>? ?? [];
    if (favs.contains(widget.plan.id)) {
      setState(() => _liked = true);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // (2) Verificar si tenemos una solicitud de unión pendiente
  // ─────────────────────────────────────────────────────────────
  Future<void> _checkIfPendingJoinRequest() async {
    if (_currentUser == null) return;

    // Si ya es participante, no necesitamos join_request
    if (widget.plan.participants?.contains(_currentUser!.uid) ?? false) {
      return;
    }

    final q = await FirebaseFirestore.instance
        .collection('notifications')
        .where('type', isEqualTo: 'join_request')
        .where('senderId', isEqualTo: _currentUser!.uid)
        .where('receiverId', isEqualTo: widget.plan.createdBy)
        .where('planId', isEqualTo: widget.plan.id)
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) {
      setState(() {
        _joinState = JoinState.requested;
        _pendingNotificationId = q.docs.first.id;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // (3) Toggle "Like"
  // ─────────────────────────────────────────────────────────────
  Future<void> _toggleLike() async {
    if (_currentUser == null) return;

    final planRef =
        FirebaseFirestore.instance.collection('plans').doc(widget.plan.id);
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(planRef);
      if (!snap.exists) return;

      int currentLikes = snap.data()?['likes'] ?? 0;
      if (!_liked) {
        currentLikes++;
      } else {
        currentLikes = (currentLikes > 0) ? currentLikes - 1 : 0;
      }
      transaction.update(planRef, {'likes': currentLikes});
      setState(() => _likeCount = currentLikes);
    });

    if (!_liked) {
      await userRef.update({
        'favourites': FieldValue.arrayUnion([widget.plan.id])
      });
    } else {
      await userRef.update({
        'favourites': FieldValue.arrayRemove([widget.plan.id])
      });
    }
    setState(() => _liked = !_liked);
  }

  // ─────────────────────────────────────────────────────────────
  // (4) Botón "Unirse"
  // ─────────────────────────────────────────────────────────────
  Future<void> _onJoinTap() async {
    if (_currentUser == null) return;
    final plan = widget.plan;

    // Si ya participas
    if (plan.participants?.contains(_currentUser!.uid) ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya eres participante de este plan.')),
      );
      return;
    }

    // Si es tu plan
    if (plan.createdBy == _currentUser!.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes unirte a tu propio plan')),
      );
      return;
    }

    // Cupo lleno → no se hace nada
    final int participantes = plan.participants?.length ?? 0;
    final int maxPart = plan.maxParticipants ?? 0;
    if (maxPart > 0 && participantes >= maxPart) {
      return; // Sin acción
    }

    // Alternar join_request
    if (_joinState == JoinState.requested) {
      // Cancelamos la solicitud anterior
      await _cancelJoinRequest();
      setState(() {
        _joinState = JoinState.rejoin;
      });
    } else {
      // Creamos solicitud de unión
      await _createJoinRequest();
      setState(() {
        _joinState = JoinState.requested;
      });
    }
  }

  Future<void> _createJoinRequest() async {
    if (_currentUser == null) return;

    final plan = widget.plan;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .get();

    String senderName = 'Usuario';
    String senderPhoto = '';
    if (userDoc.exists && userDoc.data() != null) {
      final udata = userDoc.data()!;
      senderName = udata['name'] ?? senderName;
      senderPhoto = udata['photoUrl'] ?? senderPhoto;
    }

    final planType = plan.type.isNotEmpty ? plan.type : 'Plan';
    final docRef =
        await FirebaseFirestore.instance.collection('notifications').add({
      'type': 'join_request',
      'receiverId': plan.createdBy,
      'senderId': _currentUser!.uid,
      'senderName': senderName,
      'senderProfilePic': senderPhoto,
      'planId': plan.id,
      'planType': planType,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    _pendingNotificationId = docRef.id;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tu solicitud de unión se ha enviado con éxito.'),
      ),
    );
  }

  Future<void> _cancelJoinRequest() async {
    try {
      if (_pendingNotificationId != null) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(_pendingNotificationId!)
            .delete();

        _pendingNotificationId = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Has cancelado tu solicitud de unión.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cancelar solicitud: $e')),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // (5) Abrir detalles del plan
  // ─────────────────────────────────────────────────────────────
  void _openPlanDetails(BuildContext context, PlanModel plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FrostedPlanDialog(
          plan: plan,
          fetchParticipants: widget.fetchParticipants,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // (6) Popup Chat
  // ─────────────────────────────────────────────────────────────
  void _onMessageButtonTap() {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.25,
          ),
          backgroundColor: const ui.Color.fromARGB(255, 35, 57, 80),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: _buildChatPopup(widget.plan),
        );
      },
    );
  }

  Widget _buildChatPopup(PlanModel plan) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  "Chat del Plan",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white38),

        // Lista de mensajes
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('plan_chat')
                .where('planId', isEqualTo: plan.id)
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.hasError) {
                return const Center(
                  child: Text('Error al cargar mensajes',
                      style: TextStyle(color: Colors.white)),
                );
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text('No hay mensajes todavía',
                      style: TextStyle(color: Colors.white)),
                );
              }
              return ListView(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final text = data['text'] ?? '';
                  final senderName = data['senderName'] ?? 'Invitado';
                  final senderPic = data['senderPic'] ?? '';
                  final ts = data['timestamp'] as Timestamp?;
                  final timeStr = _formatTimestamp(ts);

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundImage:
                          senderPic.isNotEmpty ? NetworkImage(senderPic) : null,
                      backgroundColor: Colors.blueGrey[100],
                    ),
                    title: Text(
                      senderName,
                      style: const TextStyle(
                        color: Colors.yellow,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '$text\n$timeStr',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),

        // Caja de texto
        Container(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: "Escribe un mensaje...",
                    filled: true,
                    fillColor: Colors.white24,
                    hintStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () => _sendMessage(plan),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _sendMessage(PlanModel plan) async {
    if (_currentUser == null) return;
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    String senderName = _currentUser!.uid;
    String senderPic = '';

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .get();
    if (userDoc.exists && userDoc.data() != null) {
      final data = userDoc.data()!;
      senderPic = data['photoUrl'] ?? senderPic;
      senderName = data['name'] ?? senderName;
    }

    await FirebaseFirestore.instance.collection('plan_chat').add({
      'planId': plan.id,
      'senderId': _currentUser!.uid,
      'senderName': senderName,
      'senderPic': senderPic,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Actualizar commentsCount en el doc del plan
    final planRef = FirebaseFirestore.instance.collection('plans').doc(plan.id);
    await planRef.update({
      'commentsCount': FieldValue.increment(1),
    }).catchError((_) {
      planRef.set({'commentsCount': 1}, SetOptions(merge: true));
    });

    _chatController.clear();
  }

  // ─────────────────────────────────────────────────────────────
  // Compartir plan
  // ─────────────────────────────────────────────────────────────
  void _onShareButtonTap() {
    _openCustomShareModal(widget.plan);
  }

  void _openCustomShareModal(PlanModel plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) {
            return PlanShareSheet(
              plan: plan,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Bloque de "creador" (avatar + nombre + actividad)
  // ─────────────────────────────────────────────────────────────
  Widget _buildCreatorFrosted(String name, String? photoUrl) {
    final creatorUid = widget.plan.createdBy;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          color: Colors.black.withOpacity(0.2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              buildProfileAvatar(photoUrl),
              const SizedBox(width: 8),

              // Nombre y estado de actividad
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre + verificado
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SvgPicture.asset(
                        'assets/verificado.svg',
                        width: 14,
                        height: 14,
                        color: Colors.blueAccent,
                      ),
                    ],
                  ),

                  // Solo el estado de actividad
                  if (creatorUid.isNotEmpty)
                    UserActivityStatus(userId: creatorUid),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Función de truncado seguro
  // ─────────────────────────────────────────────────────────────
  String _truncate(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return text.substring(0, math.min(maxChars, text.length)) + '…';
  }

  // ─────────────────────────────────────────────────────────────
  // Participantes en la esquina
  // ─────────────────────────────────────────────────────────────
  Widget _buildParticipantsCorner() {
    if (_participants.isEmpty) return const SizedBox.shrink();
    final count = _participants.length;

    // Solo 1
    if (count == 1) {
      final p = _participants[0];
      final pic = p['photoUrl'] ?? '';
      String name = p['name'] ?? 'Usuario';
      final age = p['age']?.toString() ?? '';

      const int maxChars = 14;
      String displayText = '$name, $age';
      displayText = _truncate(displayText, maxChars);

      return GestureDetector(
        onTap: () => _showParticipantsModal(_participants),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
                backgroundColor: Colors.blueGrey[400],
              ),
              const SizedBox(width: 8),
              Text(displayText, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }
    // Si hay 2 o más
    else {
      final p1 = _participants[0];
      final p2 = _participants[1];
      final pic1 = p1['photoUrl'] ?? '';
      final pic2 = p2['photoUrl'] ?? '';

      const double avatarSize = 40;
      const double overlapOffset = 24;
      final extras = count - 2;
      final hasExtras = extras > 0;

      final double containerWidth = hasExtras
          ? (avatarSize + overlapOffset * 2)
          : (avatarSize + overlapOffset);

      return GestureDetector(
        onTap: () => _showParticipantsModal(_participants),
        child: SizedBox(
          width: containerWidth,
          height: avatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                child: CircleAvatar(
                  radius: avatarSize / 2,
                  backgroundImage: pic1.isNotEmpty ? NetworkImage(pic1) : null,
                  backgroundColor: Colors.blueGrey[400],
                ),
              ),
              Positioned(
                left: overlapOffset,
                child: CircleAvatar(
                  radius: avatarSize / 2,
                  backgroundImage: pic2.isNotEmpty ? NetworkImage(pic2) : null,
                  backgroundColor: Colors.blueGrey[400],
                ),
              ),
              if (hasExtras)
                Positioned(
                  left: overlapOffset * 2,
                  child: SizedBox(
                    width: avatarSize,
                    height: avatarSize,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(avatarSize / 2),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          color: Colors.white.withOpacity(0.4),
                          child: Center(
                            child: Text(
                              '+$extras',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
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

  // ─────────────────────────────────────────────────────────────
  // Modal de participantes (con lógica de "ASISTE")
  // ─────────────────────────────────────────────────────────────
  Future<void> _showParticipantsModal(
    List<Map<String, dynamic>> participants,
  ) async {
    // Revisamos quién ha hecho check-in
    List checkedInUsers = [];
    try {
      final planSnap = await FirebaseFirestore.instance
          .collection('plans')
          .doc(widget.plan.id)
          .get();
      final planData = planSnap.data();
      checkedInUsers = planData?['checkedInUsers'] ?? [];
    } catch (e) {
      debugPrint('Error al cargar checkedInUsers: $e');
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          // Ocupamos casi toda la pantalla
          insetPadding: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.05,
            left: 0,
            right: 0,
            bottom: 0,
          ),
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 13, 32, 53),
                  Color.fromARGB(255, 72, 38, 38),
                  Color(0xFF12232E),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Título
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Participantes",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white38),

                // Lista
                Expanded(
                  child: ListView.builder(
                    itemCount: participants.length,
                    itemBuilder: (ctx, i) {
                      final p = participants[i];
                      final pic = p['photoUrl'] ?? '';
                      final name = p['name'] ?? 'Usuario';
                      final age = p['age']?.toString() ?? '';
                      final uid = p['uid']?.toString() ?? '';

                      final bool isCheckedIn = checkedInUsers.contains(uid);

                      return ListTile(
                        onTap: () {
                          if (uid.isEmpty || uid == _currentUser?.uid) return;
                          // Verificación / apertura de perfil
                          UserInfoCheck.open(context, uid);
                        },
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundImage:
                              pic.isNotEmpty ? NetworkImage(pic) : null,
                          backgroundColor: Colors.blueGrey[400],
                        ),
                        title: Text(
                          '$name, $age',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Si está en check-in, mostramos "ASISTE"
                        trailing: isCheckedIn
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Text(
                                  'ASISTE',
                                  style: TextStyle(
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Botón "Unirse" o "Cupo completo"
  // ─────────────────────────────────────────────────────────────
  Widget _buildJoinFrosted() {
    if (widget.hideJoinButton) {
      return const SizedBox.shrink();
    }

    final plan = widget.plan;
    final int pCount = plan.participants?.length ?? 0;
    final int maxP = plan.maxParticipants ?? 0;
    final bool isFull = (maxP > 0 && pCount >= maxP);

    if (isFull) {
      // Cupo completo => texto
      return ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.black.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: const Text(
              "Cupo completo",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    } else {
      // Botón normal
      String buttonText;
      switch (_joinState) {
        case JoinState.none:
          buttonText = 'Unirse';
          break;
        case JoinState.requested:
          buttonText = 'Unión solicitada';
          break;
        case JoinState.rejoin:
          buttonText = 'Unirse';
          break;
      }

      return GestureDetector(
        onTap: _onJoinTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.black.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/union.svg',
                    width: 20,
                    height: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    buttonText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Botón Frosted (like, chat, share)
  // ─────────────────────────────────────────────────────────────
  Widget _buildFrostedAction({
    required String iconPath,
    required String countText,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  iconPath,
                  width: 20,
                  height: 20,
                  color: iconColor,
                ),
                const SizedBox(width: 4),
                Text(
                  countText,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Formatear fecha/hora (Timestamp o DateTime)
  // ─────────────────────────────────────────────────────────────
  String _formatTimestamp(dynamic value) {
    if (value == null) return '';
    late DateTime dt;

    if (value is Timestamp) {
      dt = value.toDate();
    } else if (value is DateTime) {
      dt = value;
    } else {
      return '';
    }

    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final name = widget.userData['name']?.toString().trim() ?? 'Usuario';
    final fallbackPhotoUrl = widget.userData['photoUrl']?.toString();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futureParticipants,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 330,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return SizedBox(
            height: 330,
            child: Center(
              child: Text(
                'Error: ${snap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        _participants = snap.data ?? [];
        final totalP = _participants.length;
        final maxP = plan.maxParticipants ?? 0;
        final bool isFull = (maxP > 0 && totalP >= maxP);

        // Fecha/hora de inicio
        final dateText = _formatTimestamp(plan.startTimestamp);

        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.95,
              margin: const EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromARGB(255, 13, 32, 53),
                    Color.fromARGB(255, 72, 38, 38),
                    Color(0xFF12232E),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fila superior (creador + botón unirse)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            final creatorUid = plan.createdBy;
                            final currentUid =
                                FirebaseAuth.instance.currentUser?.uid;
                            if (creatorUid.isNotEmpty &&
                                creatorUid != currentUid) {
                              UserInfoCheck.open(context, creatorUid);
                            }
                          },
                          child: _buildCreatorFrosted(name, fallbackPhotoUrl),
                        ),
                        const Spacer(),
                        _buildJoinFrosted(),
                      ],
                    ),
                  ),

                  // Imagen principal
                  GestureDetector(
                    onTap: () => _openPlanDetails(context, plan),
                    child: (plan.backgroundImage != null &&
                            plan.backgroundImage!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 16 / 13,
                              child: Image.network(
                                plan.backgroundImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    buildPlaceholder(),
                              ),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: buildPlaceholder(),
                            ),
                          ),
                  ),

                  // Botones de acción (like, chat, share) → Se añade SingleChildScrollView para evitar overflow
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 8,
                      bottom: 8,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFrostedAction(
                            iconPath: 'assets/corazon.svg',
                            countText: '$_likeCount',
                            onTap: _toggleLike,
                            iconColor: _liked ? Colors.red : Colors.white,
                          ),
                          const SizedBox(width: 16),
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('plans')
                                .doc(plan.id)
                                .snapshots(),
                            builder: (ctx, snapMsg) {
                              String countText = '0';
                              if (snapMsg.hasData && snapMsg.data!.exists) {
                                final d =
                                    snapMsg.data!.data() as Map<String, dynamic>;
                                final c = d['commentsCount'] ?? 0;
                                countText = c.toString();
                              }
                              return _buildFrostedAction(
                                iconPath: 'assets/mensaje.svg',
                                countText: countText,
                                onTap: _onMessageButtonTap,
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          _buildFrostedAction(
                            iconPath: 'assets/icono-compartir.svg',
                            countText: '',
                            onTap: _onShareButtonTap,
                          ),
                          const SizedBox(width: 16),
                          _buildParticipantsCorner(),
                        ],
                      ),
                    ),
                  ),

                  // Texto: "X/Y participantes"
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        maxP > 0
                            ? '$totalP/$maxP participantes'
                            : '$totalP participantes',
                        style: TextStyle(
                          color: (isFull && maxP > 0)
                              ? Colors.redAccent
                              : Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  // plan.type y fecha/hora
                  if (dateText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            plan.type.isNotEmpty ? plan.type : 'Plan',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            dateText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
