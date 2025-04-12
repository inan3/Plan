import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart'; // <-- Importante para Share.share()

import '../users_managing/frosted_plan_dialog_state.dart' as new_frosted;
import '../../models/plan_model.dart';
import '../../main/colors.dart';
import '../../utils/plans_list.dart' as plansData;

/// ---------------------------------------------------------------------------
/// PANTALLA "Mis Planes", que muestra los planes creados por el usuario actual
/// y permite compartirlos con la misma lógica que en tus otras pantallas.
/// ---------------------------------------------------------------------------
class MyPlansScreen extends StatelessWidget {
  const MyPlansScreen({Key? key}) : super(key: key);

  // --------------------------------------------------------------------------
  // Método para obtener todos los participantes de un plan (creator + subs).
  // --------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(
      PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];
    // 2) Datos de suscripciones
    final subsSnap = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('id', isEqualTo: plan.id)
        .get();
    for (var sDoc in subsSnap.docs) {
      final sData = sDoc.data();
      final userId = sData['userId'];
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final uData = userDoc.data()!;
        participants.add({
          'uid': userId,
          'name': uData['name'] ?? 'Sin nombre',
          'age': uData['age']?.toString() ?? '',
          'photoUrl': uData['photoUrl'] ?? uData['profilePic'] ?? '',
          'isCreator': false,
        });
      }
    }

    return participants;
  }

  // --------------------------------------------------------------------------
  // Build principal
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(
        child: Text(
          'Debes iniciar sesión para ver tus planes.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('plans')
            .where('createdBy', isEqualTo: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No tienes planes aún.',
                style: TextStyle(color: Colors.black),
              ),
            );
          }

          // Convertimos cada doc a un PlanModel
          final plans = snapshot.data!.docs.map((doc) {
            final pData = doc.data() as Map<String, dynamic>;
            pData['id'] = doc.id; // Aseguramos que tenga el id
            return PlanModel.fromMap(pData);
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return _buildPlanCard(context, plan, index);
            },
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Construye cada tarjeta de plan
  // --------------------------------------------------------------------------
  Widget _buildPlanCard(BuildContext context, PlanModel plan, int index) {
    if (plan.special_plan == 1) {
      // Plan especial (estilo distinto)
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchAllPlanParticipants(plan),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: 100,
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueAccent, width: 2),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            );
          }

          final participants = snapshot.data!;
          final Widget creatorAvatar = participants.isNotEmpty &&
                  (participants[0]['photoUrl'] ?? '').toString().isNotEmpty
              ? CircleAvatar(
                  backgroundImage: NetworkImage(participants[0]['photoUrl']),
                  radius: 20,
                )
              : const CircleAvatar(radius: 20);
          final Widget participantAvatar = (participants.length > 1 &&
                  (participants[1]['photoUrl'] ?? '').toString().isNotEmpty)
              ? CircleAvatar(
                  backgroundImage: NetworkImage(participants[1]['photoUrl']),
                  radius: 20,
                )
              : const SizedBox();

          // Encontrar el icono desde la lista local
          String iconPath = plan.iconAsset ?? '';
          for (var item in plansData.plans) {
            if (plan.iconAsset == item['icon']) {
              iconPath = item['icon'];
              break;
            }
          }

          return GestureDetector(
            onTap: () {
              // Ir a la pantalla de detalles (FrostedPlanDialog)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: Colors.transparent,
                    body: new_frosted.FrostedPlanDialog(
                      plan: plan,
                      fetchParticipants: _fetchAllPlanParticipants,
                    ),
                  ),
                ),
              );
            },
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: 80,
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(color: Colors.blueAccent, width: 2),
                ),
                child: Row(
                  children: [
                    // Lado izquierdo: icono + tipo
                    Row(
                      children: [
                        if (iconPath.isNotEmpty)
                          SvgPicture.asset(
                            iconPath,
                            width: 40,
                            height: 40,
                            color: Colors.amber,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          plan.type,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Lado derecho: avatares
                    Row(
                      children: [
                        creatorAvatar,
                        const SizedBox(width: 8),
                        participantAvatar,
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } else {
      // Plan "normal"
      final String? backgroundImage = plan.backgroundImage;
      final String caption = plan.description.isNotEmpty
          ? plan.description
          : 'Descripción breve o #hashtags';
      const String sharesCount = '227';

      return GestureDetector(
        onTap: () {
          // FrostedPlanDialog
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: Colors.transparent,
                body: new_frosted.FrostedPlanDialog(
                  plan: plan,
                  fetchParticipants: _fetchAllPlanParticipants,
                ),
              ),
            ),
          );
        },
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: 330,
            margin: const EdgeInsets.only(bottom: 15),
            child: Stack(
              children: [
                // Imagen de fondo
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: (backgroundImage != null && backgroundImage.isNotEmpty)
                      ? Image.network(
                          backgroundImage,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
                // Botón compartir + eliminar (esquina sup der)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botón compartir
                      GestureDetector(
                        onTap: () {
                          _openCustomShareModal(context, plan);
                        },
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  'assets/compartir.svg',
                                  width: 20,
                                  height: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botón eliminar
                      GestureDetector(
                        onTap: () => _confirmDeletePlan(context, plan),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Parte inferior: contadores + descripción
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.5),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildIconText(
                                  icon: Icons.favorite_border,
                                  label: plan.likes.toString(),
                                ),
                                const SizedBox(width: 25),
                                // commentsCount en tiempo real
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('plans')
                                      .doc(plan.id)
                                      .snapshots(),
                                  builder: (context, snap) {
                                    if (!snap.hasData || !snap.data!.exists) {
                                      return _buildIconText(
                                        icon: Icons.chat_bubble_outline,
                                        label: '0',
                                      );
                                    }
                                    final data =
                                        snap.data!.data() as Map<String, dynamic>;
                                    final count = data['commentsCount'] ?? 0;
                                    return _buildIconText(
                                      icon: Icons.chat_bubble_outline,
                                      label: count.toString(),
                                    );
                                  },
                                ),
                                const SizedBox(width: 25),
                                _buildIconText(
                                  icon: Icons.share,
                                  label: sharesCount,
                                ),
                                const Spacer(),
                                // participantes / max
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('plans')
                                      .doc(plan.id)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return Row(
                                        children: [
                                          const Text(
                                            '0/0',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          SvgPicture.asset(
                                            'assets/users.svg',
                                            color: AppColors.blue,
                                            width: 20,
                                            height: 20,
                                          ),
                                        ],
                                      );
                                    }
                                    if (!snapshot.data!.exists) {
                                      return const SizedBox();
                                    }
                                    final updatedData = snapshot.data!.data()
                                        as Map<String, dynamic>;
                                    final List<dynamic> updatedParticipants =
                                        updatedData['participants']
                                                as List<dynamic>? ??
                                            [];
                                    final int participantes =
                                        updatedParticipants.length;
                                    final int maxPart =
                                        updatedData['maxParticipants'] ??
                                            plan.maxParticipants ??
                                            0;
                                    return Row(
                                      children: [
                                        Text(
                                          '$participantes/$maxPart',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        SvgPicture.asset(
                                          'assets/users.svg',
                                          color: AppColors.blue,
                                          width: 20,
                                          height: 20,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              caption,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Lógica para abrir el bottom sheet con la lista de seguidores/seguidos
  // (misma que en tus otras pantallas)
  // --------------------------------------------------------------------------
  void _openCustomShareModal(BuildContext context, PlanModel plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 35, 57, 80),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Pequeño "handle" para arrastrar
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

                  // Botón para "Compartir con otras apps"
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          "Compartir con otras apps",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.white),
                          onPressed: () {
                            final String shareUrl =
                                'https://plan-social-app.web.app/plan?planId=${plan.id}';
                            final shareText =
                                '¡Mira este plan!\n\nTítulo: ${plan.type}\nDescripción: ${plan.description}\n$shareUrl';
                            Share.share(shareText);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Sección para compartir dentro de la app (seguidores/seguidos)
                  Expanded(
                    child: _CustomShareDialogContent(
                      plan: plan,
                      scrollController: scrollController,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Popup de confirmación para eliminar el plan
  // --------------------------------------------------------------------------
  void _confirmDeletePlan(BuildContext context, PlanModel plan) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("¿Eliminar este plan?"),
          content: Text("Esta acción eliminará el plan ${plan.type}."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                // 1) Eliminar el plan
                await FirebaseFirestore.instance
                    .collection('plans')
                    .doc(plan.id)
                    .delete();
                // 2) Eliminar suscripciones relacionadas
                final subs = await FirebaseFirestore.instance
                    .collection('subscriptions')
                    .where('id', isEqualTo: plan.id)
                    .get();
                for (var doc in subs.docs) {
                  await doc.reference.delete();
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Plan ${plan.type} eliminado correctamente.'),
                  ),
                );
              },
              child: const Text("Eliminar"),
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Placeholder si no hay imagen
  // --------------------------------------------------------------------------
  Widget _buildPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.grey[200],
        height: 350,
        width: double.infinity,
        child: const Center(
          child: Icon(Icons.image, size: 40, color: Colors.grey),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Helper para icono + texto
  // --------------------------------------------------------------------------
  Widget _buildIconText({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// --------------------------------------------------------------------------
/// Clase que muestra la lógica para compartir dentro de la app (seguidores, etc.)
/// Copiada o adaptada de tus otras pantallas (SubscribedPlansScreen, etc.).
/// --------------------------------------------------------------------------
class _CustomShareDialogContent extends StatefulWidget {
  final PlanModel plan;
  final ScrollController scrollController;

  const _CustomShareDialogContent({
    Key? key,
    required this.plan,
    required this.scrollController,
  }) : super(key: key);

  @override
  State<_CustomShareDialogContent> createState() =>
      _CustomShareDialogContentState();
}

class _CustomShareDialogContentState extends State<_CustomShareDialogContent> {
  final TextEditingController _searchController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Listas de usuarios (followers / following)
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];

  // Conjunto de UIDs seleccionados
  final Set<String> _selectedUsers = {};

  @override
  void initState() {
    super.initState();
    _fetchFollowersAndFollowing();
  }

  /// Cargar "followers" y "followed" desde Firestore
  Future<void> _fetchFollowersAndFollowing() async {
    if (_currentUser == null) return;

    try {
      // 1) followers => docs donde userId = mi UID
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

      // 2) followed => docs donde userId = mi UID
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

      // 3) Obtenemos la info de cada uno
      _followers = await _fetchUsersData(followerUids);
      _following = await _fetchUsersData(followedUids);

      setState(() {});
    } catch (e) {
      debugPrint("Error al cargar followers/following: $e");
    }
  }

  /// Dado un listado de UIDs, retornamos la info de cada user (nombre, foto, etc.)
  Future<List<Map<String, dynamic>>> _fetchUsersData(List<String> uids) async {
    if (uids.isEmpty) return [];
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

  /// Cuando pulsamos “Enviar”, compartimos el plan con los usuarios seleccionados
  Future<void> _sendPlanToSelectedUsers() async {
    if (_currentUser == null || _selectedUsers.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final String shareUrl =
        'https://plan-social-app.web.app/plan?planId=${widget.plan.id}';
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

    Navigator.pop(context); // cerrar bottom sheet
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra superior con “Cancelar” y “Enviar”
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  "Cancelar",
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _sendPlanToSelectedUsers,
                child: const Text(
                  "Enviar",
                  style: TextStyle(color: Colors.green, fontSize: 16),
                ),
              ),
            ],
          ),
        ),

        // Buscador
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
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
            onChanged: (_) {
              setState(() {}); // Para refrescar el filtrado
            },
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título "Mis seguidores"
                const SizedBox(height: 6),
                const Text(
                  "Mis seguidores",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                _buildUserList(_filterUsers(_followers)),

                const SizedBox(height: 12),
                // Título "A quienes sigo"
                const Text(
                  "A quienes sigo",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                _buildUserList(_filterUsers(_following)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Filtrado según el texto de búsqueda
  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> users) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return users;
    return users.where((u) {
      final name = u['name'].toString().toLowerCase();
      return name.contains(query);
    }).toList();
  }

  /// Lista de usuarios con un “checkbox” para seleccionar
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
        final uid = user['uid'] ?? '';
        final name = user['name'] ?? 'Usuario';
        final age = user['age'] ?? '';
        final photo = user['photoUrl'] ?? '';
        final isSelected = _selectedUsers.contains(uid);

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: CircleAvatar(
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
}
