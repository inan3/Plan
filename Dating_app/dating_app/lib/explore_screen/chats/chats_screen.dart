import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  final String? sharedText;

  const ChatsScreen({Key? key, this.sharedText}) : super(key: key);

  @override
  _ChatsScreenState createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    // Si llegó texto compartido, muestra un cuadro de diálogo al iniciar
    if (widget.sharedText != null && widget.sharedText!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSharedTextDialog(widget.sharedText!);
      });
    }
  }

  /// Muestra un diálogo con el texto compartido.
  void _showSharedTextDialog(String text) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Contenido compartido"),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cerrar"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // EJEMPLO: envía el texto a un chat con un ID "destUserId"
                String destUserId = "123456"; // Ejemplo
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatPartnerId: destUserId,
                      chatPartnerName: "Contacto Ejemplo",
                      chatPartnerPhoto: "",
                    ),
                  ),
                );
              },
              child: const Text("Enviar a un contacto"),
            ),
          ],
        );
      },
    );
  }

  /// Elimina el chat (ejemplo)
  Future<void> _deleteChat(String otherUserId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .set(
        {'deletedChats': {otherUserId: FieldValue.serverTimestamp()}},
        SetOptions(merge: true),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chat eliminado.")),
      );
    } catch (e) {
      print("❌ Error al eliminar chat: $e");
    }
  }

  /// Convierte un Timestamp a String "HH:mm"
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return "$hh:$mm";
  }

  /// Lógica para la previa de mensaje.
  String _buildMessagePreview(Map<String, dynamic> data) {
    final type = data['type'] ?? 'text';
    if (type == 'shared_plan') {
      return "Plan compartido";
    } else if (type == 'text') {
      final text = data['text'] as String? ?? '';
      if (text.startsWith('http') || text.startsWith('www')) {
        return "Enlace: ${_truncate(text, maxLen: 20)}";
      } else {
        return _truncate(text, maxLen: 30);
      }
    } else {
      // Otros tipos (imagen, video, etc.)
      return "Mensaje multimedia";
    }
  }

  /// Truncar un string
  String _truncate(String text, {int maxLen = 30}) {
    if (text.length <= maxLen) return text;
    return "${text.substring(0, maxLen)}...";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chats"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _buildChatList(),
    );
  }

  /// Muestra la lista de últimos chats
  Widget _buildChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('participants', arrayContains: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No tienes mensajes aún."));
        }

        final docs = snapshot.data!.docs;
        // Map: otherUserId -> lastMessageData
        final Map<String, Map<String, dynamic>> lastMessages = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['timestamp'] as Timestamp?;
          if (ts == null) continue;

          // Determinamos el "otro" usuario
          final String otherUserId = (data['senderId'] == currentUserId)
              ? data['receiverId']
              : data['senderId'];

          // Nos quedamos con el mensaje más reciente
          if (!lastMessages.containsKey(otherUserId)) {
            lastMessages[otherUserId] = data;
          } else {
            final existingTs = lastMessages[otherUserId]!['timestamp'] as Timestamp;
            if (ts.toDate().isAfter(existingTs.toDate())) {
              lastMessages[otherUserId] = data;
            }
          }
        }

        // Ordenamos por fecha descendente
        final entries = lastMessages.entries.toList()
          ..sort((a, b) {
            final tA = a.value['timestamp'] as Timestamp;
            final tB = b.value['timestamp'] as Timestamp;
            return tB.toDate().compareTo(tA.toDate());
          });

        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (_, i) {
            final otherUserId = entries[i].key;
            final lastMsgData = entries[i].value;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserId)
                  .get(),
              builder: (ctx, usrSnapshot) {
                if (!usrSnapshot.hasData || !usrSnapshot.data!.exists) {
                  return const SizedBox.shrink();
                }

                final userData = usrSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox.shrink();

                final userName = userData['name'] ?? 'Usuario';
                final userPhoto = userData['photoUrl'] ?? '';

                // Mensajes no leídos (sender=otherUserId => receiver=currentUserId => isRead=false)
                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('messages')
                      .where('senderId', isEqualTo: otherUserId)
                      .where('receiverId', isEqualTo: currentUserId)
                      .where('isRead', isEqualTo: false)
                      .get(),
                  builder: (ctx2, unreadSnap) {
                    int unreadCount = 0;
                    if (unreadSnap.hasData) {
                      unreadCount = unreadSnap.data!.docs.length;
                    }

                    return Dismissible(
                      key: Key(otherUserId),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white, size: 32),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _deleteChat(otherUserId),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              userPhoto.isNotEmpty ? NetworkImage(userPhoto) : null,
                          backgroundColor: Colors.grey[300],
                        ),
                        title: Text(
                          userName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        // PREVIA del mensaje
                        subtitle: Text(
                          _buildMessagePreview(lastMsgData),
                          style: unreadCount > 0
                              ? const TextStyle(color: Colors.blue)
                              : null,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Hora
                            Text(
                              _formatTimestamp(lastMsgData['timestamp'] as Timestamp?),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            // Si hay mensajes no leídos, mostramos el número
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatPartnerId: otherUserId,
                                chatPartnerName: userName,
                                chatPartnerPhoto: userPhoto,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
