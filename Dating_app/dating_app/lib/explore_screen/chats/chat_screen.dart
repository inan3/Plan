import 'dart:ui'; // Para ImageFilter (frosted glass)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../main/colors.dart';

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

  // Altura fija para el encabezado personalizado (usado solo para definir el tamaño del widget)
  final double _headerHeight = 70.0;

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    // Usamos el color de fondo del Scaffold para mantener la coherencia
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // El listado de mensajes ocupa toda el área disponible.
            Positioned.fill(
              child: _buildMessagesList(),
            ),
            // Encabezado flotante en la parte superior.
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  // Botón de retroceso circular con sombra.
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
                  // Contenedor de información del chat (foto y nombre) con sombra y ancho limitado.
                  Container(
                    width: MediaQuery.of(context).size.width * 0.55,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        // Nombre del usuario con manejo de texto largo.
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
                  const SizedBox(width: 8),
                  // Botón de teléfono.
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
                        // Por ahora no hace nada.
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón de opciones (3 puntos verticales).
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
                        // Por ahora no hace nada.
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Área de entrada de mensaje posicionada en la parte inferior.
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

  /// **Lista de mensajes**
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

      // Filtrar mensajes para mostrar solo los recientes tras `deletedAt`.
      var messages = snapshot.data!.docs.where((doc) {
        var data = doc.data() as Map<String, dynamic>;

        // Verificar que 'timestamp' exista y sea de tipo Timestamp.
        if (!(data['timestamp'] is Timestamp)) {
          return false;
        }
        Timestamp timestamp = data['timestamp'] as Timestamp;
        DateTime messageTime = timestamp.toDate();

        // Si se ha eliminado el chat, ocultar mensajes previos a 'deletedAt'.
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
        // Agregamos padding para evitar que el primer y último mensaje queden tapados.
        padding: EdgeInsets.only(
          top: _headerHeight + 16,  // espacio para el header
          bottom: 70,               // espacio para el área de entrada
        ),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          var data = messages[index].data() as Map<String, dynamic>;
          bool isMe = data['senderId'] == currentUserId;

          // Asegurarse de que 'timestamp' sea de tipo Timestamp.
          DateTime messageTime;
          if (data['timestamp'] is Timestamp) {
            messageTime = (data['timestamp'] as Timestamp).toDate();
          } else {
            messageTime = DateTime.now();
          }

          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
          );
        },
      );
    },
  );
}


  /// **Área de entrada de mensaje con efecto frosted glass y botones flotantes**
Widget _buildMessageInput() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        // Botón flotante con ícono de "+" a la izquierda.
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
              // Acción vacía por el momento.
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 48, // Establece un alto fijo para que coincida con los botones.
            alignment: Alignment.center, // Centra el contenido verticalmente.
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white, // Fondo blanco.
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
                isCollapsed: true, // Reduce el padding interno.
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Botón de envío flotante a la derecha.
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
