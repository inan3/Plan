// user_info_inside_chat.dart

import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../main/colors.dart'; // Ajusta la importación si es necesario
import '../chats/chat_screen.dart';

class UserInfoInsideChat extends StatefulWidget {
  /// ID del usuario con el que se chatea (el receptor).
  /// Este id debe ser el id EXACTO del documento en la colección 'users'.
  final String chatPartnerId;

  const UserInfoInsideChat({super.key, required this.chatPartnerId});

  @override
  _UserInfoInsideChatState createState() => _UserInfoInsideChatState();
}

class _UserInfoInsideChatState extends State<UserInfoInsideChat> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  Map<String, dynamic>? _chatPartnerData;
  Map<String, dynamic>? _currentUserData;

  /// Color de fondo lila crema claro
  final Color _lilaCrema = const Color.fromARGB(255, 245, 237, 246);

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      // Si no hay usuario autenticado, cerramos el chat.
      Navigator.pop(context);
      return;
    }
    final partnerId = widget.chatPartnerId.trim();
    _fetchChatPartnerData(partnerId);
    _fetchCurrentUserData();
  }

  /// Obtiene los datos del usuario receptor (a quién le envío el mensaje)
  Future<void> _fetchChatPartnerData(String partnerId) async {
    if (partnerId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(partnerId)
          .get();
      if (doc.exists) {
        setState(() {
          _chatPartnerData = doc.data() as Map<String, dynamic>;
        });
      } else {
        setState(() {
          _chatPartnerData = {};
        });
      }
    } catch (e) {
      setState(() {
        _chatPartnerData = {};
      });
    }
  }

  /// Obtiene los datos del usuario emisor (actual)
  Future<void> _fetchCurrentUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _currentUserData = doc.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      // Manejo de error si hace falta
    }
  }

  /// Verifica la conversación y, según el estado del último mensaje, envía o redirige.
  Future<void> _checkAndSendMessage() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty) return;

    final String senderId = _currentUser!.uid;
    final String receiverId = widget.chatPartnerId.trim();
    final String conversationId = senderId.compareTo(receiverId) < 0
        ? "${senderId}_$receiverId"
        : "${receiverId}_$senderId";

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Existe al menos un mensaje
        final lastMessage = snapshot.docs.first.data() as Map<String, dynamic>;
        if (lastMessage['senderId'] == senderId) {
          // Último mensaje es del usuario actual, pedimos que espere
          _mostrarPopUpEspera();
          return;
        } else {
          // El receptor ya respondió, redirigimos al chat completo
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatPartnerId: receiverId,
                chatPartnerName: _chatPartnerData?['name'] ?? 'Usuario',
                chatPartnerPhoto: _chatPartnerData?['photoUrl'],
                deletedAt: null,
              ),
            ),
          );
          return;
        }
      } else {
        // No hay mensajes, enviamos el primero
        await _sendMessage(conversationId);
      }
    } catch (e) {
      // Manejo de error
    }
  }

  /// Envía un mensaje (primer mensaje).
  Future<void> _sendMessage(String conversationId) async {
    final String messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final String senderId = _currentUser!.uid;
    final String receiverId = widget.chatPartnerId.trim();

    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': senderId,
        'receiverId': receiverId,
        'participants': [senderId, receiverId],
        'conversationId': conversationId,
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      _messageController.clear();
    } catch (e) {
      // Manejo de error
    }
  }

  /// Muestra un pop-up indicando que se debe esperar a que el receptor responda.
  void _mostrarPopUpEspera() {
    final String receptor = _chatPartnerData?['name'] ?? "el usuario";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Espera un momento"),
        content: Text("Espera a que $receptor te responda."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Ok"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calcula la altura del pop-up según la presencia del teclado
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double popUpHeight =
        keyboardHeight > 0 ? screenHeight * 0.4 : screenHeight * 0.5;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        // Tocar fuera del pop-up cierra este widget
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            // Contenedor principal del chat con clipping de bordes
            Positioned(
              left: MediaQuery.of(context).size.width * 0.1,
              top: keyboardHeight > 0 ? screenHeight * 0.1 : screenHeight * 0.2,
              child: GestureDetector(
                onTap: () {}, // Evita que se cierre si pulsamos dentro
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: popUpHeight,
                    decoration: BoxDecoration(
                      color: _lilaCrema,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.black12,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Cabecera (avatar + nombre + boton cerrar)
                        _buildHeaderContainer(),
                        // Línea de separación
                        const Divider(height: 1, color: Colors.black26),
                        // Lista de mensajes
                        Expanded(child: _buildMessagesListContainer()),
                        // Línea de separación
                        const Divider(height: 1, color: Colors.black26),
                        // Caja de texto para enviar mensaje
                        _buildMessageInputContainer(),
                      ],
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

  /// Cabecera con foto, nombre y edad del usuario receptor
  Widget _buildHeaderContainer() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.chatPartnerId.trim())
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: Text(
                'Usuario no encontrado',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String name = data['name'] ?? 'Usuario';
        final String age = data['age']?.toString() ?? '';
        final String photoUrl = data['photoUrl'] ?? data['profilePic'] ?? '';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          // Sin borderRadius interno; se hereda del contenedor principal
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[400],
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$name, $age',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Contenedor que envuelve la lista de mensajes
  Widget _buildMessagesListContainer() {
    return Container(
      // Mismo color que el contenedor principal
      color: _lilaCrema,
      child: _buildMessagesList(),
    );
  }

  /// Lista de mensajes en la conversación (o texto vacío si no hay mensajes)
  Widget _buildMessagesList() {
    if (_currentUser == null) return const SizedBox.shrink();

    final String senderId = _currentUser!.uid;
    final String receiverId = widget.chatPartnerId.trim();
    final String conversationId = senderId.compareTo(receiverId) < 0
        ? "${senderId}_$receiverId"
        : "${receiverId}_$senderId";

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final messages = snapshot.data!.docs;
        if (messages.isEmpty) {
          return const Center(
            child: Text(
              "Aún no hay mensajes.",
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
          );
        }
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index].data() as Map<String, dynamic>;
            final bool isMe = message['senderId'] == senderId;
            if (message['timestamp'] is Timestamp) {
              // Convertimos si es necesario, pero no lo estamos usando en un text
              // salvo que quisieras mostrar la hora
            }
            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: isMe ? Colors.blueAccent : Colors.grey[300],
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  message['text'] ?? '',
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Contenedor que envuelve el área de entrada de texto para enviar mensaje.
  Widget _buildMessageInputContainer() {
    return Container(
      color: _lilaCrema,
      child: _buildMessageInput(),
    );
  }

  /// Área de entrada de mensaje: campo de texto y botón enviar.
  Widget _buildMessageInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _messageController,
            style: const TextStyle(color: Colors.black87),
            decoration: const InputDecoration(
              hintText: 'Escribe tu mensaje...',
              hintStyle: TextStyle(color: Colors.black45),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.send, color: Colors.blueAccent),
          onPressed: _checkAndSendMessage,
        ),
      ],
    );
  }
}
