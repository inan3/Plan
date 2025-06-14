// frosted_plan_dialog_state.dart
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/plan_model.dart';
import '../users_managing/user_info_check.dart';
import 'attendance_managing.dart';
import '../../main/colors.dart';
import '../profile/profile_screen.dart';

class FrostedPlanDialog extends StatefulWidget {
  final PlanModel plan;
  final Future<List<Map<String, dynamic>>> Function(PlanModel plan)
      fetchParticipants;
  final bool openChat;

  const FrostedPlanDialog({
    Key? key,
    required this.plan,
    required this.fetchParticipants,
    this.openChat = false,
  }) : super(key: key);

  @override
  State<FrostedPlanDialog> createState() => _FrostedPlanDialogState();
}

class _FrostedPlanDialogState extends State<FrostedPlanDialog> {
  late Future<List<Map<String, dynamic>>> _futureParticipants;
  final TextEditingController _chatController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String? _creatorAge;
  String? _creatorPhotoUrl;
  bool _liked = false;
  int _likeCount = 0;

  late PageController _pageController;
  int _currentPageIndex = 0;

  Future<void> _incrementViewCount() async {
    final user = _currentUser;
    if (user == null) return;
    if (user.uid == widget.plan.createdBy) return;
    final planRef =
        FirebaseFirestore.instance.collection('plans').doc(widget.plan.id);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(planRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final viewedBy = List<String>.from(data['viewedBy'] ?? []);
      if (!viewedBy.contains(user.uid)) {
        tx.update(planRef, {
          'views': (data['views'] ?? 0) + 1,
          'viewedBy': FieldValue.arrayUnion([user.uid])
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _futureParticipants = widget.fetchParticipants(widget.plan);
    _likeCount = widget.plan.likes;
    _creatorPhotoUrl = widget.plan.creatorProfilePic;
    _checkIfLiked();
    _fetchCreatorInfo();
    _pageController = PageController();
    _incrementViewCount();
    if (widget.openChat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            insetPadding: EdgeInsets.only(
              top: MediaQuery.of(context).size.height * 0.25,
              left: 0,
              right: 0,
              bottom: 0,
            ),
            backgroundColor: AppColors.lightTurquoise,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: _buildChatPopup(widget.plan),
          ),
        );
      });
    }
  }

