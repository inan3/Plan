import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  /// Controladores para el buscador
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

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
        {
          'deletedChats': {otherUserId: FieldValue.serverTimestamp()}
        },
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
      // Quitamos el AppBar y hacemos el encabezado manualmente
      body: SafeArea(
        child: Column(
          children: [
            // Encabezado "Chats" (a la izquierda) + botón de escribir (a la derecha)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    "Chats",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Botón con SVG
                  GestureDetector(
                    onTap: _openContactsDialog,
                    child: SvgPicture.asset(
                      'assets/icono-escribir.svg',
                      width: 28,
                      height: 28,
                    ),
                  ),
                ],
              ),
            ),
            // El resto: la lista de chats
            Expanded(child: _buildChatList()),
          ],
        ),
      ),
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
            final existingTs =
                lastMessages[otherUserId]!['timestamp'] as Timestamp;
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

                final userData =
                    usrSnapshot.data!.data() as Map<String, dynamic>?;
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
                        child: const Icon(Icons.delete,
                            color: Colors.white, size: 32),
                      ),
                      direction: DismissDirection.endToStart,

                      /// Aquí interceptamos el deslizamiento antes de eliminar
                      confirmDismiss: (direction) async {
                        final bool? result = await showDialog<bool>(
                          context: context,
                          builder: (ctx) {
                            return AlertDialog(
                              title: const Text("Confirmar eliminación"),
                              content: const Text(
                                  "¿Estás seguro de que quieres eliminar este chat?"),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(ctx).pop(false); // NO
                                  },
                                  child: const Text("No"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(ctx).pop(true); // SÍ
                                  },
                                  child: const Text("Sí"),
                                ),
                              ],
                            );
                          },
                        );

                        // Si result es true, sí elimina; si es false (o null), cancela el deslizamiento
                        return result == true;
                      },

                      /// Si confirmDismiss devolvió true, se ejecutará onDismissed
                      onDismissed: (_) => _deleteChat(otherUserId),

                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: userPhoto.isNotEmpty
                              ? NetworkImage(userPhoto)
                              : null,
                          backgroundColor: Colors.grey[300],
                        ),
                        title: Text(
                          userName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _buildMessagePreview(lastMsgData),
                          style: unreadCount > 0
                              ? const TextStyle(color: Colors.blue)
                              : null,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatTimestamp(
                                  lastMsgData['timestamp'] as Timestamp?),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
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

  /// Abre la ventana (draggable) ocupando el 90% de la pantalla para seleccionar contacto
  void _openContactsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Para que pueda ocupar el 90% de la altura
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.9,
          maxChildSize: 0.9,
          builder: (BuildContext context, ScrollController scrollController) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  // Degradado de fondo + borde redondeado arriba
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromARGB(255, 13, 32, 53),
                      Color.fromARGB(255, 72, 38, 38),
                      Color(0xFF12232E),
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // ----- Handle -----
                    Stack(
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white54,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ----- Título -----
                    const Center(
                      child: Text(
                        "¿Con quién contactar?",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // Forzamos blanco
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ----- Buscador -----
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Buscar usuario...",
                          hintStyle: const TextStyle(color: Colors.white70),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: () {
                              // Si quieres forzar la búsqueda manual aquí
                              // _searchUser(_searchController.text);
                            },
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white),
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onChanged: (val) {
                          if (val.isEmpty) {
                            setState(() {
                              _searchResults.clear();
                              _isSearching = false;
                            });
                          } else {
                            setState(() {
                              _isSearching = true;
                            });
                            _searchUser(val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ----- Todo lo que se desplaza -----
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        children: [
                          // Resultados de búsqueda (si estás buscando)
                          if (_isSearching) _buildSearchResults(),

                          // Sección: "Mis seguidores"
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              "Mis seguidores",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          _buildFollowersList(),

                          // Sección: "A quienes sigo"
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              "A quienes sigo",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          _buildFollowingList(),
                        ],
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

  /// Contenido interno de la ventana para seleccionar contacto
  Widget _buildContactsContent(ScrollController scrollController) {
    return Column(
      children: [
        const SizedBox(height: 16),
        // Stack para el handle y (si quisieras) un botón de cierre
        Stack(
          children: [
            // Handle centrado
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            "¿Con quién contactar?",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white, // Forzamos blanco
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Buscador
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Buscar usuario...",
              hintStyle: const TextStyle(color: Colors.white70),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {
                  // Búsqueda manual (si lo deseas)
                  // _searchUser(_searchController.text);
                },
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white),
                borderRadius: BorderRadius.circular(30),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            // Búsqueda en tiempo real
            onChanged: (val) {
              if (val.isEmpty) {
                setState(() {
                  _searchResults.clear();
                  _isSearching = false;
                });
              } else {
                setState(() {
                  _isSearching = true;
                });
                _searchUser(val); // Búsqueda por subcadena
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Resultados de búsqueda
                if (_isSearching) _buildSearchResults(),
                // Sección: "Mis seguidores"
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    "Mis seguidores",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildFollowersList(),
                // Sección: "A quienes sigo"
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    "A quienes sigo",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildFollowingList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Búsqueda POR SUBCADENA, en tiempo real
  Future<void> _searchUser(String query) async {
    try {
      // 1) Obtenemos TODOS los documentos de 'users'
      final snap = await FirebaseFirestore.instance.collection('users').get();

      // 2) Filtramos localmente por subcadena en 'name'
      final filtered = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'photoUrl': data['photoUrl'] ?? '',
          'age': data['age']?.toString() ?? '',
        };
      }).where((user) {
        final userName = user['name'].toString().toLowerCase();
        return userName.contains(query.toLowerCase());
      }).toList();

      setState(() {
        _searchResults = filtered;
      });
    } catch (e) {
      print("Error al buscar usuarios: $e");
    }
  }

  /// Genera la sección de resultados de la búsqueda
  Widget _buildSearchResults() {
    // Si no hay resultados, mostramos el mensaje requerido
    if (_searchResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text("El nombre de usuario especificado no existe"),
      );
    }
    return Column(
      children: _searchResults.map((user) {
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user['photoUrl'].isNotEmpty
                ? NetworkImage(user['photoUrl'])
                : null,
            backgroundColor: Colors.grey[300],
          ),
          title: Text(
            "${user['name']}",
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            "Edad: ${user['age']}",
            style: const TextStyle(color: Colors.white70),
          ),
          onTap: () => _openChatWithUser(
            user['id'],
            user['name'],
            user['photoUrl'],
          ),
        );
      }).toList(),
    );
  }

  /// Construye la lista de seguidores
  Widget _buildFollowersList() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('followers')
          .where('userId', isEqualTo: currentUserId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text("Aún no tienes seguidores."),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
          ),
          height: 250,
          child: ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (ctx, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              // El seguidor es data['followerId']
              final followerId = data['followerId'] ?? '';

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(followerId)
                    .get(),
                builder: (ctx2, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return const SizedBox.shrink();
                  }
                  final userData =
                      userSnap.data!.data() as Map<String, dynamic>;
                  final followerName = userData['name'] ?? 'Sin nombre';
                  final followerPhoto = userData['photoUrl'] ?? '';
                  final followerAge = userData['age']?.toString() ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: followerPhoto.isNotEmpty
                          ? NetworkImage(followerPhoto)
                          : null,
                      backgroundColor: Colors.grey[300],
                    ),
                    title: Text(
                      followerName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      "Edad: $followerAge",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    onTap: () => _openChatWithUser(
                      followerId,
                      followerName,
                      followerPhoto,
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  /// Construye la lista de a quienes sigo
  Widget _buildFollowingList() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('followed')
          .where('userId', isEqualTo: currentUserId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text("Aún no sigues a nadie."),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
          ),
          height: 250,
          child: ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (ctx, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              // A quién sigo: data['followedId']
              final followingId = data['followedId'] ?? '';

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(followingId)
                    .get(),
                builder: (ctx2, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return const SizedBox.shrink();
                  }
                  final userData =
                      userSnap.data!.data() as Map<String, dynamic>;
                  final followingName = userData['name'] ?? 'Sin nombre';
                  final followingPhoto = userData['photoUrl'] ?? '';
                  final followingAge = userData['age']?.toString() ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: followingPhoto.isNotEmpty
                          ? NetworkImage(followingPhoto)
                          : null,
                      backgroundColor: Colors.grey[300],
                    ),
                    title: Text(
                      followingName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      "Edad: $followingAge",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    onTap: () => _openChatWithUser(
                      followingId,
                      followingName,
                      followingPhoto,
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  /// Abre la pantalla de Chat con el usuario seleccionado
  void _openChatWithUser(String userId, String name, String photoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatPartnerId: userId,
          chatPartnerName: name,
          chatPartnerPhoto: photoUrl,
        ),
      ),
    );
  }
}
