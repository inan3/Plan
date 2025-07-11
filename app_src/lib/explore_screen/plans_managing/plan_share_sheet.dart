import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../models/plan_model.dart';
import '../users_grid/users_grid_helpers.dart'; // Para funciones de ayuda si hiciera falta
import '../../main/colors.dart';
import '../../l10n/app_localizations.dart';

/// Muestra un bottom sheet para compartir el plan con seguidores/seguidos,
/// y también la opción de compartir con otras apps.
class PlanShareSheet extends StatefulWidget {
  final PlanModel plan;
  final ScrollController scrollController;

  const PlanShareSheet({
    Key? key,
    required this.plan,
    required this.scrollController,
  }) : super(key: key);

  @override
  State<PlanShareSheet> createState() => PlanShareSheetState();
}

class PlanShareSheetState extends State<PlanShareSheet> {
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

  Future<void> _fetchFollowersAndFollowing() async {
    if (_currentUser == null) return;

    try {
      final snapFollowers = await FirebaseFirestore.instance
          .collection('followers')
          .where('userId', isEqualTo: _currentUser!.uid)
          .get();

      final followerUids = <String>[];
      for (var doc in snapFollowers.docs) {
        final data = doc.data();
        final fid = data['followerId'] as String?;
        if (fid != null) followerUids.add(fid);
      }

      final snapFollowing = await FirebaseFirestore.instance
          .collection('followed')
          .where('userId', isEqualTo: _currentUser!.uid)
          .get();

      final followedUids = <String>[];
      for (var doc in snapFollowing.docs) {
        final data = doc.data();
        final fid = data['followedId'] as String?;
        if (fid != null) followedUids.add(fid);
      }

      _followers = await _fetchUsersData(followerUids);
      _following = await _fetchUsersData(followedUids);
      setState(() {});
    } catch (e) {}
  }

  Future<List<Map<String, dynamic>>> _fetchUsersData(List<String> uids) async {
    final List<Map<String, dynamic>> usersData = [];
    for (String uid in uids) {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        usersData.add({
          'uid': uid,
          'name': data['name'] ?? 'Usuario',
          'age': data['age']?.toString() ?? '',
          'photoUrl': data['photoUrl'] ?? '',
        });
      }
    }
    return usersData;
  }


  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final String planTitle = widget.plan.type;
    final String planDesc = widget.plan.description;
    final String webLink = 'https://plansocialapp.es/plan?planId=${widget.plan.id}';
    final String shareText =
        '¡Mira este plan!\nTítulo: $planTitle\nDescripción: $planDesc\n\n$webLink';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.shareSheetBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white54,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // Botón "Compartir con otras apps"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _sharePlanWithImage,
              icon: const Icon(Icons.share, color: Colors.white),
              label: Text(
                t.shareWithOtherApps,
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.planColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          const Divider(color: Colors.white54),

          // Contenido principal: enviar plan a usuarios (followers/following)
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  // Barra superior
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          t.cancel,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _sendPlanToSelectedUsers,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.planColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          t.send,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Cuadro de búsqueda
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: t.searchUserHint,
                      hintStyle: const TextStyle(color: Colors.white60),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white60),
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

                  // Lista “Mis seguidores”
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t.myFollowers,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildUserList(_filterUsers(_followers)),

                  const SizedBox(height: 12),
                  // Lista “A quienes sigo”
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t.usersIFollow,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildUserList(_filterUsers(_following)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  //--------------------------------------------------------------------------
  // Filtra usuarios según lo que se escribe en la barra de búsqueda.
  //--------------------------------------------------------------------------
  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> original) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return original;
    return original.where((user) {
      final name = (user['name'] ?? '').toLowerCase();
      return name.contains(query);
    }).toList();
  }

  //--------------------------------------------------------------------------
  // Lista de usuarios (seguidores o siguiendo)
  //--------------------------------------------------------------------------
  Widget _buildUserList(List<Map<String, dynamic>> userList) {
    if (userList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "No hay usuarios en esta sección.",
          style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Column(
      children: userList.map((user) {
        final uid = user['uid'] as String? ?? '';
        final name = user['name'] as String? ?? 'Usuario';
        final age = user['age'] as String? ?? '';
        final photo = user['photoUrl'] as String? ?? '';
        final isSelected = _selectedUsers.contains(uid);

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
              "$name, $age",
              style: const TextStyle(color: Colors.white),
            ),
            trailing: GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedUsers.remove(uid);
                  } else {
                    _selectedUsers.add(uid);
                  }
                });
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.green : Colors.white54,
                    width: 2,
                  ),
                  color: isSelected ? Colors.green : Colors.transparent,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  //--------------------------------------------------------------------------
  // Comparte el plan con imagen descargada (si la hay)
  //--------------------------------------------------------------------------
  Future<void> _sharePlanWithImage() async {
    final String planTitle = widget.plan.type;
    final String planDesc = widget.plan.description;
    final String webLink = 'https://plansocialapp.es/plan?planId=${widget.plan.id}';
    final String shareText =
        '¡Mira este plan!\nTítulo: $planTitle\nDescripción: $planDesc\n\n$webLink';

    final imageUrl = widget.plan.backgroundImage ??
        ((widget.plan.images != null && widget.plan.images!.isNotEmpty)
            ? widget.plan.images!.first
            : null);

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(imageUrl));
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/plan_share.jpg');
        await file.writeAsBytes(response.bodyBytes);
        await Share.shareXFiles([XFile(file.path)], text: shareText);
        return;
      } catch (_) {
        // Si falla la descarga, continúa con un share de texto simple
      }
    }

    await Share.share(shareText);
  }

  //--------------------------------------------------------------------------
  // Envía un mensaje con el plan a los usuarios seleccionados
  //--------------------------------------------------------------------------
  Future<void> _sendPlanToSelectedUsers() async {
    if (_currentUser == null || _selectedUsers.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final String shareUrl =
        'https://plansocialapp.es/plan?planId=${widget.plan.id}';
    final String planId = widget.plan.id;
    final String planTitle = widget.plan.type;
    final String planDesc = widget.plan.description;
    final String? planImage = widget.plan.backgroundImage;

    for (String uidDestino in _selectedUsers) {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': _currentUser!.uid,
        'receiverId': uidDestino,
        'participants': [_currentUser!.uid, uidDestino],
        'type': 'shared_plan',
        'planId': planId,
        'planTitle': planTitle,
        'planDescription': planDesc,
        'planImage': planImage ?? '',
        'planLink': shareUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }

    await FirebaseFirestore.instance
        .collection('plans')
        .doc(widget.plan.id)
        .update({'share_count': FieldValue.increment(1)});

    Navigator.pop(context);
  }
}
