import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: CircleAvatar(
            backgroundImage: widget.chatPartnerPhoto != null
                ? NetworkImage(widget.chatPartnerPhoto!)
                : null,
            backgroundColor: Colors.grey[300],
          ),
        ),
        title: Text(widget.chatPartnerName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  /// **Lista de mensajes**
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

        // **Filtrar mensajes para mostrar solo los recientes tras `deletedAt`**
        var messages = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;

          // Verificar que 'timestamp' exista y sea de tipo Timestamp
          if (!(data['timestamp'] is Timestamp)) {
            return false;
          }
          Timestamp timestamp = data['timestamp'] as Timestamp;
          DateTime messageTime = timestamp.toDate();

          // Si se ha eliminado el chat, ocultar mensajes previos a 'deletedAt'
          if (widget.deletedAt != null &&
              messageTime.isBefore(widget.deletedAt!.toDate())) {
            return false;
          }

          return (data['senderId'] == currentUserId &&
                  data['receiverId'] == widget.chatPartnerId) ||
              (data['senderId'] == widget.chatPartnerId &&
                  data['receiverId'] == currentUserId);
        }).toList();

        return ListView.builder(
          controller: _scrollController,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            var data = messages[index].data() as Map<String, dynamic>;
            bool isMe = data['senderId'] == currentUserId;

            // Se verifica que 'timestamp' sea de tipo Timestamp antes de usarlo.
            DateTime messageTime;
            if (data['timestamp'] is Timestamp) {
              messageTime = (data['timestamp'] as Timestamp).toDate();
            } else {
              messageTime = DateTime.now();
            }

            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
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
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
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
            );
          },
        );
      },
    );
  }

  /// **Área de entrada de mensaje**
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: "Escribe un mensaje...",
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.blue),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  /// **Enviar mensaje**
  void _sendMessage() async {
    String messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': currentUserId,
        'receiverId': widget.chatPartnerId,
        'participants': [currentUserId, widget.chatPartnerId],
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

  /// **Auto-scroll al enviar mensaje**
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
