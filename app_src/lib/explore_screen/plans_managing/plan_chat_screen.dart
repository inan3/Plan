import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../models/plan_model.dart';
import '../users_managing/user_info_check.dart';
import '../../l10n/app_localizations.dart';
import '../../main/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../users_grid/users_grid_helpers.dart';

class PlanChatScreen extends StatefulWidget {
  final PlanModel plan;
  const PlanChatScreen({Key? key, required this.plan}) : super(key: key);

  @override
  State<PlanChatScreen> createState() => _PlanChatScreenState();
}

class _PlanChatScreenState extends State<PlanChatScreen> {
  final TextEditingController _chatController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

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
      child: buildProfileAvatar(senderPic, radius: 20),
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
        ),
      ),
    );

    final msgWidget = Text(
      text,
      textAlign: isMe ? TextAlign.right : TextAlign.left,
      style: const TextStyle(color: Colors.black),
    );

    final timeWidget = Text(
      timeStr,
      style: const TextStyle(color: Colors.grey, fontSize: 12),
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

  Future<void> _sendMessage() async {
    final plan = widget.plan;
    if (_currentUser == null) return;
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

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

    final planRef = FirebaseFirestore.instance.collection('plans').doc(plan.id);
    await planRef.update({
      'commentsCount': FieldValue.increment(1),
    }).catchError((_) {
      planRef.set({'commentsCount': 1}, SetOptions(merge: true));
    });

    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context).planChat,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
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
                      child: Text(AppLocalizations.of(context).errorLoadingMessages),
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(AppLocalizations.of(context).noMessagesYet),
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
                        hintText: AppLocalizations.of(context).writeMessage,
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.blue),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

