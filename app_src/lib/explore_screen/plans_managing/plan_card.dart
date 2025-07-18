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
import '../../l10n/app_localizations.dart';
import 'join_state.dart';
import 'plan_chat_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

    // Si ya es participante
    if (widget.plan.participants?.contains(_currentUser!.uid) ?? false) {
      setState(() => _joinState = JoinState.joined);
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
      return;
    }

    final rejected = await FirebaseFirestore.instance
        .collection('notifications')
        .where('type', isEqualTo: 'join_rejected')
        .where('receiverId', isEqualTo: _currentUser!.uid)
        .where('planId', isEqualTo: widget.plan.id)
        .limit(1)
        .get();

    if (rejected.docs.isNotEmpty) {
      setState(() => _joinState = JoinState.rejected);
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

    final bool newLiked = !_liked;
    setState(() {
      _liked = newLiked;
      _likeCount = math.max(0, _likeCount + (newLiked ? 1 : -1));
    });

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(planRef);
      if (!snap.exists) return;

      int currentLikes = snap.data()?['likes'] ?? 0;
      if (newLiked) {
        currentLikes++;
      } else {
        currentLikes = currentLikes > 0 ? currentLikes - 1 : 0;
      }
      transaction.update(planRef, {'likes': currentLikes});
    });

    if (newLiked) {
      await userRef.update({
        'favourites': FieldValue.arrayUnion([widget.plan.id])
      });
    } else {
      await userRef.update({
        'favourites': FieldValue.arrayRemove([widget.plan.id])
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // (4) Botón "Unirse"
  // ─────────────────────────────────────────────────────────────
  Future<void> _onJoinTap() async {
    if (_currentUser == null) return;
    final plan = widget.plan;

    if (_joinState == JoinState.joined) {
      final confirm = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
                  title: const Text('¿Abandonar este plan?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('No')),
                    TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Sí')),
                  ],
                )) ??
          false;
      if (confirm) {
        await _leavePlan();
        setState(() => _joinState = JoinState.none);
      }
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
      await _cancelJoinRequest();
      setState(() => _joinState = JoinState.none);
    } else {
      await _createJoinRequest();
      setState(() => _joinState = JoinState.requested);
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

  Future<void> _leavePlan() async {
    if (_currentUser == null) return;
    final uid = _currentUser!.uid;
    try {
      final subs = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('userId', isEqualTo: uid)
          .where('id', isEqualTo: widget.plan.id)
          .get();
      for (final d in subs.docs) {
        await d.reference.delete();
      }
      await FirebaseFirestore.instance.collection('plans').doc(widget.plan.id).update({
        'participants': FieldValue.arrayRemove([uid]),
        'invitedUsers': FieldValue.arrayRemove([uid])
      });
      await PlanModel.updateUserHasActivePlan(uid);
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final leaverName = userDoc.data()?['name'] ?? 'Usuario';
        final leaverPhoto = userDoc.data()?['photoUrl'] ?? '';
        await FirebaseFirestore.instance.collection('notifications').add({
          'type': 'special_plan_left',
          'receiverId': widget.plan.createdBy,
          'senderId': uid,
          'senderName': leaverName,
          'senderProfilePic': leaverPhoto,
          'planId': widget.plan.id,
          'planType': widget.plan.type,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Has abandonado el plan ${widget.plan.type}.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al abandonar el plan.')),
      );
    }
  }

  Future<void> _removeParticipant(String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('plans')
          .doc(widget.plan.id)
          .update({
        'participants': FieldValue.arrayRemove([uid]),
        'removedParticipants': FieldValue.arrayUnion([uid])
      });
    } catch (e) {}

    try {
      final q = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('id', isEqualTo: widget.plan.id)
          .where('userId', isEqualTo: uid)
          .get();
      for (final d in q.docs) {
        await d.reference.delete();
      }
    } catch (e) {}

    // La notificación y el push serán generados por Cloud Functions
  }

  // ─────────────────────────────────────────────────────────────
  // (5) Abrir detalles del plan
  // ─────────────────────────────────────────────────────────────
  void _openPlanDetails(BuildContext context, PlanModel plan,
      {bool openChat = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FrostedPlanDialog(
          plan: plan,
          fetchParticipants: widget.fetchParticipants,
          openChat: openChat,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // (6) Popup Chat
  // ─────────────────────────────────────────────────────────────
  void _onMessageButtonTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanChatScreen(plan: widget.plan),
      ),
    );
  }

  Widget _buildChatPopup(PlanModel plan, ScrollController scrollController) {
    return Container(
        decoration: BoxDecoration(
          color: AppColors.shareSheetBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    Text(
                      AppLocalizations.of(context).planChat,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white),

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
                    return Center(
                      child: Text(
                          AppLocalizations.of(context).errorLoadingMessages,
                          style: const TextStyle(color: Colors.white)),
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(AppLocalizations.of(context).noMessagesYet,
                          style: const TextStyle(color: Colors.white)),
                    );
                  }
                  return ListView(
                    controller: scrollController,
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildMessageItem(data);
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
                        hintText: AppLocalizations.of(context).writeMessage,
                        filled: true,
                        fillColor: Colors.white10,
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
        ));
  }

  Widget _buildMessageItem(Map<String, dynamic> data) {
    final String text = data['text'] ?? '';
    final String senderName = data['senderName'] ?? 'Invitado';
    final String senderPic = data['senderPic'] ?? '';
    final String senderId = data['senderId'] ?? '';
    final Timestamp? ts = data['timestamp'] as Timestamp?;
    final String timeStr = _formatTimestamp(ts);

    final bool isMe = senderId == _currentUser?.uid;

    final avatar = GestureDetector(
      onTap: () {
        if (senderId.isNotEmpty && senderId != _currentUser?.uid) {
          UserInfoCheck.open(context, senderId);
        }
      },
      child: CircleAvatar(
        radius: 20,
        backgroundImage:
            senderPic.isNotEmpty ? CachedNetworkImageProvider(senderPic) : null,
        backgroundColor:
            senderPic.isNotEmpty ? Colors.blueGrey[100] : avatarColor(senderName),
        child: senderPic.isEmpty
            ? Text(
                getInitialsSync(senderName),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              )
            : null,
      ),
    );

    final nameWidget = GestureDetector(
      onTap: () {
        if (senderId.isNotEmpty && senderId != _currentUser?.uid) {
          UserInfoCheck.open(context, senderId);
        }
      },
      child: Text(
        senderName,
        textAlign: isMe ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    final msgWidget = Text(
      text,
      textAlign: isMe ? TextAlign.right : TextAlign.left,
      style: const TextStyle(color: Colors.white),
    );

    final timeWidget = Text(
      timeStr,
      style: const TextStyle(color: Colors.white70, fontSize: 12),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) avatar,
          if (!isMe) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                nameWidget,
                msgWidget,
                const SizedBox(height: 2),
                timeWidget,
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe) avatar,
        ],
      ),
    );
  }

  Future<void> _sendMessage(PlanModel plan) async {
    if (_currentUser == null) return;
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    // Solo el creador o un participante pueden comentar
    final uid = _currentUser!.uid;
    final isCreator = plan.createdBy == uid;
    final isParticipant = plan.participants?.contains(uid) ?? false;
    if (!isCreator && !isParticipant) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Debes participar en el plan para comentar.')),
      );
      return;
    }

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

    // Crear notificación para cada participante y creador (excepto el emisor)
    final planDoc =
        await FirebaseFirestore.instance.collection('plans').doc(plan.id).get();
    if (planDoc.exists && planDoc.data() != null) {
      final pdata = planDoc.data()!;
      final List<String> uids = List<String>.from(pdata['participants'] ?? []);
      final String creatorId = pdata['createdBy'] ?? '';
      if (!uids.contains(creatorId)) uids.add(creatorId);
      for (final uid in uids) {
        if (uid == _currentUser!.uid) continue;
        await FirebaseFirestore.instance.collection('notifications').add({
          'type': 'plan_chat_message',
          'receiverId': uid,
          'senderId': _currentUser!.uid,
          'senderName': senderName,
          'senderProfilePic': senderPic,
          'planId': plan.id,
          'planType': plan.type,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    }

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
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
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
  Widget _buildCreatorFrosted(String name, String? photoUrl, {String? coverUrl}) {
    final creatorUid = widget.plan.createdBy;
    final bool showActivity = widget.userData['activityStatusPublic'] != false;

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
              buildProfileAvatar(photoUrl,
                  coverUrl: coverUrl, userName: name),
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
                      Image.asset(
                        _getPrivilegeIcon(
                            widget.userData['privilegeLevel']?.toString() ??
                                'Básico'),
                        width: 14,
                        height: 14,
                      ),
                    ],
                  ),

                  // Solo el estado de actividad
                  if (creatorUid.isNotEmpty && showActivity)
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

  String _getPrivilegeIcon(String level) {
    final normalized = level.toLowerCase().replaceAll('á', 'a');
    switch (normalized) {
      case 'premium':
        return 'assets/icono-usuario-premium.png';
      case 'golden':
        return 'assets/icono-usuario-golden.png';
      case 'vip':
        return 'assets/icono-usuario-vip.png';
      default:
        return 'assets/icono-usuario-basico.png';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Participantes en la esquina
  // ─────────────────────────────────────────────────────────────
  Widget _buildParticipantsCorner() {
    final participants =
        _participants.where((p) => p['uid'] != widget.plan.createdBy).toList();
    if (participants.isEmpty) return const SizedBox.shrink();
    final count = participants.length;

    // Solo 1
    if (count == 1) {
      final p = participants[0];
      final pic = p['photoUrl'] ?? '';
      final name = p['name'] ?? 'Usuario';
      final uid = p['uid']?.toString() ?? '';
      final level = p['privilegeLevel']?.toString() ?? 'Básico';

      const int maxChars = 14;
      final truncated = _truncate(name, maxChars);

      return GestureDetector(
        onTap: () => _showParticipantsModal(participants),
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
                backgroundImage:
                    pic.isNotEmpty ? CachedNetworkImageProvider(pic) : null,
                backgroundColor:
                    pic.isNotEmpty ? Colors.blueGrey[400] : avatarColor(name),
                child: pic.isEmpty
                    ? Text(
                        getInitialsSync(name),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          truncated,
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Image.asset(
                        _getPrivilegeIcon(level),
                        width: 14,
                        height: 14,
                      ),
                    ],
                  ),
                  if (uid.isNotEmpty) UserActivityStatus(userId: uid),
                ],
              ),
            ],
          ),
        ),
      );
    }
    // Si hay 2 o más
    else {
      final p1 = participants[0];
      final p2 = participants[1];
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
        onTap: () => _showParticipantsModal(participants),
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
                  backgroundImage:
                      pic1.isNotEmpty ? CachedNetworkImageProvider(pic1) : null,
                  backgroundColor:
                      pic1.isNotEmpty ? Colors.blueGrey[400] : avatarColor(p1['name'] ?? ''),
                  child: pic1.isEmpty
                      ? Text(
                          getInitialsSync(p1['name'] ?? ''),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
              ),
              Positioned(
                left: overlapOffset,
                child: CircleAvatar(
                  radius: avatarSize / 2,
                  backgroundImage:
                      pic2.isNotEmpty ? CachedNetworkImageProvider(pic2) : null,
                  backgroundColor:
                      pic2.isNotEmpty ? Colors.blueGrey[400] : avatarColor(p2['name'] ?? ''),
                  child: pic2.isEmpty
                      ? Text(
                          getInitialsSync(p2['name'] ?? ''),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
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
    // Revisamos quién ha hecho check-in (solo planes generales)
    List checkedInUsers = [];
    if (widget.plan.special_plan != 1) {
      try {
        final planSnap = await FirebaseFirestore.instance
            .collection('plans')
            .doc(widget.plan.id)
            .get();
        final planData = planSnap.data();
        checkedInUsers = planData?['checkedInUsers'] ?? [];
      } catch (e) {}
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
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).participantsTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.close, color: AppColors.planColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.planColor),

                // Lista
                Expanded(
                  child: ListView.builder(
                    itemCount: participants.length,
                    itemBuilder: (ctx, i) {
                      final p = participants[i];
                      final pic = p['photoUrl'] ?? '';
                      final name = p['name'] ?? 'Usuario';
                      final uid = p['uid']?.toString() ?? '';

                      final bool isCheckedIn = checkedInUsers.contains(uid);

                      final tile = ListTile(
                        onTap: () {
                          if (uid.isEmpty || uid == _currentUser?.uid) return;
                          UserInfoCheck.open(context, uid);
                        },
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundImage:
                              pic.isNotEmpty ? CachedNetworkImageProvider(pic) : null,
                          backgroundColor:
                              pic.isNotEmpty ? Colors.blueGrey[400] : avatarColor(name),
                          child: pic.isEmpty
                              ? Text(
                                  getInitialsSync(name),
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Image.asset(
                              _getPrivilegeIcon(
                                  p['privilegeLevel']?.toString() ?? 'Básico'),
                              width: 14,
                              height: 14,
                            ),
                          ],
                        ),
                        subtitle: uid.isNotEmpty
                            ? UserActivityStatus(userId: uid)
                            : null,
                        trailing: (widget.plan.special_plan != 1 && isCheckedIn)
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  AppLocalizations.of(context).attends,
                                  style: const TextStyle(
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      );

                      final isCreator =
                          widget.plan.createdBy == _currentUser?.uid;
                      if (isCreator && uid != widget.plan.createdBy) {
                        return Dismissible(
                          key: Key(uid),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Eliminar participante'),
                                    content:
                                        Text('¿Eliminar a $name del plan?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text('No'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('Sí'),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                          },
                          onDismissed: (_) => _removeParticipant(uid),
                          child: tile,
                        );
                      } else {
                        return tile;
                      }
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
    if (isFull && _joinState != JoinState.joined) {
      // Cupo completo => texto
      return ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.black.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              AppLocalizations.of(context).fullCapacity,
              style: const TextStyle(
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
      Widget iconWidget;
      switch (_joinState) {
        case JoinState.none:
          buttonText = AppLocalizations.of(context).join;
          iconWidget = SvgPicture.asset(
            'assets/union.svg',
            width: 20,
            height: 20,
            color: Colors.white,
          );
          break;
        case JoinState.requested:
          buttonText = AppLocalizations.of(context).joinRequested;
          iconWidget = SvgPicture.asset(
            'assets/union.svg',
            width: 20,
            height: 20,
            color: Colors.white,
          );
          break;
        case JoinState.joined:
          buttonText = AppLocalizations.of(context).leavePlan;
          iconWidget = const Icon(Icons.exit_to_app, color: Colors.white, size: 20);
          break;
        case JoinState.rejected:
          buttonText = AppLocalizations.of(context).joinRejected;
          iconWidget = const Icon(Icons.close, color: Colors.white, size: 20);
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
                  iconWidget,
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
        // Contamos solo los participantes reales (sin incluir al creador)
        final totalP = widget.plan.participants?.length ?? 0;
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
                          onTap: () async {
                            final creatorUid = plan.createdBy;
                            final currentUid =
                                FirebaseAuth.instance.currentUser?.uid;
                            if (creatorUid.isNotEmpty &&
                                creatorUid != currentUid) {
                              await UserInfoCheck.open(context, creatorUid);
                              if (mounted) setState(() {});
                            }
                          },
                          child: _buildCreatorFrosted(
                            name,
                            fallbackPhotoUrl,
                            coverUrl: widget.userData['coverPhotoUrl']?.toString(),
                          ),
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
                              child: CachedNetworkImage(
                                imageUrl: plan.backgroundImage!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Center(
                                    child: CircularProgressIndicator()),
                                errorWidget: (_, __, ___) => buildPlaceholder(),
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
                    padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                    child: Builder(
                      builder: (context) {
                        final textScale =
                            MediaQuery.of(context).textScaleFactor;
                        final actions = FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              _buildFrostedAction(
                                iconPath: 'assets/corazon.svg',
                                countText: '$_likeCount',
                                onTap: _toggleLike,
                                iconColor: _liked ? Colors.red : Colors.white,
                              ),
                              const SizedBox(width: 8),
                              StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('plans')
                                    .doc(plan.id)
                                    .snapshots(),
                                builder: (ctx, snap) {
                                  final data = snap.data?.data()
                                          as Map<String, dynamic>? ??
                                      {};
                                  return _buildFrostedAction(
                                    iconPath: 'assets/mensaje.svg',
                                    countText: '${data['commentsCount'] ?? 0}',
                                    onTap: _onMessageButtonTap,
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('plans')
                                    .doc(plan.id)
                                    .snapshots(),
                                builder: (ctx, snap) {
                                  final data = snap.data?.data()
                                          as Map<String, dynamic>? ??
                                      {};
                                  return _buildFrostedAction(
                                    iconPath: 'assets/icono-compartir.svg',
                                    countText: '${data['share_count'] ?? 0}',
                                    onTap: _onShareButtonTap,
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('plans')
                                    .doc(plan.id)
                                    .snapshots(),
                                builder: (ctx, snap) {
                                  final data = snap.data?.data()
                                          as Map<String, dynamic>? ??
                                      {};
                                  return _buildFrostedAction(
                                    iconPath: 'assets/icono-ojo.svg',
                                    countText: '${data['views'] ?? 0}',
                                    onTap: () {},
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                        final corner = _buildParticipantsCorner();
                        return Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            actions,
                            corner,
                          ],
                        );
                      },
                    ),
                  ),
                  // Texto: "X/Y participantes"
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        maxP > 0
                            ? '$totalP/$maxP ${AppLocalizations.of(context).participants}'
                            : '$totalP ${AppLocalizations.of(context).participants}',
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
                  if (dateText.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            plan.type.isNotEmpty ? plan.type : 'Plan',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
