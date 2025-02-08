// user_info_inside_chat.dart
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../main/colors.dart'; // Asegúrate de que AppColors esté definido correctamente

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

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      // Si no hay usuario autenticado, cerramos el chat.
      Navigator.pop(context);
      return;
    }
    // Imprime el chatPartnerId (con trim para eliminar espacios extra)
    final partnerId = widget.chatPartnerId.trim();
    print("UserInfoInsideChat: chatPartnerId = $partnerId");
    _fetchChatPartnerData(partnerId);
    _fetchCurrentUserData();
  }

  /// Obtiene los datos del usuario receptor (a quién le envío el mensaje)
  Future<void> _fetchChatPartnerData(String partnerId) async {
    if (partnerId.isEmpty) {
      print("🚨 Error: chatPartnerId está vacío");
      return;
    }
    try {
      print("Consultando Firestore con ID: $partnerId");
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(partnerId)
          .get();
      print("Chat partner doc id: ${doc.id}, exists: ${doc.exists}");
      if (doc.exists) {
        print("✅ Usuario encontrado: ${doc.data()}");
        setState(() {
          _chatPartnerData = doc.data() as Map<String, dynamic>;
        });
      } else {
        print("❌ Usuario NO encontrado en Firestore");
        setState(() {
          _chatPartnerData = {};
        });
      }
    } catch (e) {
      print('🔥 Error al obtener datos del usuario receptor: $e');
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
      print("Current user doc id: ${doc.id}, exists: ${doc.exists}");
      if (doc.exists) {
        setState(() {
          _currentUserData = doc.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      print('🔥 Error al obtener datos del usuario emisor: $e');
    }
  }

  /// Envía el mensaje incluyendo algunos datos del emisor
  Future<void> _sendMessage() async {
    final String messageText = _messageController.text.trim();
    if (messageText.isEmpty || _currentUser == null || _chatPartnerData == null) return;

    final String receiverId = widget.chatPartnerId.trim();
    final String senderId = _currentUser!.uid;

    try {
      print("📤 Enviando mensaje a Firestore...");
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': senderId,
        'receiverId': receiverId,
        'participants': [senderId, receiverId], // 📌 IMPORTANTE: Para filtrar chats
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      print("✅ Mensaje enviado con éxito.");
      _messageController.clear();
    } catch (e) {
      print('🔥 Error al enviar el mensaje: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    // Calcula la altura del pop-up según la presencia del teclado
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double popUpHeight =
        keyboardHeight > 0 ? screenHeight * 0.4 : screenHeight * 0.5;

    return Scaffold(
      // Fondo transparente para que se vea el contenido original detrás
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        // Tocar fuera del pop-up cierra el chat
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            // Fondo desenfocado: se aplica el blur sin oscurecer el contenido original
            /*Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(color: Colors.transparent),
              ),
            ),*/
            // Pop-up central
            Positioned(
              left: MediaQuery.of(context).size.width * 0.1,
              top: keyboardHeight > 0
                  ? screenHeight * 0.1
                  : screenHeight * 0.2,
              child: GestureDetector(
                // Evita que el pop-up se cierre al tocarlo
                onTap: () {},
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      height: popUpHeight,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          _buildHeader(),
                          Expanded(child: _buildMessagesList()),
                          _buildMessageInput(),
                        ],
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

  /// Construye el header del pop-up: muestra la foto, nombre y edad del usuario receptor.
  Widget _buildHeader() {
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
                style: TextStyle(color: Colors.white, fontSize: 16),
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
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey,
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$name, $age',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.blue),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Área de mensajes: muestra los mensajes (por ahora, un placeholder).
  Widget _buildMessagesList() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('messages')
        .where('participants', arrayContains: _currentUser?.uid)
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
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        );
      }

      return ListView.builder(
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index].data() as Map<String, dynamic>;
          final bool isMe = message['senderId'] == _currentUser?.uid;
          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: isMe ? Colors.blueAccent : Colors.grey[700],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                message['text'] ?? '',
                style: TextStyle(color: isMe ? Colors.white : Colors.black87),
              ),
            ),
          );
        },
      );
    },
  );
}


  /// Área de entrada de mensaje: campo de texto y botón enviar.
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Escribe tu mensaje...',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: AppColors.blue),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
