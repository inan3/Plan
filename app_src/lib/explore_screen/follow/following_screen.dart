import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Eliminamos import innecesario de campanas:
// import 'package:flutter_svg/flutter_svg.dart';

import '../users_managing/user_info_check.dart';

/// Pantalla de seguidores/seguidos.
/// Se muestra como un modal a pantalla casi completa (deja libre el 10 % superior)
/// y permite alternar entre las dos listas además de filtrar por nombre.
class FollowingScreen extends StatefulWidget {
  /// UID del usuario cuyas listas se mostrarán
  final String userId;

  /// `true` => abre inicialmente en la pestaña de seguidores,
  /// `false` => abre inicialmente en la pestaña de seguidos
  final bool showFollowersFirst;

  const FollowingScreen({
    Key? key,
    required this.userId,
    this.showFollowersFirst = true,
  }) : super(key: key);

  /// Atajo estático para lanzar el modal con la animación típica de BottomSheet
  /// y dejando un margen del 10 % en la parte superior.
  static Future<void> show({
    required BuildContext context,
    required String userId,
    bool showFollowersFirst = true,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final height = MediaQuery.of(context).size.height;
        return Container(
          height: height * 0.9, // 90 % de la pantalla
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: FollowingScreen(
            userId: userId,
            showFollowersFirst: showFollowersFirst,
          ),
        );
      },
    );
  }

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  late bool _showFollowers;
  final TextEditingController _searchCtl = TextEditingController();

  /// Lista completa de usuarios
  List<_UserItem> _all = [];

  /// Lista filtrada según el buscador
  List<_UserItem> _filtered = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _showFollowers = widget.showFollowersFirst;
    _loadData();
    _searchCtl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final List<_UserItem> items = [];
      // Colección y campo cambian según pestaña
      final isFollowers = _showFollowers;
      final collection = isFollowers ? 'followers' : 'followed';
      final queryField = isFollowers ? 'userId' : 'userId';
      final linkField = isFollowers ? 'followerId' : 'followedId';

      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .where(queryField, isEqualTo: widget.userId)
          .get();

      for (final doc in snap.docs) {
        final relatedUid = doc.data()[linkField];

        final uDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(relatedUid)
            .get();
        if (uDoc.exists && uDoc.data() != null) {
          final data = uDoc.data()!;
          items.add(
            _UserItem(
              uid: relatedUid,
              name: data['name'] ?? 'Usuario',
              age: (data['age']?.toString() ?? '').isNotEmpty
                  ? data['age'].toString()
                  : null,
              photoUrl: data['photoUrl'] ?? '',
            ),
          );
        }
      }

      setState(() {
        _all = items;
        _filtered = List.from(_all);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final query = _searchCtl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = List.from(_all);
      } else {
        _filtered =
            _all.where((u) => u.name.toLowerCase().contains(query)).toList();
      }
    });
  }

  void _switchTab(bool followers) {
    if (_showFollowers == followers) return;
    setState(() {
      _showFollowers = followers;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Indicador tipo draggable
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Título principal dinámico
        Text(
          _showFollowers ? 'Seguidores' : 'Seguidos',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        // Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TabButton(
              label: 'Seguidores',
              selected: _showFollowers,
              onTap: () => _switchTab(true),
            ),
            const SizedBox(width: 16),
            _TabButton(
              label: 'Seguidos',
              selected: !_showFollowers,
              onTap: () => _switchTab(false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Buscador
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchCtl,
            decoration: InputDecoration(
              hintText: 'Buscar…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        // Lista
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? const Center(child: Text('Sin resultados'))
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const _ThinDivider(),
                      itemBuilder: (_, idx) {
                        final u = _filtered[idx];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(u.photoUrl.isNotEmpty
                                ? u.photoUrl
                                : 'https://via.placeholder.com/150'),
                          ),
                          title: Text(u.name),
                          subtitle: u.age != null ? Text('${u.age} años') : null,
                          trailing: null,
                          onTap: () {
                            // 1) Cerramos primero el modal
                            Navigator.of(context).pop();

                            // 2) Lanzamos la pantalla de perfil usando el rootNavigator
                            Future.microtask(() {
                              Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute(
                                  builder: (_) => UserInfoCheck(userId: u.uid),
                                ),
                              );
                            });
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton({
    Key? key,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: selected ? Colors.black : Colors.grey,
        ),
      ),
    );
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: 0.5,
        color: Colors.grey[300],
      ),
    );
  }
}

class _UserItem {
  final String uid;
  final String name;
  final String? age;
  final String photoUrl;

  _UserItem({
    required this.uid,
    required this.name,
    required this.age,
    required this.photoUrl,
  });
}
