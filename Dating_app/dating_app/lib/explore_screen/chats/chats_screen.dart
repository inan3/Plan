import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  final String? sharedText; // Texto que llega si la app se selecciona en el panel de compartir.

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

  /// Muestra un diálogo que contiene el texto compartido.
  /// Desde aquí el usuario puede cerrar el diálogo o decidir enviarlo a un contacto.
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
                // Por ejemplo, podrías abrir una pantalla
                // para seleccionar el contacto al que enviar.
                // O podrías enviar directamente a un ChatScreen predefinido.
                Navigator.pop(context);

                // EJEMPLO: envía el texto a un chat con un ID "destUserId"
                // En un caso real, mostrarías una lista de contactos
                // y al elegir uno, harías algo así:
                String destUserId = "123456"; // Ejemplo
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatPartnerId: destUserId,
                      chatPartnerName: "Contacto Ejemplo",
                      chatPartnerPhoto: "",
                      // Podrías añadir un parámetro extra en ChatScreen para mandar el texto inicial
                      // Ej: initialMessage: text,
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

  /// Método de ejemplo para eliminar un chat, si tuvieras esa lógica.
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

  /// Convierte un [Timestamp] a un string con la hora para mostrar en la lista
  String _formatTimestamp(Timestamp? timestamp) {
    final date = timestamp?.toDate() ?? DateTime.now();
    return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
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

  /// Ejemplo de widget que muestra la lista de chats
  /// Tu lógica puede ser distinta según cómo guardes tus mensajes.
  Widget _buildChatList() {
    return StreamBuilder<QuerySnapshot>(
      // Suponiendo que guardas la lista de mensajes en 'messages'
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
        // Lógica de ejemplo para agrupar por último mensaje
        // (depende de cómo implementes tu base de datos)
        Map<String, Map<String, dynamic>> lastMessages = {};
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final Timestamp? ts = data['timestamp'];
          if (ts == null) continue;

          // Quien es el "otro" usuario
          final String otherUserId = (data['senderId'] == currentUserId)
              ? data['receiverId']
              : data['senderId'];

          // Si ya existe, chequea si este mensaje es más reciente
          if (!lastMessages.containsKey(otherUserId)) {
            lastMessages[otherUserId] = data;
          } else {
            final existingTs = lastMessages[otherUserId]!['timestamp'] as Timestamp;
            if (ts.toDate().isAfter(existingTs.toDate())) {
              lastMessages[otherUserId] = data;
            }
          }
        }

        // Ordenar por fecha descendente
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
                      backgroundImage: userPhoto.isNotEmpty ? NetworkImage(userPhoto) : null,
                      backgroundColor: Colors.grey[300],
                    ),
                    title: Text(
                      userName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(lastMsgData['text'] ?? ''),
                    trailing: Text(
                      _formatTimestamp(lastMsgData['timestamp'] as Timestamp?),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    onTap: () {
                      // Navega a la pantalla de chat individual
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
  }
}
