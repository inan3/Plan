import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/plan_model.dart';
import '../../main/colors.dart';
import 'users_grid_helpers.dart'; // Para buildPlaceholder, buildProfileAvatar, etc.
import 'plan_share_sheet.dart';
import '../users_managing/user_info_check.dart';
import '../users_managing/frosted_plan_dialog_state.dart';

/// Esta clase es la tarjeta que muestra cada Plan de un usuario.
class PlanCard extends StatefulWidget {
  final PlanModel plan;
  final Map<String, dynamic> userData;
  final Future<List<Map<String, dynamic>>> Function(PlanModel plan) fetchParticipants;

  /// Nueva propiedad:
  final bool hideJoinButton;

  const PlanCard({
    Key? key,
    required this.plan,
    required this.userData,
    required this.fetchParticipants,
    this.hideJoinButton = false, // por defecto, NO se oculta
  }) : super(key: key);

  @override
  State<PlanCard> createState() => PlanCardState();
}

class PlanCardState extends State<PlanCard> {
  bool _liked = false;
  int _likeCount = 0;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  late Future<List<Map<String, dynamic>>> _futureParticipants;
  late List<Map<String, dynamic>> _participants;

  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _likeCount = widget.plan.likes;
    _checkIfLiked();
    _futureParticipants = widget.fetchParticipants(widget.plan);
    _participants = [];
  }

  //--------------------------------------------------------------------------
  // Chequea si el plan ya fue marcado como favorito por el usuario actual.
  //--------------------------------------------------------------------------
  Future<void> _checkIfLiked() async {
    final user = _currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      final data = userDoc.data()!;
      final favs = data['favourites'] as List<dynamic>? ?? [];
      if (favs.contains(widget.plan.id)) {
        setState(() => _liked = true);
      }
    }
  }

  //--------------------------------------------------------------------------
  // Alterna el “me gusta” de este plan, actualizando Firestore y usuario.
  //--------------------------------------------------------------------------
  Future<void> _toggleLike() async {
    final user = _currentUser;
    if (user == null) return;

    final planRef = FirebaseFirestore.instance.collection('plans').doc(widget.plan.id);
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

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
      setState(() {
        _likeCount = currentLikes;
      });
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

  //--------------------------------------------------------------------------
  // El botón "Unirse" a un plan público o mandar solicitud a un plan privado.
  //--------------------------------------------------------------------------
  Future<void> _onJoinTap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // No hay usuario logueado

    final plan = widget.plan;

    // Si es su propio plan
    if (plan.createdBy == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes unirte a tu propio plan')),
      );
      return;
    }

    // Si ya está suscrito
    if (plan.participants?.contains(user.uid) ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Ya estás suscrito a este plan!')),
      );
      return;
    }

    // Revisar cupo
    final int participantes = plan.participants?.length ?? 0;
    final int maxPart = plan.maxParticipants ?? 0;
    if (maxPart > 0 && participantes >= maxPart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El cupo máximo de participantes para este plan está cubierto'),
        ),
      );
      return;
    }

    // Privado vs público
    final bool isPlanPrivate = (plan.creatorProfilePrivacy ?? 0) == 1;
    if (isPlanPrivate) {
      // Notificación
      final planType = plan.type.isNotEmpty ? plan.type : 'Plan';
      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'join_request',
        'receiverId': plan.createdBy,
        'senderId': user.uid,
        'planId': plan.id,
        'planType': planType,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu solicitud de unión se ha enviado con éxito.'),
        ),
      );
    } else {
      // Público => se une
      final planRef = FirebaseFirestore.instance.collection('plans').doc(plan.id);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snap = await transaction.get(planRef);
        if (!snap.exists) return;
        final data = snap.data()!;
        final participantsList = List<String>.from(data['participants'] ?? []);
        if (!participantsList.contains(user.uid)) {
          participantsList.add(user.uid);
        }
        transaction.update(planRef, {'participants': participantsList});
      });

      // Añadir doc en 'subscriptions'
      await FirebaseFirestore.instance.collection('subscriptions').add({
        'id': plan.id,
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Te uniste al plan ${plan.type}.')),
      );
    }
  }

  //--------------------------------------------------------------------------
  // Muestra el diálogo con detalles del plan (FrostedPlanDialog).
  //--------------------------------------------------------------------------
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

  //--------------------------------------------------------------------------
  // Cuando se presiona el ícono de mensaje, abrimos un popup de chat
  //--------------------------------------------------------------------------
  void _onMessageButtonTap() {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.25,
            left: 0,
            right: 0,
            bottom: 0,
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

  //--------------------------------------------------------------------------
  // Popup de chat con los mensajes del plan
  //--------------------------------------------------------------------------
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
                  final timeStr = formatTimestamp(ts);

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

        // Caja de texto para enviar mensaje
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

  //--------------------------------------------------------------------------
  // Envía un mensaje al chat del plan
  //--------------------------------------------------------------------------
  void _sendMessage(PlanModel plan) async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _currentUser == null) return;

    String senderName = _currentUser!.uid;
    String senderPic = '';
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .get();
    if (userDoc.exists && userDoc.data() != null) {
      final data = userDoc.data()!;
      senderPic = data['photoUrl'] ?? '';
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

    final planRef = FirebaseFirestore.instance.collection('plans').doc(plan.id);
    await planRef.update({
      'commentsCount': FieldValue.increment(1),
    }).catchError((_) {
      planRef.set({'commentsCount': 1}, SetOptions(merge: true));
    });
    _chatController.clear();
  }

  //--------------------------------------------------------------------------
  // Comparte el plan con otras apps
  //--------------------------------------------------------------------------
  void _onShareButtonTap() {
    _openCustomShareModal(widget.plan);
  }

  //--------------------------------------------------------------------------
  // Abre el "BottomSheet" para compartir el plan con seguidores/seguidos
  //--------------------------------------------------------------------------
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
          builder: (BuildContext context, ScrollController scrollController) {
            return PlanShareSheet(
              plan: plan,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  //--------------------------------------------------------------------------
  // Muestra los Avatares de los participantes en la esquina (en la parte de abajo)
  //--------------------------------------------------------------------------
  Widget _buildParticipantsCorner() {
    if (_participants.isEmpty) return const SizedBox.shrink();
    final count = _participants.length;

    // Caso 1: Sólo 1 participante
    if (count == 1) {
      final p = _participants[0];
      final pic = p['photoUrl'] ?? '';
      String name = p['name'] ?? 'Usuario';
      final age = p['age']?.toString() ?? '';

      String displayText = '$name, $age';
      if (displayText.length > 10) {
        displayText = displayText.substring(0, 14) + '...';
      }

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
              Text(
                displayText,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    // Caso 2: Más de 1 participante
    else {
      final p1 = _participants[0];
      final p2 = _participants[1];
      final pic1 = p1['photoUrl'] ?? '';
      final pic2 = p2['photoUrl'] ?? '';
      final extras = count - 2;
      final bool hasExtras = extras > 0;

      const double avatarSize = 40;
      const double overlapOffset = 24;
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
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '+$extras',
                            style: const TextStyle(color: Colors.white),
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

  //--------------------------------------------------------------------------
  // Muestra un modal con la lista de participantes
  //--------------------------------------------------------------------------
  void _showParticipantsModal(List<Map<String, dynamic>> participants) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.25,
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
                  padding: const EdgeInsets.all(16.0),
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
                Expanded(
                  child: ListView.builder(
                    itemCount: participants.length,
                    itemBuilder: (ctx, i) {
                      final p = participants[i];
                      final pic = p['photoUrl'] ?? '';
                      final name = p['name'] ?? 'Usuario';
                      final age = p['age']?.toString() ?? '';
                      final uid = p['uid']?.toString() ?? '';

                      return ListTile(
                        onTap: () {
                          if (uid.isEmpty || uid == _currentUser?.uid) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserInfoCheck(userId: uid),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundImage: (pic.isNotEmpty ? NetworkImage(pic) : null),
                          backgroundColor: Colors.blueGrey[400],
                        ),
                        title: Text(
                          '$name, $age',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  //--------------------------------------------------------------------------
  // Formatea timestamp (hora y minuto)
  //--------------------------------------------------------------------------
  String formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final String name = widget.userData['name']?.toString().trim() ?? 'Usuario';
    final String userHandle = widget.userData['handle']?.toString() ?? '@usuario';
    final String? fallbackPhotoUrl = widget.userData['photoUrl']?.toString();

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
                  // Info superior (creador + botón Unirse)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            final creatorUid = plan.createdBy;
                            if (creatorUid.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserInfoCheck(userId: creatorUid),
                                ),
                              );
                            }
                          },
                          child: _buildCreatorFrosted(name, userHandle, fallbackPhotoUrl),
                        ),
                        const Spacer(),
                        _buildJoinFrosted(),
                      ],
                    ),
                  ),

                  // Imagen del plan
                  GestureDetector(
                    onTap: () => _openPlanDetails(context, plan),
                    child: (plan.backgroundImage != null && plan.backgroundImage!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 16 / 13,
                              child: Image.network(
                                plan.backgroundImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => buildPlaceholder(),
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

                  // Botones (like, chat, compartir, participantsCorner)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 8),
                    child: Row(
                      children: [
                        _buildFrostedAction(
                          iconPath: 'assets/corazon.svg',
                          countText: '$_likeCount',
                          onTap: _toggleLike,
                          iconColor: _liked ? Colors.red : Colors.white,
                        ),
                        const SizedBox(width: 16),
                        // Contador de comentarios
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('plans')
                              .doc(plan.id)
                              .snapshots(),
                          builder: (ctx, snapMsg) {
                            String countText = '0';
                            if (snapMsg.hasData && snapMsg.data!.exists) {
                              final d = snapMsg.data!.data() as Map<String, dynamic>;
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
                        const Spacer(),
                        _buildParticipantsCorner(),
                      ],
                    ),
                  ),

                  // Texto: X/Y participantes
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        maxP > 0 ? '$totalP/$maxP participantes' : '$totalP participantes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  // Descripción
                  if (plan.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: plan.type.isNotEmpty ? plan.type : 'Plan',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: ': ${plan.description}'),
                          ],
                        ),
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

  //--------------------------------------------------------------------------
  // Creador Frosted
  //--------------------------------------------------------------------------
  Widget _buildCreatorFrosted(String name, String handle, String? photoUrl) {
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
              buildProfileAvatar(photoUrl),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Text(
                    handle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Botón Unirse (frosted) en la esquina superior
  //--------------------------------------------------------------------------
  Widget _buildJoinFrosted() {
  if (widget.hideJoinButton) {
    // Si nos piden ocultarlo, devolvemos un espacio en blanco (o nada).
    return const SizedBox.shrink();
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
              const Text(
                'Unirse',
                style: TextStyle(
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


  //--------------------------------------------------------------------------
  // Botón Frosted de corazon, chat, compartir...
  //--------------------------------------------------------------------------
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
}
