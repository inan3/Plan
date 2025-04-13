import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/plan_model.dart';
import '../../main/colors.dart';

import 'users_managing/user_info_check.dart';
import 'users_managing/user_info_inside_chat.dart';
import 'special_plans/invite_users_to_plan_screen.dart';
import 'users_managing/frosted_plan_dialog_state.dart';

class UsersGrid extends StatelessWidget {
  final void Function(dynamic userDoc)? onUserTap;
  final List<dynamic> users;

  const UsersGrid({
    Key? key,
    required this.users,
    this.onUserTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final userDoc = users[index];
        final Map<String, dynamic> userData = userDoc is QueryDocumentSnapshot
            ? (userDoc.data() as Map<String, dynamic>)
            : userDoc as Map<String, dynamic>;
        return _buildUserCard(userData, context);
      },
    );
  }

  Future<List<PlanModel>> _fetchUserPlans(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('plans')
        .where('createdBy', isEqualTo: userId)
        .get();

    final now = DateTime.now();
    final filteredDocs = snapshot.docs.where((doc) {
      final data = doc.data();
      final int sp = data['special_plan'] ?? 0;
      if (sp != 0) return false;

      final Timestamp? finishTs = data['finish_timestamp'];
      if (finishTs == null) return false;
      final finishDate = finishTs.toDate();
      return finishDate.isAfter(now);
    }).toList();

    return filteredDocs.map((doc) {
      final data = doc.data();
      return PlanModel.fromMap(data);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchPlanParticipants(PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];

    final planDoc = await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .get();

    if (!planDoc.exists) {
      return participants;
    }

    final planData = planDoc.data()!;
    final participantsList = List<String>.from(planData['participants'] ?? []);

    for (String userId in participantsList) {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final uData = userDoc.data()!;
        participants.add({
          'uid': userId,
          'name': uData['name'] ?? 'Sin nombre',
          'age': uData['age']?.toString() ?? '',
          'photoUrl': uData['photoUrl'] ?? '',
          'isCreator': (plan.createdBy == userId),
        });
      }
    }
    return participants;
  }

  Widget _buildUserCard(Map<String, dynamic> userData, BuildContext context) {
    final String? uid = userData['uid']?.toString();
    if (uid == null) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: Text(
            'Usuario inválido',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return FutureBuilder<List<PlanModel>>(
      future: _fetchUserPlans(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 330,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            height: 330,
            child: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final plans = snapshot.data ?? [];
        if (plans.isEmpty) {
          return _buildNoPlanLayout(context, userData);
        } else {
          return Column(
            children: plans.map((plan) {
              return _PlanCard(
                plan: plan,
                userData: userData,
                fetchParticipants: _fetchPlanParticipants,
              );
            }).toList(),
          );
        }
      },
    );
  }

  Widget _buildNoPlanLayout(BuildContext context, Map<String, dynamic> userData) {
    final String name = userData['name']?.toString().trim() ?? 'Usuario';
    final String userHandle = userData['handle']?.toString() ?? '@usuario';
    final String? uid = userData['uid']?.toString();
    final String? fallbackPhotoUrl = userData['photoUrl']?.toString();

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: 330,
        margin: const EdgeInsets.only(bottom: 15),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: (fallbackPhotoUrl != null && fallbackPhotoUrl.isNotEmpty)
                  ? Image.network(
                      fallbackPhotoUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: GestureDetector(
                onTap: () {
                  if (uid != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserInfoCheck(userId: uid),
                      ),
                    );
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: const Color.fromARGB(255, 14, 14, 14).withOpacity(0.2),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildProfileAvatar(fallbackPhotoUrl),
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
                                userHandle,
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
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Container(
                  margin: const EdgeInsets.only(top: 100),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            color: const Color.fromARGB(255, 84, 78, 78)
                                .withOpacity(0.3),
                            child: const Text(
                              'Este usuario no ha creado planes aún...',
                              style: TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SvgPicture.asset(
                        'assets/sin-plan.svg',
                        width: 80,
                        height: 80,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 20),
                      _buildActionButtons(context, uid),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String? userId) {
    final String safeUserId = userId ?? '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          context: context,
          iconPath: 'assets/agregar-usuario.svg',
          label: 'Invítale a un Plan',
          onTap: () {
            if (userId != null && userId.isNotEmpty) {
              InviteUsersToPlanScreen.showPopup(context, userId);
            }
          },
        ),
        const SizedBox(width: 16),
        _buildActionButton(
          context: context,
          iconPath: 'assets/mensaje.svg',
          label: null,
          onTap: () {
            showGeneralDialog(
              context: context,
              barrierDismissible: true,
              barrierLabel: 'Cerrar',
              barrierColor: Colors.transparent,
              transitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (_, __, ___) => const SizedBox(),
              transitionBuilder: (ctx, anim1, anim2, child) {
                return FadeTransition(
                  opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
                  child: UserInfoInsideChat(
                    key: ValueKey(safeUserId),
                    chatPartnerId: safeUserId,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String iconPath,
    String? label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color.fromARGB(255, 84, 78, 78).withOpacity(0.3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  iconPath,
                  width: 32,
                  height: 32,
                  color: Colors.white,
                ),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(photoUrl),
      );
    } else {
      return const CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, color: Colors.white),
      );
    }
  }

  Widget _buildPlaceholder() {
    return SizedBox(
      width: double.infinity,
      child: AspectRatio(
        aspectRatio: 1, // Mismo ancho y alto
        child: Container(
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PlanCard
// ---------------------------------------------------------------------------
class _PlanCard extends StatefulWidget {
  final PlanModel plan;
  final Map<String, dynamic> userData;
  final Future<List<Map<String, dynamic>>> Function(PlanModel plan) fetchParticipants;

  const _PlanCard({
    Key? key,
    required this.plan,
    required this.userData,
    required this.fetchParticipants,
  }) : super(key: key);

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _liked = false;
  int _likeCount = 0;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  late Future<List<Map<String, dynamic>>> _futureParticipants;
  late List<Map<String, dynamic>> _participants;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.plan.likes;
    _checkIfLiked();
    _futureParticipants = widget.fetchParticipants(widget.plan);
    _participants = [];
  }

  Future<void> _checkIfLiked() async {
    final user = _currentUser;
    if (user == null) return;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      final data = userDoc.data()!;
      final favs = data['favourites'] as List<dynamic>? ?? [];
      if (favs.contains(widget.plan.id)) {
        setState(() => _liked = true);
      }
    }
  }

  Future<void> _toggleLike() async {
    final user = _currentUser;
    if (user == null) return;
    final planRef =
        FirebaseFirestore.instance.collection('plans').doc(widget.plan.id);
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(planRef);
      if (!snap.exists) return;
      int currentLikes = snap.data()!['likes'] ?? 0;
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
    setState(() => _liked = !_liked);
  }

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
      final planRef =
          FirebaseFirestore.instance.collection('plans').doc(plan.id);
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

  void _onAvatarTap(String creatorUid) {
    if (creatorUid.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserInfoCheck(userId: creatorUid)),
    );
  }

  final TextEditingController _chatController = TextEditingController();

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

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

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
          builder: (BuildContext context, ScrollController scrollController) {
            return _PlanShareSheet(
              plan: plan,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  /// Aquí está el cambio esencial:
  /// Si "name, age" excede 10 caracteres, truncamos y agregamos '...'
  Widget _buildParticipantsCorner() {
    if (_participants.isEmpty) return const SizedBox.shrink();
    final count = _participants.length;

    // CASO 1: Solo hay 1 participante
    if (count == 1) {
      final p = _participants[0];
      final pic = p['photoUrl'] ?? '';
      String name = p['name'] ?? 'Usuario';
      final age = p['age']?.toString() ?? '';

      // Construimos un string con "name, age"
      String displayText = '$name, $age';

      // Limitamos a 10 caracteres si excede
      if (displayText.length > 10) {
        displayText = displayText.substring(0, 9) + '...';
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

    // CASO 2: Más de 1 participante
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

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final String name = widget.userData['name']?.toString().trim() ?? 'Usuario';
    final String userHandle =
        widget.userData['handle']?.toString() ?? '@usuario';
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
                  // Info superior
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
                          child: _buildCreatorFrosted(
                            name,
                            userHandle,
                            fallbackPhotoUrl,
                          ),
                        ),
                        const Spacer(),
                        _buildJoinFrosted(),
                      ],
                    ),
                  ),

                  // Imagen del plan
                  GestureDetector(
                    onTap: () => _openPlanDetails(context, plan),
                    child: plan.backgroundImage != null &&
                            plan.backgroundImage!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 16 / 13,
                              child: Image.network(
                                plan.backgroundImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildPlaceholder(),
                              ),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: _buildPlaceholder(),
                            ),
                          ),
                  ),

                  // Botones
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 8,
                      bottom: 8,
                    ),
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
                          countText: 'Compartir',
                          onTap: _onShareButtonTap,
                        ),
                        const Spacer(),
                        _buildParticipantsCorner(),
                      ],
                    ),
                  ),

                  // n/m
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        maxP > 0
                            ? '$totalP/$maxP participantes'
                            : '$totalP participantes',
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
              _buildProfileAvatar(photoUrl),
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

  Widget _buildJoinFrosted() {
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

  Widget _buildProfileAvatar(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(photoUrl),
      );
    } else {
      return const CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, color: Colors.white),
      );
    }
  }

  Widget _buildPlaceholder() {
    return SizedBox(
      width: double.infinity,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------
// _PlanShareSheet
// ------------------------------------------------
class _PlanShareSheet extends StatefulWidget {
  final PlanModel plan;
  final ScrollController scrollController;

  const _PlanShareSheet({
    Key? key,
    required this.plan,
    required this.scrollController,
  }) : super(key: key);

  @override
  State<_PlanShareSheet> createState() => _PlanShareSheetState();
}

class _PlanShareSheetState extends State<_PlanShareSheet> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  final TextEditingController _searchController = TextEditingController();
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
      debugPrint("Error al cargar followers/following: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUsersData(List<String> uids) async {
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

    final String shareUrl =
        'https://plan-social-app.web.app/plan?planId=${widget.plan.id}';
    final String planId = widget.plan.id;
    final String planTitle = widget.plan.type;
    final String planDesc = widget.plan.description;
    final String? planImage = widget.plan.backgroundImage;

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

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final String shareUrl =
        'https://plan-social-app.web.app/plan?planId=${widget.plan.id}';
    final String planTitle = widget.plan.type;
    final String planDesc = widget.plan.description;
    final String shareText =
        '¡Mira este plan!\n\nTítulo: $planTitle\nDescripción: $planDesc\n$shareUrl';

    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 35, 57, 80),
        borderRadius: BorderRadius.circular(20),
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
          // Botón "Compartir con otras apps"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    Share.share(shareText);
                  },
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white54),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  // Barra sup "Cancelar" y "Enviar"
                  Row(
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
                  const SizedBox(height: 10),
                  // Cuadro de búsqueda
                  TextField(
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
                  const SizedBox(height: 12),
                  // "Mis seguidores"
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Mis seguidores",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildUserList(_filterUsers(_followers)),
                  const SizedBox(height: 12),
                  // "A quienes sigo"
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "A quienes sigo",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildUserList(_filterUsers(_following)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> original) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return original;
    return original.where((user) {
      final name = (user['name'] ?? '').toLowerCase();
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
        final uid = user['uid'] as String? ?? '';
        final name = user['name'] as String? ?? 'Usuario';
        final age = user['age'] as String? ?? '';
        final photo = user['photoUrl'] as String? ?? '';
        final isSelected = _selectedUsers.contains(uid);

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 20,
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