  Future<void> _fetchCreatorInfo() async {
    if (widget.plan.createdBy.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.plan.createdBy)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final ageCreador = data['age']?.toString() ?? '';
        setState(() {
          widget.plan.creatorName = data['name'] ?? 'Creador';
          widget.plan.creatorProfilePic = data['photoUrl'] ?? '';
          _creatorPhotoUrl = widget.plan.creatorProfilePic;
          _creatorAge = ageCreador;
        });
      }
    } catch (e) {
    }
  }

  Future<void> _checkIfLiked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await userRef.get();
    if (!snapshot.exists || snapshot.data() == null) return;

    final data = snapshot.data() as Map<String, dynamic>;
    final favourites = data['favourites'] as List<dynamic>? ?? [];
    if (favourites.contains(widget.plan.id)) {
      setState(() => _liked = true);
    }
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _buildLocationArea(PlanModel plan) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/icono-ubicacion.svg',
                        width: 18,
                        height: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Ubicación",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    plan.location,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (plan.latitude != null && plan.longitude != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 240,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(plan.latitude!, plan.longitude!),
                            zoom: 16,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('plan_location'),
                              position: LatLng(plan.latitude!, plan.longitude!),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueBlue,
                              ),
                            ),
                          },
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          liteModeEnabled: true,
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Ubicación no disponible",
                        style: TextStyle(
                          color: Color.fromARGB(255, 151, 121, 215),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoBox(PlanModel plan) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/icono-id-plan.svg',
                        width: 18,
                        height: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          "Información adicional",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "ID del Plan: ${plan.id}",
                          style: const TextStyle(
                            color: Color.fromARGB(255, 212, 211, 211),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.copy,
                          color: Color.fromARGB(255, 203, 202, 206),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: plan.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ID copiado al portapapeles'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (plan.special_plan != 1)
                    Text(
                      "Restricción de edad: ${plan.minAge} - ${plan.maxAge} años",
                      style: const TextStyle(
                        color: Color.fromARGB(255, 212, 211, 211),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 25),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SvgPicture.asset(
                        'assets/icono-calendario.svg',
                        width: 16,
                        height: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Fecha de inicio: ${plan.formattedDate(plan.startTimestamp)}",
                          style: const TextStyle(
                            color: Color.fromARGB(255, 219, 218, 218),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (plan.finishTimestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(width: 21),
                          Expanded(
                            child: Text(
                              "Finaliza: ${plan.formattedDate(plan.finishTimestamp)}",
                              style: const TextStyle(
                                color: Color.fromARGB(255, 219, 218, 218),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
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
              color: Colors.black.withOpacity(0.2),
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

  Widget _buildLikeButton() {
    return _buildActionButton(
      iconPath: 'assets/corazon.svg',
      countText: _likeCount.toString(),
      onTap: _toggleLike,
      iconColor: _liked ? Colors.red : Colors.white,
    );
  }

  Widget _buildMessageButton(PlanModel plan) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('plans').doc(plan.id).snapshots(),
      builder: (context, snapshot) {
        String countText = '0';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final count = data['commentsCount'] ?? 0;
          countText = count.toString();
        }
        return _buildActionButton(
          iconPath: 'assets/mensaje.svg',
          countText: countText,
          onTap: () {
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
                  backgroundColor: AppColors.lightTurquoise,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _buildChatPopup(plan),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildShareButton(PlanModel plan) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('plans')
          .doc(plan.id)
          .snapshots(),
      builder: (context, snapshot) {
        String countText = '0';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final count = data['share_count'] ?? 0;
          countText = count.toString();
        }
        return _buildActionButton(
          iconPath: 'assets/icono-compartir.svg',
          countText: countText,
          onTap: () => _openCustomShareModal(plan),
        );
      },
    );
  }

  Widget _buildViewButton(PlanModel plan) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('plans')
          .doc(plan.id)
          .snapshots(),
      builder: (context, snapshot) {
        String countText = '0';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final count = data['views'] ?? 0;
          countText = count.toString();
        }
        return _buildActionButton(
          iconPath: 'assets/icono-ojo.svg',
          countText: countText,
          onTap: () {},
        );
      },
    );
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
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 35, 57, 80),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white54,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Text(
                          "Compartir con otras apps",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.white),
                          onPressed: () {
                            final shareUrl =
                                'https://plan-social-app.web.app/plan?planId=${plan.id}';
                            final shareText =
                                '¡Mira este plan!\n\nTítulo: ${plan.type}\nDescripción: ${plan.description}\n$shareUrl';
                            Share.share(shareText);
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _CustomShareDialogContent(
                      plan: plan,
                      scrollController: scrollController,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButtonsRow(PlanModel plan) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLikeButton(),
        const SizedBox(width: 8),
        _buildMessageButton(plan),
        const SizedBox(width: 8),
        _buildShareButton(plan),
        const SizedBox(width: 8),
        _buildViewButton(plan),
      ],
    );
  }

  Widget _buildJoinButton(PlanModel plan) {
    final pCount = plan.participants?.length ?? 0;
    final maxP = plan.maxParticipants ?? 0;
    final bool isFull = (maxP > 0 && pCount >= maxP);

    if (isFull) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: const Text(
            "Cupo completo",
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        if (plan.createdBy == user.uid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No puedes unirte a tu propio plan')),
          );
          return;
        }
        if (plan.participants?.contains(user.uid) ?? false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Ya estás suscrito a este plan!')),
          );
          return;
        }
        if (maxP > 0 && pCount >= maxP) {
          return;
        }

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
          const SnackBar(content: Text('¡Tu solicitud de unión se ha enviado!')),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                "Únete ahora",
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatPopup(PlanModel plan) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const SizedBox(width: 48),
              const Expanded(
                child: Text(
                  "Chat del Plan",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.planColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.planColor),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(color: AppColors.planColor),
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
                      style: TextStyle(color: Colors.black)),
                );
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text('No hay mensajes todavía',
                      style: TextStyle(color: Colors.black)),
                );
              }
              return ListView(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildMessageItem(data);
                }).toList(),
              );
            },
          ),
        ),
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
                    fillColor: const ui.Color.fromARGB(255, 177, 177, 177),
                    hintStyle: const TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.planColor),
                onPressed: () => _sendMessage(plan),
              ),
            ],
          ),
        ),
      ],
    );
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
        backgroundImage: senderPic.isNotEmpty ? NetworkImage(senderPic) : null,
        backgroundColor: Colors.blueGrey[100],
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
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );

    final msgWidget = Text(
      text,
      textAlign: isMe ? TextAlign.right : TextAlign.left,
      style: const TextStyle(color: Colors.black, fontSize: 13),
    );

    final timeWidget = Text(
      timeStr,
      style: const TextStyle(color: Colors.black54, fontSize: 12),
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

  void _sendMessage(PlanModel plan) async {
    if (_currentUser == null) return;
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    // Solo participantes o el creador pueden enviar mensajes
    final uid = _currentUser!.uid;
    final isCreator = plan.createdBy == uid;
    final isParticipant = plan.participants?.contains(uid) ?? false;
    if (!isCreator && !isParticipant) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes participar en el plan para comentar.')),
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

    // Notificaciones para participantes y creador
    final planDoc = await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .get();
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

    final planRef = FirebaseFirestore.instance.collection('plans').doc(plan.id);
    await planRef.update({
      'commentsCount': FieldValue.increment(1),
    }).catchError((_) {
      planRef.set({'commentsCount': 1}, SetOptions(merge: true));
    });

    _chatController.clear();
  }

  Future<void> _removeParticipant(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('plans').doc(widget.plan.id).update({
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

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final creatorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final senderName = creatorDoc.data()?['name'] ?? '';
        final senderPhoto = creatorDoc.data()?['photoUrl'] ?? '';
        final planType =
            widget.plan.type.isNotEmpty ? widget.plan.type : 'Plan';

        await FirebaseFirestore.instance.collection('notifications').add({
          'type': 'removed_from_plan',
          'receiverId': uid,
          'senderId': currentUser.uid,
          'planId': widget.plan.id,
          'planType': planType,
          'senderProfilePic': senderPhoto,
          'senderName': senderName,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (e) {}
  }

  Widget _buildParticipantsCorner(List<Map<String, dynamic>> participants) {
    final count = participants.length;
    if (count == 0) {
      return const SizedBox.shrink();
    }

    if (count == 1) {
      final p = participants[0];
      final pic = p['photoUrl'] ?? '';
      String name = p['name'] ?? 'Usuario';
      final age = p['age']?.toString() ?? '';

      String displayText = '$name, $age';
      if (displayText.length > 10) {
        final cut = math.min(displayText.length, 14);
        displayText = '${displayText.substring(0, cut)}...';
      }

      return GestureDetector(
        onTap: () async {
          await _showParticipantsModal(participants);
          if (mounted) setState(() {});
        },
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
    } else {
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
        onTap: () async {
          await _showParticipantsModal(participants);
          if (mounted) setState(() {});
        },
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

  Future<void> _showParticipantsModal(
      List<Map<String, dynamic>> participants) async {
    List checkedInUsers = [];
    try {
      final planSnap = await FirebaseFirestore.instance
          .collection('plans')
          .doc(widget.plan.id)
          .get();
      final planData = planSnap.data();
      checkedInUsers = planData?['checkedInUsers'] ?? [];
    } catch (e) {
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
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
                const Divider(color: AppColors.planColor),
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

                      final tile = ListTile(
                        onTap: () {
                          if (uid.isEmpty || uid == _currentUser?.uid) return;
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

                      final isCreator = widget.plan.createdBy == _currentUser?.uid;
                      if (isCreator && uid != widget.plan.createdBy) {
                        return Dismissible(
                          key: Key(uid),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Eliminar participante'),
                                    content: Text('¿Eliminar a $name del plan?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, false),
                                        child: const Text('No'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('Sí'),
                                      ),
                                    ],
                                  ),
                                ) ?? false;
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

  Widget _buildMediaCarousel({
    required List<String> images,
    required String? videoUrl,
  }) {
    final totalMedia =
        images.length + ((videoUrl?.isNotEmpty ?? false) ? 1 : 0);
    final originalImages = widget.plan.originalImages?.isNotEmpty == true
        ? widget.plan.originalImages!
        : images;

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.95,
      height: 300,
      child: PageView.builder(
        controller: _pageController,
        itemCount: totalMedia,
        onPageChanged: (index) {
          setState(() => _currentPageIndex = index);
        },
        itemBuilder: (context, index) {
          if (index < images.length) {
            final imageUrl = images[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenGalleryPage(
                      images: originalImages,
                      initialIndex: index,
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            );
          } else {
            return ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildMediaSection(
    PlanModel plan,
    List<Map<String, dynamic>> participants, {
    required bool isUserCreator,
  }) {
    final images = plan.images ?? [];
    final video = plan.videoUrl ?? '';
    final totalMedia = images.length + (video.isNotEmpty ? 1 : 0);

    Widget mediaContent;
    if (totalMedia == 0) {
      mediaContent = Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.black54,
        ),
        child: const Center(
          child: Text('Sin contenido multimedia',
              style: TextStyle(color: Colors.white)),
        ),
      );
    } else {
      mediaContent = _buildMediaCarousel(images: images, videoUrl: video);
    }

    Widget pageIndicator = const SizedBox.shrink();
    if (totalMedia > 1) {
      pageIndicator = Padding(
        padding: const EdgeInsets.only(top: 5, bottom: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalMedia, (i) {
            final isActive = (i == _currentPageIndex);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.grey,
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      );
    }

    return Column(
      children: [
        mediaContent,
        pageIndicator,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildActionButtonsRow(plan),
                ),
              ),
              const SizedBox(width: 8),
              _buildParticipantsCorner(participants),
            ],
          ),
        ),
        if (!isUserCreator)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: _buildJoinButton(plan),
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderRow() {
    final String name = widget.plan.creatorName ?? 'Creador';
    final String age = _creatorAge ?? '';
    return GestureDetector(
      onTap: () async {
        final creatorUid = widget.plan.createdBy;
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        if (creatorUid.isNotEmpty && creatorUid != currentUid) {
          await UserInfoCheck.open(context, creatorUid);
          if (mounted) await _fetchCreatorInfo();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blueGrey[400],
              child: ClipOval(
                child: (_creatorPhotoUrl?.isNotEmpty ?? false)
                    ? CachedNetworkImage(
                        imageUrl: _creatorPhotoUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.person, color: Colors.white),
                      )
                    : const Icon(Icons.person, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                age.isNotEmpty ? '$name, $age' : name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final bool isUserCreator =
        (_currentUser != null && _currentUser!.uid == plan.createdBy);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 13, 32, 53),
              Color.fromARGB(255, 72, 38, 38),
              Color(0xFF12232E),
            ],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _futureParticipants,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              final allParts = snapshot.data ?? [];

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeaderRow(),
                    if (plan.special_plan != 1)
                      _buildMediaSection(
                        plan,
                        allParts,
                        isUserCreator: isUserCreator,
                      )
                    else
                      const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.95,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Text(
                                      plan.type,
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    plan.description,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildLocationArea(plan),
                    const SizedBox(height: 16),
                    _buildAdditionalInfoBox(plan),
                    const SizedBox(height: 16),
                    _buildCheckInArea(plan, allParts, isUserCreator),
                    const SizedBox(height: 30),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCheckInArea(
    PlanModel plan,
    List<Map<String, dynamic>> participants,
    bool isCreator,
  ) {
    final bool isParticipant =
        participants.any((p) => p['uid'] == _currentUser?.uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('plans').doc(plan.id).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }
        final data = snap.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        final checkInActive = data['checkInActive'] ?? false;
        final checkedIn = data['checkedInUsers'] ?? [];
        final bool alreadyCheckedIn =
            (checkedIn as List).contains(_currentUser?.uid ?? '');

        final bool isPlanFinished = plan.finishTimestamp != null &&
            plan.finishTimestamp!.isBefore(DateTime.now());

        if (alreadyCheckedIn) {
          return Container(
            width: MediaQuery.of(context).size.width * 0.95,
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: const [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 32),
                SizedBox(height: 8),
                Text(
                  "Tu asistencia se ha confirmado con éxito.\n¡Disfruta del evento!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }

        if (isCreator) {
          if (isPlanFinished) {
            return const SizedBox.shrink();
          }
          if (!checkInActive) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  await AttendanceManaging.startCheckIn(plan.id);
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CheckInCreatorScreen(planId: plan.id),
                    ),
                  );
                },
                child: const Text("Iniciar Check-in"),
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CheckInCreatorScreen(planId: plan.id),
                        ),
                      );
                    },
                    child: const Text("Ver Check-in (QR)"),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      await AttendanceManaging.finalizeCheckIn(plan.id);
                    },
                    child: const Text("Finalizar Check-in"),
                  ),
                ],
              ),
            );
          }
        } else {
          if (!isParticipant) {
            return const SizedBox.shrink();
          }
          if (checkInActive) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CheckInParticipantScreen(planId: plan.id),
                    ),
                  );
                },
                child: const Text("Confirmar asistencia"),
              ),
            );
          } else {
            return const SizedBox.shrink();
          }
        }
      },
    );
  }
}

extension LikeLogic on _FrostedPlanDialogState {
  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final planRef =
        FirebaseFirestore.instance.collection('plans').doc(widget.plan.id);
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(planRef);
      if (!snap.exists) return;
      int currentLikes = snap.data()?['likes'] ?? 0;
      if (!_liked) {
        currentLikes++;
      } else {
        currentLikes = currentLikes > 0 ? currentLikes - 1 : 0;
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
    setState(() {
      _liked = !_liked;
    });
  }
}

class _CustomShareDialogContent extends StatefulWidget {
  final PlanModel plan;
  final ScrollController scrollController;

  const _CustomShareDialogContent({
    Key? key,
    required this.plan,
    required this.scrollController,
  }) : super(key: key);

  @override
  State<_CustomShareDialogContent> createState() =>
      _CustomShareDialogContentState();
}

class _CustomShareDialogContentState extends State<_CustomShareDialogContent> {
  final TextEditingController _searchController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  final Set<String> _selectedUsers = {};

  @override
  void initState() {
    super.initState();
    _fetchFollowersAndFollowing();
  }

  Future<void> _fetchFollowersAndFollowing() async {
    if (_currentUser == null) return;
    try {
      final snapFollowers = await FirebaseFirestore.instance
          .collection('followers')
          .where('userId', isEqualTo: _currentUser!.uid)
          .get();
      final followerUids = <String>[];
      for (var doc in snapFollowers.docs) {
        final data = doc.data();
        final fid = data['followerId'] as String?;
        if (fid != null) followerUids.add(fid);
      }

      final snapFollowing = await FirebaseFirestore.instance
          .collection('followed')
          .where('userId', isEqualTo: _currentUser!.uid)
          .get();
      final followedUids = <String>[];
      for (var doc in snapFollowing.docs) {
        final data = doc.data();
        final fid = data['followedId'] as String?;
        if (fid != null) followedUids.add(fid);
      }

      _followers = await _fetchUsersData(followerUids);
      _following = await _fetchUsersData(followedUids);
      setState(() {});
    } catch (e) {
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUsersData(List<String> uids) async {
    if (uids.isEmpty) return [];
    final List<Map<String, dynamic>> usersData = [];
    for (String uid in uids) {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        usersData.add({
          'uid': uid,
          'name': data['name'] ?? 'Usuario',
          'age': data['age']?.toString() ?? '',
          'photoUrl': data['photoUrl'] ?? '',
        });
      }
    }
    return usersData;
  }

  Future<void> _sendPlanToSelectedUsers() async {
    if (_currentUser == null || _selectedUsers.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final shareUrl =
        'https://plan-social-app.web.app/plan?planId=${widget.plan.id}';
    final planId = widget.plan.id;
    final planTitle = widget.plan.type;
    final planDesc = widget.plan.description;
    final planImage = widget.plan.backgroundImage;

    for (String uidDestino in _selectedUsers) {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': _currentUser!.uid,
        'receiverId': uidDestino,
        'participants': [_currentUser!.uid, uidDestino],
        'type': 'shared_plan',
        'planId': planId,
        'planTitle': planTitle,
        'planDescription': planDesc,
        'planImage': planImage ?? '',
        'planLink': shareUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }
    await FirebaseFirestore.instance
        .collection('plans')
        .doc(widget.plan.id)
        .update({'share_count': FieldValue.increment(1)});
  Navigator.pop(context);
}

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  "Cancelar",
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _sendPlanToSelectedUsers,
                child: const Text(
                  "Enviar",
                  style: TextStyle(color: Colors.green, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Buscar usuario...",
              hintStyle: const TextStyle(color: Colors.white60),
              prefixIcon: const Icon(Icons.search, color: Colors.white60),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                const Text(
                  "Mis seguidores",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                _buildUserList(_filterUsers(_followers)),
                const SizedBox(height: 12),
                const Text(
                  "A quienes sigo",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                _buildUserList(_filterUsers(_following)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> users) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return users;
    return users.where((u) {
      final name = u['name'].toString().toLowerCase();
      return name.contains(query);
    }).toList();
  }

  Widget _buildUserList(List<Map<String, dynamic>> userList) {
    if (userList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "No hay usuarios en esta sección.",
          style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
        ),
      );
    }
    return Column(
      children: userList.map((user) {
        final uid = user['uid'] ?? '';
        final name = user['name'] ?? 'Usuario';
        final age = user['age'] ?? '';
        final photo = user['photoUrl'] ?? '';
        final isSelected = _selectedUsers.contains(uid);

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blueGrey,
              backgroundImage: (photo.isNotEmpty) ? NetworkImage(photo) : null,
            ),
            title: Text(
              "$name, $age",
              style: const TextStyle(color: Colors.white),
            ),
            trailing: GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedUsers.remove(uid);
                  } else {
                    _selectedUsers.add(uid);
                  }
                });
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.green : Colors.white54,
                    width: 2,
                  ),
                  color: isSelected ? Colors.green : Colors.transparent,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class FullScreenGalleryPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenGalleryPage({
    Key? key,
    required this.images,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<FullScreenGalleryPage> createState() => _FullScreenGalleryPageState();
}

class _FullScreenGalleryPageState extends State<FullScreenGalleryPage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              final url = widget.images[index];
              return Center(
                child: Image.network(url, fit: BoxFit.contain),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
