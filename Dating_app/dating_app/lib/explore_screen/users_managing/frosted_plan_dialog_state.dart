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
  final Future<List<Map<String, dynamic>>> Function(PlanModel plan)
      fetchParticipants;

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

  // Añadimos variable local para la edad del creador
  String? _creatorAge;

  bool _liked = false;
  int _likeCount = 0;

  // Controladores y estados para el carrusel de imágenes + video
  late PageController _pageController;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _futureParticipants = widget.fetchParticipants(widget.plan);
    _likeCount = widget.plan.likes; // Carga inicial de 'likes'
    _checkIfLiked();

    // Intentamos cargar la info del creador (nombre, foto, EDAD) por si no vino en el plan
    _fetchCreatorInfo();

    // Inicializamos el PageController para el carrusel
    _pageController = PageController();
  }

  /// Consulta en la colección 'users' la info del creador y la guarda localmente
  Future<void> _fetchCreatorInfo() async {
    // Si no hay creador, salimos
    if (widget.plan.createdBy.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.plan.createdBy)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        
        // Si en Firestore guardas la edad en 'age'
        final String ageCreador = data['age']?.toString() ?? '';

        setState(() {
          widget.plan.creatorName = data['name'] ?? 'Creador';
          widget.plan.creatorProfilePic = data['photoUrl'] ?? '';
          // Guardamos la edad localmente, no en el PlanModel
          _creatorAge = ageCreador;
        });
      }
    } catch (e) {
      debugPrint('Error al obtener info del creador: $e');
    }
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
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
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
  // Ubicación
  // ---------------------------------------------------------------------------
  Widget _buildLocationArea(PlanModel plan) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Encabezado "Ubicación"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/icono-ubicacion.svg',
                        width: 18,
                        height: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Ubicación",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Dirección / descripción de la ubicación
                  Text(
                    plan.location,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mapa
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
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueBlue,
                              ),
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
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Información adicional (ID + Restricción + Fechas)
  // ---------------------------------------------------------------------------
  Widget _buildAdditionalInfoBox(PlanModel plan) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título de la sección
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/icono-id-plan.svg',
                        width: 18,
                        height: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          "Información adicional",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Fila para "ID del Plan" + Botón copiar
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "ID del Plan: ${plan.id}",
                          style: const TextStyle(
                            color: Color.fromARGB(255, 212, 211, 211),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.copy,
                          color: Color.fromARGB(255, 203, 202, 206),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: plan.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ID copiado al portapapeles'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Restricción de edad (si no es plan especial)
                  if (plan.special_plan != 1)
                    Text(
                      "Restricción de edad: ${plan.minAge} - ${plan.maxAge} años",
                      style: const TextStyle(
                        color: Color.fromARGB(255, 212, 211, 211),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.start,
                    ),

                  const SizedBox(height: 25),
                  // FECHA DE INICIO
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SvgPicture.asset(
                        'assets/icono-calendario.svg',
                        width: 16,
                        height: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Fecha de inicio: ${plan.formattedDate(plan.startTimestamp)}",
                          style: const TextStyle(
                            color: Color.fromARGB(255, 219, 218, 218),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // FECHA DE FINALIZACIÓN (si existe)
                  if (plan.finishTimestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(width: 21),
                          Expanded(
                            child: Text(
                              "Finaliza: ${plan.formattedDate(plan.finishTimestamp)}",
                              style: const TextStyle(
                                color: Color.fromARGB(255, 219, 218, 218),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONTENEDOR DE ACCIÓN (icono y número)
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
              color: Colors.black.withOpacity(0.2),
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
  // Botón de Like
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
  // Botón de mensaje -> abre popup de chat
  // ---------------------------------------------------------------------------
  Widget _buildMessageButton(PlanModel plan) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('plans').doc(plan.id).snapshots(),
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
                  backgroundColor: const ui.Color.fromARGB(255, 35, 57, 80),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
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
      countText: "",
      onTap: () {
        _openCustomShareModal(plan);
      },
    );
  }

  /// Abre un bottom sheet DRAGGABLE que incluye:
  /// - Barra para arrastrar/cerrar.
  /// - Botón "Compartir con otras apps".
  /// - Listado de seguidores/seguidos (para compartir dentro de la app).
  void _openCustomShareModal(PlanModel plan) {
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

                  // Botón para "Compartir con otras apps"
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            // Comparte el plan en otras apps
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

  // ---------------------------------------------------------------------------
  // Fila de acciones: Like, Mensaje y Compartir
  // ---------------------------------------------------------------------------
  Widget _buildActionButtonsRow(PlanModel plan) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLikeButton(),
        const SizedBox(width: 16),
        _buildMessageButton(plan),
        const SizedBox(width: 16),
        _buildShareButton(plan),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Botón "Únete ahora"
  // ---------------------------------------------------------------------------
  Widget _buildJoinButton(PlanModel plan) {
    return GestureDetector(
      onTap: () {
        // TODO: lógica de unirse al plan (guardar en Firestore, etc.)
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/union.svg',
                width: 20,
                height: 20,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              const Text(
                "Únete ahora",
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Popup de Chat (al pulsar botón mensaje)
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
              const Expanded(
                child: Text(
                  "Chat del Plan",
                  style: TextStyle(
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
                      backgroundImage:
                          senderPic.isNotEmpty ? NetworkImage(senderPic) : null,
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

        // Barra inferior para escribir nuevo mensaje
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
                    await FirebaseFirestore.instance
                        .collection('plan_chat')
                        .add({
                      'planId': plan.id,
                      'senderId': _currentUser!.uid,
                      'senderName': senderName,
                      'senderPic': senderPic,
                      'text': text,
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    final planRef = FirebaseFirestore.instance
                        .collection('plans')
                        .doc(plan.id);
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
  // AVATARES DE PARTICIPANTES
  // ---------------------------------------------------------------------------
  Widget _buildParticipantsCorner(List<Map<String, dynamic>> participants) {
    final count = participants.length;
    if (count == 0) {
      // Si no hay participantes, no mostramos nada
      return const SizedBox.shrink();
    }

    if (count == 1) {
      // Un participante
      final p = participants[0];
      final pic = p['photoUrl'] ?? '';
      final name = p['name'] ?? 'Usuario';
      final age = p['age']?.toString() ?? '';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
              backgroundColor: Colors.blueGrey[400],
            ),
            const SizedBox(width: 8),
            Text(
              '$name, $age',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    } else {
      // 2 o más participantes
      final p1 = participants[0];
      final p2 = participants[1];

      final pic1 = p1['photoUrl'] ?? '';
      final pic2 = p2['photoUrl'] ?? '';

      const double avatarSize = 40;
      const double overlapOffset = 30;
      final int extras = count - 2;
      final bool hasExtras = extras > 0;

      return GestureDetector(
        onTap: () {
          _showParticipantsModal(participants);
        },
        child: SizedBox(
          width: hasExtras ? 90 : 70,
          height: avatarSize,
          child: Stack(
            children: [
              // Primer avatar
              Positioned(
                left: 0,
                child: CircleAvatar(
                  radius: avatarSize / 2,
                  backgroundImage: pic1.isNotEmpty ? NetworkImage(pic1) : null,
                  backgroundColor: Colors.blueGrey[400],
                ),
              ),
              // Segundo avatar
              Positioned(
                left: overlapOffset,
                child: CircleAvatar(
                  radius: avatarSize / 2,
                  backgroundImage: pic2.isNotEmpty ? NetworkImage(pic2) : null,
                  backgroundColor: Colors.blueGrey[400],
                ),
              ),
              // +X si hay más
              if (hasExtras)
                Positioned(
                  left: overlapOffset * 2,
                  child: CircleAvatar(
                    radius: avatarSize / 2,
                    backgroundColor: Colors.deepPurple,
                    child: Text(
                      '+$extras',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // MODAL PARTICIPANTES
  // ---------------------------------------------------------------------------
  void _showParticipantsModal(List<Map<String, dynamic>> participants) {
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
          backgroundColor: const ui.Color.fromARGB(255, 35, 57, 80),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Título
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Participantes",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white38),
              // Lista de participantes
              Expanded(
                child: ListView.builder(
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final participant = participants[index];
                    return _buildParticipantTile(participant);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // AVATAR + NOMBRE + EDAD de un participante (en el modal)
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
  // CARRUSEL DE IMÁGENES + VIDEO
  // ---------------------------------------------------------------------------
  Widget _buildMediaCarousel({
    required List<String> images,
    required String? videoUrl,
  }) {
    final totalMedia =
        images.length + ((videoUrl?.isNotEmpty ?? false) ? 1 : 0);

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.95,
      height: 300,
      child: PageView.builder(
        controller: _pageController,
        itemCount: totalMedia,
        onPageChanged: (index) {
          setState(() {
            _currentPageIndex = index;
          });
        },
        itemBuilder: (context, index) {
          if (index < images.length) {
            final imageUrl = images[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          } else {
            // Vista previa del video (thumbnail simple)
            return ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECCIÓN MULTIMEDIA + BOTONES & AVATARES
  // (Aquí decidimos si aparece el botón “Únete ahora”)
  // ---------------------------------------------------------------------------
  Widget _buildMediaSection(
    PlanModel plan,
    List<Map<String, dynamic>> participants, {
    required bool isUserCreator,
  }) {
    final images = plan.images ?? [];
    final video = plan.videoUrl ?? '';
    final totalMedia = images.length + (video.isNotEmpty ? 1 : 0);

    Widget mediaContent;
    if (totalMedia == 0) {
      mediaContent = Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.black54,
        ),
        child: const Center(
          child: Text(
            'Sin contenido multimedia',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } else {
      mediaContent = _buildMediaCarousel(images: images, videoUrl: video);
    }

    // Indicadores de página (si hay más de 1)
    Widget pageIndicator = const SizedBox.shrink();
    if (totalMedia > 1) {
      pageIndicator = Padding(
        padding: const EdgeInsets.only(top: 5, bottom: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalMedia, (i) {
            final isActive = (i == _currentPageIndex);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.grey,
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      );
    }

    return Column(
      children: [
        mediaContent,
        pageIndicator,

        // Fila con los 3 botones + avatares de participantes
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              // Botones de acción a la izquierda
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildActionButtonsRow(plan),
                ),
              ),
              // Avatares de participantes a la derecha
              _buildParticipantsCorner(participants),
            ],
          ),
        ),

        // Botón "Únete ahora", SOLO si NO es el creador
        if (!isUserCreator)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: _buildJoinButton(plan),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ENCABEZADO SUPERIOR: avatar creador + nombre y EDAD + botón back
  // ---------------------------------------------------------------------------
  Widget _buildHeaderRow() {
    final String name = widget.plan.creatorName ?? 'Creador';
    // Usamos la variable local _creatorAge en vez de plan.creatorAge
    final String age = _creatorAge ?? '';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Avatar del creador
          CircleAvatar(
            radius: 20,
            backgroundImage: (widget.plan.creatorProfilePic?.isNotEmpty ?? false)
                ? NetworkImage(widget.plan.creatorProfilePic!)
                : null,
            backgroundColor: Colors.blueGrey[400],
          ),
          const SizedBox(width: 8),

          // Nombre + Edad (igual que participantes)
          Expanded(
            child: Text(
              age.isNotEmpty ? '$name, $age' : name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Botón "Atrás"
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONSTRUCCIÓN PRINCIPAL DEL DIALOG
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;

    // Determinamos si el usuario actual es el creador
    final bool isUserCreator =
        (_currentUser != null && _currentUser!.uid == plan.createdBy);

    return Scaffold(
      backgroundColor: const ui.Color.fromARGB(255, 35, 57, 80),
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

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Header (avatar creador + nombre + edad + back)
                  _buildHeaderRow(),

                  // Sección MULTIMEDIA (si no es plan especial)
                  if (plan.special_plan != 1)
                    _buildMediaSection(plan, allParts,
                        isUserCreator: isUserCreator)
                  else
                    const SizedBox(height: 10),

                  // Contenedor frosted con tipo y descripción
                  Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.95,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Título del plan (centrado)
                                Center(
                                  child: Text(
                                    plan.type,
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Descripción
                                Text(
                                  plan.description,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                    height: 1.3,
                                  ),
                                  textAlign: TextAlign.start,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Ubicación
                  _buildLocationArea(plan),
                  const SizedBox(height: 16),

                  // Información adicional (ID + Restricción + Fechas)
                  _buildAdditionalInfoBox(plan),
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

// ---------------------------------------------------------------------------
// Lógica de 'Like' (extensión)
// ---------------------------------------------------------------------------
extension LikeLogic on _FrostedPlanDialogState {
  Future<void> _checkIfLiked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
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
    final planRef =
        FirebaseFirestore.instance.collection('plans').doc(widget.plan.id);
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

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

    // Actualizamos la lista de favoritos del usuario
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

// ---------------------------------------------------------------------------
// Contenido del modal para compartir DENTRO de la app
// ---------------------------------------------------------------------------
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

  /// Carga tus "followers" y "followed" desde colecciones separadas.
  Future<void> _fetchFollowersAndFollowing() async {
    if (_currentUser == null) return;

    try {
      // 1) Traemos followers => docs donde userId = mi UID
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

      // 2) Traemos followed => docs donde userId = mi UID
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

      // 3) Cargar la info de cada uno (nombre, foto, etc.)
      _followers = await _fetchUsersData(followerUids);
      _following = await _fetchUsersData(followedUids);

      setState(() {});
    } catch (e) {
      print("Error al cargar followers/following: $e");
    }
  }

  /// Dado un listado de uids, retornamos la info de cada usuario
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

  /// Enviar el plan a los usuarios seleccionados (por chat)
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

    for (String uidDestino in _selectedUsers) {
      // Creamos un "mensaje" de tipo especial: "shared_plan"
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

    Navigator.pop(context); // Cerrar el bottom sheet
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra superior con Cancelar y Enviar
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
              setState(() {}); // Para refrescar filtrado
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
                      fontWeight: FontWeight.bold),
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
                      fontWeight: FontWeight.bold),
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

  // Filtra por lo que se escribe en el buscador
  List<Map<String, dynamic>> _filterUsers(List<Map<String, dynamic>> users) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return users;
    return users.where((u) {
      final name = u['name'].toString().toLowerCase();
      return name.contains(query);
    }).toList();
  }

  /// Devuelve una lista de usuarios con un "check" para seleccionar
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
