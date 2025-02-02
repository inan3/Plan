import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({Key? key}) : super(key: key);

  @override
  _ChatsScreenState createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  /// **Ocultar un chat para el usuario actual**
  Future<void> _hideChat(String otherUserId) async {
    try {
      DocumentReference userDoc =
          FirebaseFirestore.instance.collection('users').doc(currentUserId);

      await userDoc.set(
        {'hiddenChats': FieldValue.arrayUnion([otherUserId])},
        SetOptions(merge: true),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chat eliminado de tu bandeja.")),
      );
    } catch (e) {
      print("❌ Error al ocultar chat: $e");
    }
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
        stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          // **Verificar si el campo 'hiddenChats' existe antes de acceder a él**
          List<dynamic> hiddenChats = [];
          if (userSnapshot.data!.data() != null) {
            hiddenChats = (userSnapshot.data!.data() as Map<String, dynamic>)['hiddenChats'] ?? [];
          }

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

              Map<String, Map<String, dynamic>> lastMessages = {};
              for (var doc in snapshot.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                String otherUserId = (data['senderId'] == currentUserId)
                    ? data['receiverId']
                    : data['senderId'];

                if (hiddenChats.contains(otherUserId)) continue;

                if (!lastMessages.containsKey(otherUserId) ||
                    (data['timestamp'] != null &&
                        data['timestamp'].toDate().isAfter(
                            lastMessages[otherUserId]?['timestamp']?.toDate() ?? DateTime(0)))) {
                  lastMessages[otherUserId] = data;
                }
              }

              return ListView.builder(
                itemCount: lastMessages.length,
                itemBuilder: (context, index) {
                  String otherUserId = lastMessages.keys.elementAt(index);
                  var lastMessage = lastMessages[otherUserId]!;

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                        return const SizedBox.shrink();
                      }

                      var userData = userSnapshot.data!.data() as Map<String, dynamic>?;

                      if (userData == null) {
                        return const SizedBox.shrink();
                      }

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
                          _hideChat(otherUserId);
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: userData['photoUrl'] != null
                                ? NetworkImage(userData['photoUrl'])
                                : null,
                            backgroundColor: Colors.grey[300],
                          ),
                          title: Text(userData['name'] ?? 'Usuario'),
                          subtitle: Text(lastMessage['text'] ?? ''),
                          trailing: Text(
                            lastMessage['timestamp'] != null
                                ? _formatTimestamp(lastMessage['timestamp'])
                                : '',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  chatPartnerId: otherUserId,
                                  chatPartnerName: userData['name'] ?? 'Usuario',
                                  chatPartnerPhoto: userData['photoUrl'] ?? '',
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
      ),
    );
  }

  /// Convierte un `Timestamp` de Firestore en una hora legible.
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    DateTime date = timestamp.toDate();
    return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}
