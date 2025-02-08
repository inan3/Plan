import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  _ChatsScreenState createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Elimina un chat guardando el timestamp de eliminación para el usuario actual.
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

  /// Convierte un Timestamp en una hora legible.
  String _formatTimestamp(Timestamp? timestamp) {
    DateTime date = timestamp?.toDate() ?? DateTime.now();
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          // Se obtienen los chats eliminados y sus timestamps.
          Map<String, dynamic> deletedChats =
              (userSnapshot.data!.data() as Map<String, dynamic>)['deletedChats'] ??
                  {};

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
                return const Center(
                  child: Text(
                    "No tienes mensajes aún.",
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                );
              }

              // Map para almacenar el último mensaje por cada conversación (con otro usuario).
              Map<String, Map<String, dynamic>> lastMessages = {};

              for (var doc in snapshot.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;

                // Determinar el otro usuario según senderId y receiverId.
                String otherUserId = (data['senderId'] == currentUserId)
                    ? data['receiverId']
                    : data['senderId'];

                // Verificar que 'timestamp' sea un Timestamp válido.
                if (data['timestamp'] is! Timestamp) continue;
                Timestamp messageTimestamp = data['timestamp'] as Timestamp;

                // Si existe un 'deletedAt' para este chat, solo se toman mensajes posteriores a esa fecha.
                Timestamp? deletedAt = deletedChats[otherUserId] is Timestamp
                    ? deletedChats[otherUserId] as Timestamp
                    : null;
                if (deletedAt != null &&
                    messageTimestamp.toDate().isBefore(deletedAt.toDate())) {
                  continue;
                }

                // Si ya existe un mensaje para este chat, se compara el timestamp.
                if (lastMessages.containsKey(otherUserId)) {
                  Timestamp existingTimestamp =
                      lastMessages[otherUserId]!['timestamp'] as Timestamp;
                  if (messageTimestamp.toDate().isAfter(existingTimestamp.toDate())) {
                    lastMessages[otherUserId] = data;
                  }
                } else {
                  lastMessages[otherUserId] = data;
                }
              }

              // Convertir el mapa a una lista de entradas y ordenarlas por timestamp descendente.
              List<MapEntry<String, Map<String, dynamic>>> sortedEntries =
                  lastMessages.entries.toList();
              sortedEntries.sort((a, b) {
                Timestamp aTimestamp = a.value['timestamp'] as Timestamp;
                Timestamp bTimestamp = b.value['timestamp'] as Timestamp;
                return bTimestamp.toDate().compareTo(aTimestamp.toDate());
              });

              return ListView.builder(
              itemCount: sortedEntries.length,
              itemBuilder: (context, index) {
                String otherUserId = sortedEntries[index].key;
                var lastMessage = sortedEntries[index].value;

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                      return const SizedBox.shrink();
                    }
                    var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                    if (userData == null) return const SizedBox.shrink();

                    return Dismissible(
                      key: Key(otherUserId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white, size: 32),
                      ),
                      onDismissed: (direction) {
                        _deleteChat(otherUserId);
                      },
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                chatPartnerId: otherUserId,
                                chatPartnerName: userData['name'] ?? 'Usuario',
                                chatPartnerPhoto: userData['photoUrl'] ?? '',
                                deletedAt: deletedChats[otherUserId] is Timestamp
                                    ? deletedChats[otherUserId] as Timestamp
                                    : null,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Foto de perfil (Contenedor 1)
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: (userData['photoUrl'] != null &&
                                        userData['photoUrl'].toString().isNotEmpty)
                                    ? NetworkImage(userData['photoUrl'])
                                    : null,
                                backgroundColor: Colors.grey[300],
                              ),
                              const SizedBox(width: 12),
                              // Nombre y último mensaje (Contenedor 2)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userData['name'] ?? 'Usuario',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lastMessage['text'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Hora del último mensaje.
                              Text(
                                _formatTimestamp(
                                  lastMessage['timestamp'] is Timestamp
                                      ? lastMessage['timestamp'] as Timestamp
                                      : null,
                                ),
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );


            },
          );
        },
      ),
    );
  }
}
