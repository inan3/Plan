//chats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../l10n/app_localizations.dart';
import '../users_managing/user_activity_status.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  final String? sharedText;

  const ChatsScreen({Key? key, this.sharedText}) : super(key: key);

  @override
  _ChatsScreenState createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  /// Mapa que guarda para cada "otroUsuarioId" la fecha en que el usuario actual
  /// borró el chat: _deletedAtMap[otroId] = Timestamp
  Map<String, Timestamp> _deletedAtMap = {};

  @override
  void initState() {
    super.initState();

    // Muestra un diálogo si trae texto compartido
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
                // Ejemplo: envía el texto a un chat con un ID "destUserId"
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

  /// Elimina el chat con [otherUserId] para el usuario actual.
  /// Marca la fecha en "deletedChats.otherUserId = now".
  Future<void> _deleteChat(String otherUserId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUserId).set(
        {
          'deletedChats': {otherUserId: FieldValue.serverTimestamp()}
        },
        SetOptions(merge: true),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chat eliminado.")),
      );
    } catch (e) {
    }
  }

  /// Convierte un Timestamp a string "HH:mm"
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return "$hh:$mm";
  }

  /// Construye el preview del último mensaje
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
      // imagen, ubicación, etc.
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
    return FutureBuilder<DocumentSnapshot>(
      // Primero leemos el doc del usuario actual para cargar 'deletedChats'
      future:
          FirebaseFirestore.instance.collection('users').doc(currentUserId).get(),
      builder: (ctx, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!userSnap.hasData || !userSnap.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("No existe el usuario actual.")),
          );
        }

        // Extraemos 'deletedChats'
        final userDataRaw = userSnap.data!.data();
        if (userDataRaw is Map<String, dynamic>) {
          final deletedMap = userDataRaw['deletedChats'];
          if (deletedMap is Map) {
            _deletedAtMap.clear();
            for (var entry in deletedMap.entries) {
              final otherId = entry.key;
              final val = entry.value;
              if (val is Timestamp) {
                _deletedAtMap[otherId] = val;
              }
            }
          }
        }

        // Construimos la UI con un StreamBuilder de mensajes
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Cabecera "Chats" + icono de escribir
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                // El resto: lista de chats
                Expanded(child: _buildChatList()),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Construye la lista de últimos chats
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
        // Map: otherUserId -> { ... lastMessageData ... }
        final Map<String, Map<String, dynamic>> lastMessages = {};

        for (var doc in docs) {
          final raw = doc.data();
          if (raw is! Map<String, dynamic>) continue;
          final data = raw;

          final ts = data['timestamp'];
          if (ts is! Timestamp) continue;

          // Determinamos el "otro" usuario
          final sender = data['senderId']?.toString() ?? '';
          final receiver = data['receiverId']?.toString() ?? '';
          final otherUserId = (sender == currentUserId) ? receiver : sender;
          if (otherUserId.isEmpty) continue;

          // Filtrar por deletedAt
          final userDeletedAt = _deletedAtMap[otherUserId];
          if (userDeletedAt != null) {
            if (ts.toDate().isBefore(userDeletedAt.toDate())) {
              // Si es anterior a la fecha de borrado, lo saltamos
              continue;
            }
          }

          // Quedarnos con el más reciente
          if (!lastMessages.containsKey(otherUserId)) {
            lastMessages[otherUserId] = data;
          } else {
            final oldTs = lastMessages[otherUserId]!['timestamp'] as Timestamp;
            if (ts.toDate().isAfter(oldTs.toDate())) {
              lastMessages[otherUserId] = data;
            }
          }
        }

        // Ordenamos por timestamp desc
        final entries = lastMessages.entries.toList()
          ..sort((a, b) {
            final tA = a.value['timestamp'] as Timestamp;
            final tB = b.value['timestamp'] as Timestamp;
            return tB.toDate().compareTo(tA.toDate());
          });

        if (entries.isEmpty) {
          return const Center(child: Text("No tienes mensajes aún."));
        }

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

                final userRaw = usrSnapshot.data!.data();
                if (userRaw is! Map<String, dynamic>) {
                  return const SizedBox.shrink();
                }
                final userData = userRaw;

                final userName = userData['name']?.toString() ?? 'Usuario';
                final userPhoto = userData['photoUrl']?.toString() ?? '';

                // Contar no leídos de otherUserId -> currentUserId
                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('messages')
                      .where('participants', arrayContains: currentUserId)
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
                                    Navigator.of(ctx).pop(false);
                                  },
                                  child: const Text("No"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(ctx).pop(true);
                                  },
                                  child: const Text("Sí"),
                                ),
                              ],
                            );
                          },
                        );
                        return result == true;
                      },
                      onDismissed: (_) => _deleteChat(otherUserId),

                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: (userPhoto.isNotEmpty)
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
                                lastMsgData['timestamp'] as Timestamp?,
                              ),
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

  /// Abre el modal arrastrable para seleccionar contacto
  void _openContactsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // para ocupar 90% de altura
      isDismissible: true, // cerrar al tocar fuera
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.9,
          maxChildSize: 0.9,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            final t = AppLocalizations.of(context);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
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
                    Center(
                      child: Text(
                        t.whoToContact,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: t.searchUserHint,
                          hintStyle: const TextStyle(color: Colors.white70),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: () {
                              // Búsqueda manual
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
                            setState(() => _isSearching = true);
                            _searchUser(val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        children: [
                          if (_isSearching) _buildSearchResults(),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              t.myFollowers,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          _buildFollowersList(),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              t.usersIFollow,
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

  /// Búsqueda por subcadena en 'name'
  Future<void> _searchUser(String query) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      final filtered = snap.docs.map((doc) {
        final raw = doc.data();
        if (raw is! Map<String, dynamic>) return null;
        final data = raw;
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'photoUrl': data['photoUrl'] ?? '',
          'age': data['age']?.toString() ?? '',
          'profile_privacy': data['profile_privacy'] ?? 0,
        };
      }).where((u) {
        if (u == null) return false;
        final userName = u['name'].toString().toLowerCase();
        return userName.contains(query.toLowerCase());
      }).cast<Map<String, dynamic>>().toList();

      setState(() {
        _searchResults = filtered;
      });
    } catch (e) {
    }
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text(
          AppLocalizations.of(context).usernameNotFound,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    return Column(
      children: _searchResults.map((user) {
        final name = user['name'] ?? 'Desconocido';
        final photoUrl = user['photoUrl'] ?? '';
        final age = user['age'] ?? '';
        final level = user['privilegeLevel'] ?? 'Básico';
        final isPrivate = user['profile_privacy'] == 1;

        return ListTile(
          leading: CircleAvatar(
            backgroundImage:
                (photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
            backgroundColor: Colors.grey[300],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Image.asset(
                _getPrivilegeIcon(level),
                width: 14,
                height: 14,
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${AppLocalizations.of(context).age}: $age",
                style: const TextStyle(color: Colors.white70),
              ),
              UserActivityStatus(userId: user['id'] as String),
            ],
          ),
          onTap: () => _openChatWithUser(
            user['id'].toString(),
            name,
            photoUrl,
            isPrivate,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFollowersList() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('followers')
          .where('userId', isEqualTo: currentUserId)
          .get(),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              AppLocalizations.of(context).noFollowersYet,
              style: const TextStyle(color: Colors.white70),
            ),
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
              final rawDoc = snapshot.data!.docs[index].data();
              if (rawDoc is! Map<String, dynamic>) return const SizedBox();
              final data = rawDoc;

              final followerId = data['followerId']?.toString() ?? '';
              if (followerId.isEmpty) return const SizedBox();

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(followerId)
                    .get(),
                builder: (ctx2, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return const SizedBox.shrink();
                  }
                  final rawUser = userSnap.data!.data();
                  if (rawUser is! Map<String, dynamic>) {
                    return const SizedBox.shrink();
                  }
                  final uData = rawUser;

                  final followerName = uData['name']?.toString() ?? 'Sin nombre';
                  final followerPhoto = uData['photoUrl']?.toString() ?? '';
                  final followerAge = uData['age']?.toString() ?? '';
                  final level = uData['privilegeLevel'] ?? 'Básico';
                  final isPrivate = (uData['profile_privacy'] ?? 0) == 1;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (followerPhoto.isNotEmpty)
                          ? NetworkImage(followerPhoto)
                          : null,
                      backgroundColor: Colors.grey[300],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            followerName,
                            style: const TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Image.asset(
                          _getPrivilegeIcon(level),
                          width: 14,
                          height: 14,
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${AppLocalizations.of(context).age}: $followerAge",
                          style: const TextStyle(color: Colors.white70),
                        ),
                        UserActivityStatus(userId: followerId),
                      ],
                    ),
                    onTap: () => _openChatWithUser(
                      followerId,
                      followerName,
                      followerPhoto,
                      isPrivate,
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

  Widget _buildFollowingList() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('followed')
          .where('userId', isEqualTo: currentUserId)
          .get(),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              AppLocalizations.of(context).notFollowingAnyone,
              style: const TextStyle(color: Colors.white70),
            ),
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
              final rawDoc = snapshot.data!.docs[index].data();
              if (rawDoc is! Map<String, dynamic>) return const SizedBox();
              final data = rawDoc;

              final followingId = data['followedId']?.toString() ?? '';
              if (followingId.isEmpty) return const SizedBox();

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(followingId)
                    .get(),
                builder: (ctx2, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return const SizedBox.shrink();
                  }
                  final rawUser = userSnap.data!.data();
                  if (rawUser is! Map<String, dynamic>) {
                    return const SizedBox.shrink();
                  }
                  final uData = rawUser;

                  final followingName = uData['name']?.toString() ?? 'Sin nombre';
                  final followingPhoto = uData['photoUrl']?.toString() ?? '';
                  final followingAge = uData['age']?.toString() ?? '';
                  final level = uData['privilegeLevel'] ?? 'Básico';
                  final isPrivate = (uData['profile_privacy'] ?? 0) == 1;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (followingPhoto.isNotEmpty)
                          ? NetworkImage(followingPhoto)
                          : null,
                      backgroundColor: Colors.grey[300],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            followingName,
                            style: const TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Image.asset(
                          _getPrivilegeIcon(level),
                          width: 14,
                          height: 14,
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${AppLocalizations.of(context).age}: $followingAge",
                          style: const TextStyle(color: Colors.white70),
                        ),
                        UserActivityStatus(userId: followingId),
                      ],
                    ),
                    onTap: () => _openChatWithUser(
                      followingId,
                      followingName,
                      followingPhoto,
                      isPrivate,
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

  /// Comprueba si es privado y si no lo sigo, no deja abrir el chat
  Future<void> _openChatWithUser(
    String userId,
    String name,
    String photoUrl,
    bool isUserPrivate,
  ) async {
    if (isUserPrivate) {
      final me = FirebaseAuth.instance.currentUser;
      if (me == null) return;

      final q = await FirebaseFirestore.instance
          .collection('followed')
          .where('userId', isEqualTo: me.uid)
          .where('followedId', isEqualTo: userId)
          .limit(1)
          .get();

      final amIFollowing = q.docs.isNotEmpty;

      if (!amIFollowing) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Perfil privado"),
            content:
                const Text("Debes seguir a este usuario para interactuar."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cerrar"),
              ),
            ],
          ),
        );
        return;
      }
    }

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

  String _getPrivilegeIcon(String level) {
    final normalized = level.toLowerCase().replaceAll('á', 'a');
    switch (normalized) {
      case 'premium':
        return 'assets/icono-usuario-premium.png';
      case 'golden':
        return 'assets/icono-usuario-golden.png';
      case 'vip':
        return 'assets/icono-usuario-vip.png';
      default:
        return 'assets/icono-usuario-basico.png';
    }
  }
}
