import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/plan_model.dart';

class FrostedPlanDialog extends StatefulWidget {
  final PlanModel plan;
  final Future<List<Map<String, dynamic>>> Function(PlanModel plan) fetchParticipants;

  const FrostedPlanDialog({
    Key? key,
    required this.plan,
    required this.fetchParticipants,
  }) : super(key: key);

  @override
  State<FrostedPlanDialog> createState() => _FrostedPlanDialogState();
}

class _FrostedPlanDialogState extends State<FrostedPlanDialog> {
  late Future<List<Map<String, dynamic>>> _futureParticipants;
  final TextEditingController _chatController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  bool _liked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _futureParticipants = widget.fetchParticipants(widget.plan);
    _likeCount = widget.plan.likes; // Inicializa el contador con el valor del plan
    _checkIfLiked();
  }

  /// Convierte un Timestamp a String "HH:mm"
  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // ---------------------------------------------------------------------------
  // FROSTED BOX (genérico)
  // ---------------------------------------------------------------------------
  Widget _buildFrostedDetailBox({
    required String iconPath,
    required String title,
    required Widget child,
  }) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      iconPath,
                      width: 18,
                      height: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BLOQUES DE DETALLE (ID, Restricción, etc.)
  // ---------------------------------------------------------------------------
  Widget _buildPlanIDArea(PlanModel plan) {
    return _buildFrostedDetailBox(
      iconPath: 'assets/icono-id-plan.svg',
      title: "ID del Plan",
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            plan.id,
            style: const TextStyle(
              color: Color.fromARGB(255, 151, 121, 215),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Color.fromARGB(255, 151, 121, 215)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: plan.id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ID copiado al portapapeles')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAgeRestrictionArea(PlanModel plan) {
    return _buildFrostedDetailBox(
      iconPath: 'assets/icono-restriccion-edad.svg',
      title: "Restricción de Edad",
      child: Text(
        "${plan.minAge} - ${plan.maxAge} años",
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color.fromARGB(255, 151, 121, 215),
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildEventDateArea(PlanModel plan) {
    return _buildFrostedDetailBox(
      iconPath: 'assets/icono-calendario.svg',
      title: "Fecha del Evento",
      child: Text(
        plan.formattedDate(plan.startTimestamp),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color.fromARGB(255, 151, 121, 215),
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildLocationArea(PlanModel plan) {
    return _buildFrostedDetailBox(
      iconPath: 'assets/icono-ubicacion.svg',
      title: "Ubicación",
      child: Column(
        children: [
          Text(
            plan.location,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color.fromARGB(255, 151, 121, 215),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (plan.latitude != null && plan.longitude != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 240,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(plan.latitude!, plan.longitude!),
                    zoom: 16,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('plan_location'),
                      position: LatLng(plan.latitude!, plan.longitude!),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                    ),
                  },
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  liteModeEnabled: true,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                "Ubicación no disponible",
                style: TextStyle(
                  color: Color.fromARGB(255, 151, 121, 215),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONTENEDOR DE ACCIÓN (icono y número) con fondo sombreado
  // Se agregó el parámetro iconColor para modificar el color (rojo al dar like)
  // ---------------------------------------------------------------------------
  Widget _buildActionButton({
    required String iconPath,
    required String countText,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 175, 173, 173).withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  iconPath,
                  width: 20,
                  height: 20,
                  color: iconColor,
                ),
                const SizedBox(width: 4),
                Text(
                  countText,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Botón de like (pinta de rojo cuando está activo)
  // ---------------------------------------------------------------------------
  Widget _buildLikeButton() {
    return _buildActionButton(
      iconPath: 'assets/corazon.svg',
      countText: _likeCount.toString(),
      onTap: _toggleLike,
      iconColor: _liked ? Colors.red : Colors.white,
    );
  }

  // ---------------------------------------------------------------------------
  // Botón de mensaje que abre el chat en popup (ya no se muestra en pantalla principal)
  // ---------------------------------------------------------------------------
  Widget _buildMessageButton(PlanModel plan) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('plans').doc(plan.id).snapshots(),
      builder: (context, snap) {
        String countText = '0';
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>;
          final count = data['commentsCount'] ?? 0;
          countText = count.toString();
        }
        return _buildActionButton(
          iconPath: 'assets/mensaje.svg',
          countText: countText,
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                return Dialog(
                  insetPadding: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.25,
                    left: 0,
                    right: 0,
                    bottom: 0,
                  ),
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: _buildChatPopup(plan),
                );
              },
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Botón de compartir
  // ---------------------------------------------------------------------------
  Widget _buildShareButton(PlanModel plan) {
    return _buildActionButton(
      iconPath: 'assets/icono-compartir.svg',
      countText: "227",
      onTap: () {
        final String shareUrl = 'https://plan-social-app.web.app/plan?planId=${plan.id}';
        final String shareText =
            '¡Mira este plan!\nTítulo: ${plan.type}\nDescripción: ${plan.description}\n¡Únete y participa!\n\n$shareUrl';
        Share.share(shareText);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // FILA DE ACCIONES: like, mensaje y compartir
  // ---------------------------------------------------------------------------
  Widget _buildActionButtonsRow(PlanModel plan) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildLikeButton(),
          const SizedBox(width: 16),
          _buildMessageButton(plan),
          const SizedBox(width: 16),
          _buildShareButton(plan),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NUEVA FUNCIÓN: Chat popup (sin fondo transparente, con header y campo de texto en la parte inferior)
  // ---------------------------------------------------------------------------
  Widget _buildChatPopup(PlanModel plan) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // Header con título y botón de cierre
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "Chat del Plan",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white38),
        // Área de mensajes
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('plan_chat')
                .where('planId', isEqualTo: plan.id)
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Error al cargar mensajes',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No hay mensajes todavía',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }
              return ListView(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final text = data['text'] ?? '';
                  final senderName = data['senderName'] ?? 'Invitado';
                  final senderPic = data['senderPic'] ?? '';
                  final ts = data['timestamp'] as Timestamp?;
                  final timeStr = _formatTimestamp(ts);
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundImage: senderPic.isNotEmpty ? NetworkImage(senderPic) : null,
                      backgroundColor: Colors.blueGrey[100],
                    ),
                    title: Text(
                      senderName,
                      style: const TextStyle(
                        color: Color.fromARGB(255, 151, 121, 215),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '$text\n$timeStr',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        // Campo de introducción de texto (barra de chat en la parte inferior)
        Container(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: "Escribe un mensaje...",
                    filled: true,
                    fillColor: Colors.white24,
                    hintStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () async {
                  final text = _chatController.text.trim();
                  if (text.isNotEmpty && _currentUser != null) {
                    String senderName = _currentUser!.uid;
                    String senderPic = '';
                    try {
                      final userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(_currentUser!.uid)
                          .get();
                      if (userDoc.exists && userDoc.data() != null) {
                        final userData = userDoc.data()!;
                        senderPic = userData['photoUrl'] ?? '';
                        senderName = userData['name'] ?? senderName;
                      }
                    } catch (_) {}
                    await FirebaseFirestore.instance.collection('plan_chat').add({
                      'planId': plan.id,
                      'senderId': _currentUser!.uid,
                      'senderName': senderName,
                      'senderPic': senderPic,
                      'text': text,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    final planRef = FirebaseFirestore.instance.collection('plans').doc(plan.id);
                    await planRef.update({
                      'commentsCount': FieldValue.increment(1),
                    }).catchError((_) {
                      planRef.set({'commentsCount': 1}, SetOptions(merge: true));
                    });
                    _chatController.clear();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PARTICIPANTES (CREADOR Y RESTO)
  // ---------------------------------------------------------------------------
  Widget _buildParticipantTile(Map<String, dynamic> participant) {
    final pic = participant['photoUrl'] ?? '';
    final name = participant['name'] ?? 'Usuario';
    final age = participant['age'] ?? '';
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
        backgroundColor: Colors.blueGrey[100],
      ),
      title: Text(
        '$name, $age',
        style: const TextStyle(
          color: Color.fromARGB(255, 151, 121, 215),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ENCABEZADO SUPERIOR: Avatar e información del creador a la izquierda, flecha back a la derecha
  // ---------------------------------------------------------------------------
  Widget _buildHeaderRow(Map<String, dynamic>? creator) {
    final pic = creator?['photoUrl'] ?? '';
    final name = creator?['name'] ?? 'Usuario';
    final age = creator?['age']?.toString() ?? '';
    final fullName = age.isNotEmpty ? '$name, $age' : name;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
            backgroundColor: Colors.blueGrey[400],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fullName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection(List<Map<String, dynamic>> all) {
    if (all.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text(
          'No hay participantes en este plan.',
          style: TextStyle(
            color: Color.fromARGB(255, 151, 121, 215),
          ),
        ),
      );
    }
    final participants = all.where((p) => p['isCreator'] != true).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Participantes",
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          if (participants.isEmpty)
            const Text(
              "No hay participantes en este plan.",
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            ...participants.map((p) => _buildParticipantTile(p as Map<String, dynamic>)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONSTRUCCIÓN PRINCIPAL DE LA PANTALLA (Todo se desplaza)
  // Se eliminó el contenedor de chat (se accede vía popup) y también "Máx. Participantes" y "Creado el"
  // Además, se muestra el tipo y la descripción en un contenedor único debajo de los botones de acción
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Scaffold(
      backgroundColor: const Color(0xFF0D253F),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futureParticipants,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            final allParts = snapshot.data ?? [];
            final creator = allParts.firstWhere(
              (p) => p['isCreator'] == true,
              orElse: () => <String, dynamic>{},
            );
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // 1) Header (avatar e info + botón back)
                  _buildHeaderRow(
                    creator.isNotEmpty ? creator as Map<String, dynamic> : null,
                  ),
                  // 2) Imagen de fondo del plan
                  if (plan.special_plan != 1 &&
                      plan.backgroundImage != null &&
                      plan.backgroundImage!.isNotEmpty)
                    Container(
                      width: MediaQuery.of(context).size.width * 0.95,
                      height: 300,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        image: DecorationImage(
                          image: NetworkImage(plan.backgroundImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  // 3) Fila de botones de acción (like, mensaje y compartir)
                  _buildActionButtonsRow(plan),
                  // 4) Tipo y descripción (concatenados en un solo contenedor, alineados a la izquierda)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "${plan.type}: ${plan.description}",
                      style: const TextStyle(
                        color: Color.fromARGB(255, 151, 121, 215),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  // 5) Participantes
                  _buildParticipantsSection(allParts),
                  const SizedBox(height: 10),
                  // 6) ID del plan
                  _buildPlanIDArea(plan),
                  const SizedBox(height: 10),
                  // 7) Restricción de edad (se elimina "Máx. Participantes")
                  if (plan.special_plan != 1) ...[
                    _buildAgeRestrictionArea(plan),
                    const SizedBox(height: 10),
                  ],
                  // 8) Fecha del evento (se elimina "Creado el")
                  _buildEventDateArea(plan),
                  const SizedBox(height: 10),
                  _buildLocationArea(plan),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Lógica de like integrada en este widget
extension LikeLogic on _FrostedPlanDialogState {
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
          _liked = true;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final planRef = FirebaseFirestore.instance.collection('plans').doc(widget.plan.id);
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(planRef);
      if (!snapshot.exists) return;
      int currentLikes = snapshot.data()!['likes'] ?? 0;
      if (!_liked) {
        currentLikes++;
      } else {
        currentLikes = currentLikes > 0 ? currentLikes - 1 : 0;
      }
      transaction.update(planRef, {'likes': currentLikes});
      setState(() {
        _likeCount = currentLikes;
      });
    });
    if (!_liked) {
      await userRef.update({
        'favourites': FieldValue.arrayUnion([widget.plan.id])
      });
    } else {
      await userRef.update({
        'favourites': FieldValue.arrayRemove([widget.plan.id])
      });
    }
    setState(() {
      _liked = !_liked;
    });
  }
}
