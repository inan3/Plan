import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart'; // Asegúrate de tener share_plus en tu pubspec

// 1) Importamos el archivo con el diálogo FrostedPlanDialog real:
import '../users_managing/frosted_plan_dialog_state.dart' as new_frosted;
import '../users_managing/user_info_check.dart' as profile_readonly;

import '../../models/plan_model.dart';
import '../../main/colors.dart';

/// ---------------------------------------------------------------------------
/// PANTALLA de planes "favoritos" del usuario
/// ---------------------------------------------------------------------------
class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({Key? key}) : super(key: key);

  // ------------------------------------------------------------------------
  // Obtener todos los participantes (creador + suscriptores) de un plan
  // ------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(
    PlanModel plan,
  ) async {
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
          'uid': userId, // <--- TAMBIÉN AQUÍ
          'name': uData['name'] ?? 'Sin nombre',
          'age': uData['age']?.toString() ?? '',
          'photoUrl': uData['photoUrl'] ?? uData['profilePic'] ?? '',
          'isCreator': false,
        });
      }
    }

    return participants;
  }

  // ------------------------------------------------------------------------
  // Pantalla principal: planes marcados como favoritos
  // ------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(
        child: Text(
          'Usuario no autenticado',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    // Leemos el doc del usuario para obtener su array de 'favourites'
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(
            child: Text(
              'No tienes planes favoritos aún.',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final favouritePlanIds = List<String>.from(data['favourites'] ?? []);

        if (favouritePlanIds.isEmpty) {
          return const Center(
            child: Text(
              'No tienes planes favoritos aún.',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        // Ahora cargamos los PlanModels de cada id en 'favourites'
        return FutureBuilder<List<PlanModel>>(
          future: _fetchPlansFromIds(favouritePlanIds),
          builder: (context, planSnapshot) {
            if (!planSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final plans = planSnapshot.data!;
            if (plans.isEmpty) {
              return const Center(
                child: Text(
                  'No tienes planes favoritos aún.',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                // Obtenemos info del creador de cada plan
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(plan.createdBy)
                      .get(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 330,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (userSnapshot.hasError ||
                        !userSnapshot.hasData ||
                        !userSnapshot.data!.exists) {
                      return const SizedBox(
                        height: 330,
                        child: Center(
                          child: Text(
                            'Error al cargar creador del plan',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    }

                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    return _buildPlanCard(context, userData, plan);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------------------
  // Obtener planes completos desde la colección 'plans'
  // ------------------------------------------------------------------------
  Future<List<PlanModel>> _fetchPlansFromIds(List<String> planIds) async {
    if (planIds.isEmpty) return [];

    final List<PlanModel> plans = [];
    for (String planId in planIds) {
      final planDoc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(planId)
          .get();
      if (planDoc.exists) {
        final planData = planDoc.data() as Map<String, dynamic>;
        // Aseguramos que planData tenga el id
        planData['id'] = planDoc.id;
        plans.add(PlanModel.fromMap(planData));
      }
    }
    return plans;
  }

  // ------------------------------------------------------------------------
  // Construir la tarjeta de cada plan (con fondo, avatar, etc.)
  // Al pulsar, mostramos FrostedPlanDialog a pantalla completa
  // ------------------------------------------------------------------------
  Widget _buildPlanCard(
    BuildContext context,
    Map<String, dynamic> userData,
    PlanModel plan,
  ) {
    final String name = userData['name']?.toString().trim() ?? 'Usuario';
    final String userHandle = userData['handle']?.toString() ?? '@usuario';
    final String? fallbackPhotoUrl = userData['photoUrl']?.toString();
    final String? backgroundImage = plan.backgroundImage;
    final String caption = plan.description.isNotEmpty
        ? plan.description
        : 'Descripción breve o #hashtags';

    // Simplemente un contador "ficticio" de shares, fijo
    const String sharesCount = '227';

    return GestureDetector(
      onTap: () {
        // Abre los detalles del plan a pantalla completa (FrostedPlanDialog)
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

              // Avatar + nombre en la esquina superior izquierda
              Positioned(
                top: 10,
                left: 10,
                child: GestureDetector(
                  onTap: () {
                    // Ir al perfil del creador
                    final String? uid =
                        userData['uid']?.toString() ?? plan.createdBy;
                    if (uid != null && uid.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => profile_readonly.UserInfoCheck(
                            userId: uid,
                          ),
                        ),
                      );
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: const Color.fromARGB(255, 14, 14, 14)
                            .withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildProfileAvatar(fallbackPhotoUrl),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    SvgPicture.asset(
                                      'assets/verificado.svg',
                                      width: 14,
                                      height: 14,
                                      color: Colors.blueAccent,
                                    ),
                                  ],
                                ),
                                Text(
                                  userHandle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Menú con 3 iconos en la esquina superior derecha
              Positioned(
                top: 16,
                right: 16,
                child: _buildThreeDotsMenu(context, plan),
              ),

              // Parte inferior: contadores + descripción
              // (lee commentsCount y likes en tiempo real)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('plans')
                      .doc(plan.id)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData || !snap.data!.exists) {
                      // Plan no existe o no cargó => valores por defecto
                      return _buildBottomStats(
                        likesValue: plan.likes,
                        commentsValue: 0,
                        sharesValue: sharesCount,
                        caption: caption,
                      );
                    }
                    final data = snap.data!.data() as Map<String, dynamic>;
                    final comments = data['commentsCount'] ?? 0;
                    final likes = data['likes'] ?? plan.likes;

                    return _buildBottomStats(
                      likesValue: likes,
                      commentsValue: comments,
                      sharesValue: sharesCount,
                      caption: caption,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // Muestra la parte inferior con likes, comments, shares y la descripción
  // ------------------------------------------------------------------------
  Widget _buildBottomStats({
    required int likesValue,
    required int commentsValue,
    required String sharesValue,
    required String caption,
  }) {
    return ClipRRect(
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
                    label: likesValue.toString(),
                  ),
                  const SizedBox(width: 25),
                  _buildIconText(
                    icon: Icons.chat_bubble_outline,
                    label: commentsValue.toString(),
                  ),
                  const SizedBox(width: 25),
                  _buildIconText(
                    icon: Icons.share,
                    label: sharesValue,
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                caption,
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // Menú de iconos (compartir, like, etc.)
  // ------------------------------------------------------------------------
  Widget _buildThreeDotsMenu(BuildContext context, PlanModel plan) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Icono de compartir
        _buildFrostedIcon(
          'assets/compartir.svg',
          size: 40,
          onTap: () {
            _openCustomShareModal(context, plan);
          },
        ),
        const SizedBox(width: 16),
        // Botón de Like
        LikeButton(plan: plan),
        const SizedBox(width: 16),
        // Icono "unirse" (si lo deseas)
        _buildFrostedIcon(
          'assets/union.svg',
          size: 40,
          onTap: () {
            // Lógica tuya si quieres unirse a plan
          },
        ),
      ],
    );
  }

  // ------------------------------------------------------------------------
  // Lógica EXACTA para abrir el bottom sheet draggable y compartir
  // ------------------------------------------------------------------------
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
                  // Pequeño "handle" para indicar que se puede arrastrar
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

                  // Sección para compartir dentro de la app
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

  // ------------------------------------------------------------------------
  // Icono "Frosted" genérico
  // ------------------------------------------------------------------------
  Widget _buildFrostedIcon(
    String assetPath, {
    double size = 40,
    Color iconColor = Colors.white,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 175, 173, 173).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                assetPath,
                width: size * 0.5,
                height: size * 0.5,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------------
  // Avatar de perfil
  // ------------------------------------------------------------------------
  Widget _buildProfileAvatar(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(photoUrl),
      );
    } else {
      return const CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, color: Colors.white),
      );
    }
  }

  // ------------------------------------------------------------------------
  // Placeholder para cuando no hay imagen
  // ------------------------------------------------------------------------
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

  // ------------------------------------------------------------------------
  // Icono + texto
  // ------------------------------------------------------------------------
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
/// Clase que muestra la lógica interna para compartir dentro de tu app
/// (Seguidores, etc.). La misma que usas en tus otros archivos.
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

  /// Carga "followers" y "followed" desde Firestore
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

  /// Dado un listado de UIDs, retorna la info de cada user (nombre, foto, etc.)
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
      Navigator.pop(context); // Cerrar si no hay nada que enviar
      return;
    }

    final String shareUrl =
        'https://plan-social-app.web.app/plan?planId=${widget.plan.id}';
    final String planId = widget.plan.id;
    final String planTitle = widget.plan.type;
    final String planDesc = widget.plan.description;
    final String? planImage = widget.plan.backgroundImage;

    // Ejemplo: enviamos un doc a "messages" con la info del plan
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

    Navigator.pop(context); // Cerrar bottom sheet
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

        // Cuadro de búsqueda
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
              setState(() {}); // refresca el filtrado
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

  // Filtra los usuarios según el texto del buscador
  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> users) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return users;
    return users.where((u) {
      final name = u['name'].toString().toLowerCase();
      return name.contains(query);
    }).toList();
  }

  /// Muestra la lista de usuarios con “checkbox” para seleccionar
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

// ------------------------------------------------------------------------
// Botón de Like que actualiza el contador de likes y el array favourites
// ------------------------------------------------------------------------
class LikeButton extends StatefulWidget {
  final PlanModel plan;
  const LikeButton({Key? key, required this.plan}) : super(key: key);

  @override
  _LikeButtonState createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool liked = false;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await userRef.get();
    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data() as Map<String, dynamic>;
      final favourites = data['favourites'] as List<dynamic>? ?? [];
      if (favourites.contains(widget.plan.id)) {
        setState(() {
          liked = true;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final planRef =
        FirebaseFirestore.instance.collection('plans').doc(widget.plan.id);
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    // Actualizamos contador 'likes' en la colección 'plans'.
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(planRef);
      if (!snapshot.exists) return;
      int currentLikes = snapshot.data()!['likes'] ?? 0;
      if (!liked) {
        currentLikes++;
      } else {
        currentLikes = currentLikes > 0 ? currentLikes - 1 : 0;
      }
      transaction.update(planRef, {'likes': currentLikes});
    });

    // Actualizamos el array 'favourites' en 'users'.
    if (!liked) {
      await userRef.update({
        'favourites': FieldValue.arrayUnion([widget.plan.id])
      });
    } else {
      await userRef.update({
        'favourites': FieldValue.arrayRemove([widget.plan.id])
      });
    }

    setState(() {
      liked = !liked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleLike,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 175, 173, 173).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/corazon.svg',
                width: 20,
                height: 20,
                color: liked ? Colors.red : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
