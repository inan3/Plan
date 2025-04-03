import 'dart:ui'; // Para ImageFilter (frosted glass)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../main/colors.dart';
import '../../models/plan_model.dart';
// Importa el FrostedPlanDialog para poder abrirlo
import '../users_managing/frosted_plan_dialog_state.dart'; // Ajusta la ruta a tu ubicación real
import '../users_managing/user_info_check.dart';

class ChatScreen extends StatefulWidget {
  final String chatPartnerId;
  final String chatPartnerName;
  final String? chatPartnerPhoto;
  final Timestamp? deletedAt; // Si el usuario eliminó el chat, se almacenará el timestamp

  const ChatScreen({
    Key? key,
    required this.chatPartnerId,
    required this.chatPartnerName,
    this.chatPartnerPhoto,
    this.deletedAt,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Altura fija para el encabezado personalizado
  final double _headerHeight = 70.0;

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
    _markMessagesAsRead();
  }

  /// Marca como leídos todos los mensajes recibidos en este chat.
  Future<void> _markMessagesAsRead() async {
    try {
      // Mensajes enviados por el chatPartner que no han sido leídos
      QuerySnapshot unreadMessages = await FirebaseFirestore.instance
          .collection('messages')
          .where('senderId', isEqualTo: widget.chatPartnerId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      // Mensajes marcados como leídos
    } catch (e) {
      print("❌ Error al marcar mensajes como leídos: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // El listado de mensajes ocupa toda el área
            Positioned.fill(
              child: _buildMessagesList(),
            ),
            // Encabezado flotante arriba
            Positioned(
  top: 8,
  left: 8,
  right: 8,
  child: Row(
    children: [
      // Botón de retroceso
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.blue),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      const SizedBox(width: 8),

      // Info del chat: foto + nombre
      Container(
  width: MediaQuery.of(context).size.width * 0.55,
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(30),
    boxShadow: [
      BoxShadow(
        color: Colors.grey.withOpacity(0.5),
        spreadRadius: 1,
        blurRadius: 4,
        offset: const Offset(0, 3),
      ),
    ],
  ),

  // Envuelve TODO en GestureDetector:
  child: GestureDetector(
    onTap: () {
      // Al pulsar en cualquier parte (avatar o nombre),
      // abrimos la pantalla del usuario:
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserInfoCheck(userId: widget.chatPartnerId),
        ),
      );
    },
    child: Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundImage: widget.chatPartnerPhoto != null
              ? NetworkImage(widget.chatPartnerPhoto!)
              : null,
          backgroundColor: Colors.grey[300],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.chatPartnerName,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  ),
),
      const SizedBox(width: 8),

      // Botón teléfono (opcional)
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.phone, color: AppColors.blue),
          onPressed: () {
            // ...
          },
        ),
      ),
      const SizedBox(width: 8),

      // Botón menú (3 puntos)
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.more_vert, color: AppColors.blue),
          onPressed: () {
            // ...
          },
        ),
      ),
    ],
  ),
),
            // Área de entrada de mensaje en la parte inferior
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildMessageInput(),
            ),
          ],
        ),
      ),
    );
  }

  /// Lista de mensajes
  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('participants', arrayContains: currentUserId)
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "No hay mensajes aún.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        // Filtrar solo los mensajes entre currentUserId y chatPartnerId
        var messages = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['timestamp'] is! Timestamp) return false;
          Timestamp timestamp = data['timestamp'];
          DateTime messageTime = timestamp.toDate();

          // Si hay un deletedAt, no mostramos los mensajes anteriores a ese momento
          if (widget.deletedAt != null &&
              messageTime.isBefore(widget.deletedAt!.toDate())) {
            return false;
          }

          // Verificar que son mensajes con sender/receiver correctos
          bool case1 = (data['senderId'] == currentUserId &&
              data['receiverId'] == widget.chatPartnerId);
          bool case2 = (data['senderId'] == widget.chatPartnerId &&
              data['receiverId'] == currentUserId);

          return case1 || case2;
        }).toList();

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.only(
            top: _headerHeight + 16,
            bottom: 70,
          ),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            var data = messages[index].data() as Map<String, dynamic>;
            bool isMe = data['senderId'] == currentUserId;
            final String? type = data['type'] as String?;

            if (type == 'shared_plan') {
              // Renderizar tarjeta de plan
              return _buildSharedPlanBubble(data, isMe);
            } else {
              // Mensaje de texto normal
              return _buildTextBubble(data, isMe);
            }
          },
        );
      },
    );
  }

  /// Burbuja para mensajes de texto
  Widget _buildTextBubble(Map<String, dynamic> data, bool isMe) {
  DateTime messageTime = DateTime.now();
  if (data['timestamp'] is Timestamp) {
    messageTime = (data['timestamp'] as Timestamp).toDate();
  }

  return Align(
    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
    child: ConstrainedBox(
      // Aquí limitamos el ancho al 75% de la pantalla
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[400] : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              data['text'] ?? '',
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(messageTime),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  /// Burbuja para mensajes que comparten un plan
  Widget _buildSharedPlanBubble(Map<String, dynamic> data, bool isMe) {
    final String planId = data['planId'] ?? '';
    final String planTitle = data['planTitle'] ?? 'Título';
    final String planDesc = data['planDescription'] ?? 'Descripción';
    final String planImage = data['planImage'] ?? '';
    final String planLink = data['planLink'] ?? '';

    DateTime messageTime = DateTime.now();
    if (data['timestamp'] is Timestamp) {
      messageTime = (data['timestamp'] as Timestamp).toDate();
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.65,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[400] : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Imagen / preview del plan
            GestureDetector(
              onTap: () => _openPlanDetails(planId),
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  image: planImage.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(planImage),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: planImage.isEmpty
                    ? const Center(
                        child: Icon(Icons.image, size: 40, color: Colors.grey),
                      )
                    : null,
              ),
            ),
            // Texto del plan
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    planTitle,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    planDesc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Enlace
                  InkWell(
                    onTap: () => _openPlanDetails(planId),
                    child: Text(
                      planLink,
                      style: TextStyle(
                        color: isMe ? Colors.yellow : Colors.blueAccent,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Hora
                  Text(
                    DateFormat('HH:mm').format(messageTime),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Abre el plan con un FrostedPlanDialog
  void _openPlanDetails(String planId) async {
  try {
    final planDoc = await FirebaseFirestore.instance
        .collection('plans')
        .doc(planId)
        .get();

    if (!planDoc.exists || planDoc.data() == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("El plan no existe o fue borrado.")),
      );
      return;
    }

    final planData = planDoc.data()!;
    final plan = PlanModel.fromMap(planData);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => FrostedPlanDialog(
          plan: plan,
          fetchParticipants: _fetchPlanParticipants,
        ),
      ),
    );
  } catch (e) {
    print("Error al abrir plan: $e");
  }
}

Future<List<Map<String, dynamic>>> _fetchPlanParticipants(PlanModel plan) async {
  final List<Map<String, dynamic>> participants = [];

  // 1) Cargamos creador
  final docPlan = await FirebaseFirestore.instance
      .collection('plans')
      .doc(plan.id)
      .get();
  if (docPlan.exists) {
    final planMap = docPlan.data();
    final creatorId = planMap?['createdBy'];
    if (creatorId != null) {
      final creatorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(creatorId)
          .get();
      if (creatorDoc.exists && creatorDoc.data() != null) {
        final cdata = creatorDoc.data()!;
        participants.add({
          'name': cdata['name'] ?? 'Sin nombre',
          'age': cdata['age']?.toString() ?? '',
          'photoUrl': cdata['photoUrl'] ?? '',
          'isCreator': true,
        });
      }
    }
  }

  // 2) Suscritos
  final subsSnap = await FirebaseFirestore.instance
      .collection('subscriptions')
      .where('id', isEqualTo: plan.id)
      .get();
  for (var sDoc in subsSnap.docs) {
    final data = sDoc.data();
    final uid = data['userId'];
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (userDoc.exists && userDoc.data() != null) {
      final udata = userDoc.data()!;
      participants.add({
        'name': udata['name'] ?? 'Sin nombre',
        'age': udata['age']?.toString() ?? '',
        'photoUrl': udata['photoUrl'] ?? '',
        'isCreator': false,
      });
    }
  }

  return participants;
}

  /// Área de entrada de mensaje
  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Botón "+"
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: AppColors.blue),
              onPressed: () {
                // ...
              },
            ),
          ),
          const SizedBox(width: 8),
          // Campo de texto
          Expanded(
            child: Container(
              height: 48,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: "Escribe un mensaje...",
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Botón "Send"
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: AppColors.blue),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  /// Enviar mensaje de texto
  void _sendMessage() async {
    String messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': currentUserId,
        'receiverId': widget.chatPartnerId,
        'participants': [currentUserId, widget.chatPartnerId],
        'type': 'text', // Mensaje normal
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print("❌ Error al enviar mensaje: $e");
    }
  }

  /// Auto-scroll al final
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
