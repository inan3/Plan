// image_share_sheet.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

class ImageShareSheet extends StatefulWidget {
  final String imageUrl;
  final ScrollController scrollController;

  const ImageShareSheet({
    Key? key,
    required this.imageUrl,
    required this.scrollController,
  }) : super(key: key);

  @override
  State<ImageShareSheet> createState() => _ImageShareSheetState();
}

class _ImageShareSheetState extends State<ImageShareSheet> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  final Set<String> _selectedUsers = {};

  @override
  void initState() {
    super.initState();
    _fetchFollowersAndFollowing();
  }

  // --------------------------------------------------------------------------
  //   Trae seguidores y seguidos EXACTAMENTE igual que PlanShareSheet
  // --------------------------------------------------------------------------
  Future<void> _fetchFollowersAndFollowing() async {
    if (_currentUser == null) return;

    try {
      // Seguidores
      final snapFollowers = await FirebaseFirestore.instance
          .collection('followers')
          .where('userId', isEqualTo: _currentUser!.uid)
          .get();

      final followerUids = <String>[];
      for (var doc in snapFollowers.docs) {
        final fid = doc.data()['followerId'] as String?;
        if (fid != null) followerUids.add(fid);
      }

      // Seguidos
      final snapFollowing = await FirebaseFirestore.instance
          .collection('followed')
          .where('userId', isEqualTo: _currentUser!.uid)
          .get();

      final followedUids = <String>[];
      for (var doc in snapFollowing.docs) {
        final fid = doc.data()['followedId'] as String?;
        if (fid != null) followedUids.add(fid);
      }

      _followers  = await _fetchUsersData(followerUids);
      _following  = await _fetchUsersData(followedUids);

      setState(() {});
    } catch (e) {
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUsersData(List<String> uids) async {
    final List<Map<String, dynamic>> usersData = [];
    for (String uid in uids) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        usersData.add({
          'uid'     : uid,
          'name'    : data['name'] ?? 'Usuario',
          'age'     : data['age']?.toString() ?? '',
          'photoUrl': data['photoUrl'] ?? data['profilePic'] ?? '',
        });
      }
    }
    return usersData;
  }

  // --------------------------------------------------------------------------
  //   UI
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 35, 57, 80),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white54,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // Compartir con apps externas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  "Compartir con otras apps",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () => Share.share(widget.imageUrl),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white54),

          // Contenido principal
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  // Barra superior Cancelar / Enviar
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text("Cancelar",
                            style: TextStyle(color: Colors.red, fontSize: 16)),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _sendImageToSelectedUsers,
                        child: const Text("Enviar",
                            style: TextStyle(color: Colors.green, fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Búsqueda
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Buscar usuario...",
                      hintStyle: const TextStyle(color: Colors.white60),
                      prefixIcon: const Icon(Icons.search, color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),

                  // Seguidores
                  _buildSectionTitle("Mis seguidores"),
                  _buildUserList(_filterUsers(_followers)),
                  const SizedBox(height: 12),

                  // Seguidos
                  _buildSectionTitle("A quienes sigo"),
                  _buildUserList(_filterUsers(_following)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  Widget _buildSectionTitle(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  //--------------------------------------------------------------------------  
  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> original) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return original;
    return original.where((u) {
      final name = (u['name'] ?? '').toLowerCase();
      return name.contains(q);
    }).toList();
  }

  //--------------------------------------------------------------------------  
  Widget _buildUserList(List<Map<String, dynamic>> users) {
    if (users.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text("No hay usuarios en esta sección.",
            style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
      );
    }

    return Column(
      children: users.map((u) {
        final uid   = u['uid'] as String;
        final name  = u['name'] as String? ?? 'Usuario';
        final age   = u['age']  as String? ?? '';
        final photo = u['photoUrl'] as String? ?? '';
        final isSel = _selectedUsers.contains(uid);

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blueGrey,
              backgroundImage: (photo.isNotEmpty) ? NetworkImage(photo) : null,
            ),
            title: Text(
              age.isNotEmpty ? "$name, $age" : name,
              style: const TextStyle(color: Colors.white),
            ),
            trailing: GestureDetector(
              onTap: () {
                setState(() {
                  if (isSel) {
                    _selectedUsers.remove(uid);
                  } else {
                    _selectedUsers.add(uid);
                  }
                });
              },
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSel ? Colors.green : Colors.white54, width: 2),
                  color : isSel ? Colors.green : Colors.transparent,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --------------------------------------------------------------------------
  Future<void> _sendImageToSelectedUsers() async {
    if (_currentUser == null || _selectedUsers.isEmpty) {
      Navigator.pop(context);
      return;
    }

    for (final uid in _selectedUsers) {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId'   : _currentUser!.uid,
        'receiverId' : uid,
        'participants': [_currentUser!.uid, uid],
        'type'       : 'image',
        'imageUrl'   : widget.imageUrl,
        'timestamp'  : FieldValue.serverTimestamp(),
        'isRead'     : false,
      });
    }
    Navigator.pop(context);
  }
}
