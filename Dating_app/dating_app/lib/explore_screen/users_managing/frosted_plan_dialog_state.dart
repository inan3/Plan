import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  // Controlador de texto para el campo de chat
  final TextEditingController _chatController = TextEditingController();

  // Usuario actual (asumiendo que ya estás logeado)
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _futureParticipants = widget.fetchParticipants(widget.plan);
  }

  /// FORMATEA LA HORA (HH:mm)
  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// CONTENEDOR FROSTED
  Widget _buildFrostedDetailBox({
    required String iconPath,
    required String title,
    required Widget content,
    double width = 360,
  }) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: width,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título centrado
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
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
                          softWrap: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// DETALLES PRINCIPALES DEL PLAN
  Widget _buildPlanDetailsArea(PlanModel plan, {double width = 240}) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: width,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 8),
                if (plan.iconAsset != null && plan.iconAsset!.isNotEmpty) ...[
                  SvgPicture.asset(
                    plan.iconAsset!,
                    width: 34,
                    height: 34,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: "Este plan va de \n${plan.type}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// OTROS DETALLES (ID, DESCRIPTION, RESTRICCIONES, ETC.)
  Widget _buildPlanDescriptionArea(PlanModel plan, {double width = 360}) {
    return _buildFrostedDetailBox(
      iconPath: 'assets/icono-descripcion-plan.svg',
      title: "Descripción",
      width: width,
      content: Text(
        plan.description,
        style: const TextStyle(
          color: Color.fromARGB(255, 151, 121, 215),
          fontSize: 16,
        ),
        textAlign: TextAlign.left,
        softWrap: true,
      ),
    );
  }

  Widget _buildPlanIDArea(PlanModel plan, {double width = 360}) {
    return _buildFrostedDetailBox(
      iconPath: 'assets/icono-id-plan.svg',
      title: "ID del Plan",
      width: width,
      content: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              plan.id,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color.fromARGB(255, 151, 121, 215),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy,
                  color: Color.fromARGB(255, 151, 121, 215)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: plan.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ID copiado al portapapeles')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeRestrictionArea(PlanModel plan, {double width = 360}) {
    return _buildFrostedDetailBox(
      iconPath: 'assets/icono-restriccion-edad.svg',
      title: "Restricción de Edad",
      width: width,
      content: Center(
        child: Text(
          "${plan.minAge} - ${plan.maxAge} años",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color.fromARGB(255, 151, 121, 215),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildMaxParticipantsArea(PlanModel plan, {double width = 360}) {
    final maxP = plan.maxParticipants?.toString() ?? 'Sin límite';
    return _buildFrostedDetailBox(
      iconPath: 'assets/icono-max-participantes.svg',
      title: "Máx. Participantes",
      width: width,
      content: Center(
        child: Text(
          maxP,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color.fromARGB(255, 151, 121, 215),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildEventDateArea(PlanModel plan, {double width = 360}) {
    return _buildFrostedDetailBox(
      iconPath: 'assets/icono-calendario.svg',
      title: "Fecha del Evento",
      width: width,
      content: Center(
        child: Text(
          plan.formattedDate(plan.startTimestamp),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color.fromARGB(255, 151, 121, 215),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildCreatedAtArea(PlanModel plan, {double width = 360}) {
    return _buildFrostedDetailBox(
      iconPath: 'assets/icono-fecha-creacion.svg',
      title: "Creado el",
      width: width,
      content: Center(
        child: Text(
          plan.formattedDate(plan.createdAt),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color.fromARGB(255, 151, 121, 215),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildLocationArea(PlanModel plan, {double width = 360}) {
    return _buildFrostedDetailBox(
      iconPath: 'assets/icono-ubicacion.svg',
      title: "Ubicación",
      width: width,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                width: double.infinity,
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
                      anchor: const Offset(0.5, 0.5),
                    )
                  },
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  liteModeEnabled: true,
                ),
              ),
            )
          else
            const Center(
              child: Text(
                "Ubicación no disponible",
                style: TextStyle(
                  color: Color.fromARGB(255, 151, 121, 215),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECCIÓN DE CHAT USANDO FIRESTORE (colección "plan_chat")
  // con avatar y hora, + INCREMENTA commentsCount
  // ---------------------------------------------------------------------------
  Widget _buildChatSection(PlanModel plan) {
    return _buildFrostedDetailBox(
      // Aquí cambiamos el icono a 'assets/mensaje.svg'
      iconPath: 'assets/mensaje.svg',
      title: "Chat del Plan",
      content: Column(
        children: [
          // 1. StreamBuilder para leer mensajes
          SizedBox(
            height: 300,
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
                        backgroundImage: senderPic.isNotEmpty
                            ? NetworkImage(senderPic)
                            : null,
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
          const SizedBox(height: 10),

          // 2. Campo de texto + botón enviar
          Row(
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
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () async {
                  final text = _chatController.text.trim();
                  if (text.isNotEmpty) {
                    final user = _currentUser;
                    if (user == null) return;

                    // Obtenemos info del usuario actual: name + photoUrl
                    String senderName = user.uid; // fallback
                    String senderPic = '';
                    try {
                      final userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .get();
                      if (userDoc.exists) {
                        final userData = userDoc.data();
                        if (userData != null) {
                          if (userData['photoUrl'] != null) {
                            senderPic = userData['photoUrl'];
                          }
                          if (userData['name'] != null) {
                            senderName = userData['name'];
                          }
                        }
                      }
                    } catch (e) {
                      // ignora error
                    }

                    // 1) Guardamos el mensaje en plan_chat
                    await FirebaseFirestore.instance.collection('plan_chat').add({
                      'planId': plan.id,
                      'senderId': user.uid,
                      'senderName': senderName,
                      'senderPic': senderPic,
                      'text': text,
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    // 2) Incrementamos commentsCount en la colección 'plans'
                    final planRef = FirebaseFirestore.instance
                        .collection('plans')
                        .doc(plan.id);
                    await planRef.update({
                      'commentsCount': FieldValue.increment(1),
                    }).catchError((e) {
                      // Si no existe commentsCount, lo inicializa en 1
                      planRef.set({
                        'commentsCount': 1,
                      }, SetOptions(merge: true));
                    });

                    _chatController.clear();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TILE PARA MOSTRAR EL CREADOR
  // ---------------------------------------------------------------------------
  Widget _buildCreatorTile(Map<String, dynamic> creator) {
    final pic = creator['photoUrl'] ?? '';
    final name = creator['name'] ?? 'Usuario';
    final age = creator['age'] ?? '';
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
        backgroundColor: Colors.purple[100],
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
  // TILE PARA MOSTRAR CADA PARTICIPANTE
  // ---------------------------------------------------------------------------
  Widget _buildParticipantTile(Map<String, dynamic> part) {
    final pic = part['photoUrl'] ?? '';
    final name = part['name'] ?? 'Usuario';
    final age = part['age'] ?? '';
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
  // BUILD PRINCIPAL
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final screenSize = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () => Navigator.pop(context), // Cierra el pop-up al tocar fuera
      behavior: HitTestBehavior.opaque,
      child: SafeArea(
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Evita propagar el tap dentro del diálogo
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: screenSize.width * 0.92,
                  constraints: BoxConstraints(
                    maxHeight: screenSize.height * 0.88,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0D253F),
                        Color(0xFF1B3A57),
                        Color(0xFF12232E),
                      ],
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Imagen de fondo (para planes normales)
                          if (plan.special_plan != 1 &&
                              plan.backgroundImage != null &&
                              plan.backgroundImage!.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(30),
                                topRight: Radius.circular(30),
                              ),
                              child: Image.network(
                                plan.backgroundImage!,
                                width: double.infinity,
                                height: 300,
                                fit: BoxFit.cover,
                              ),
                            ),
                          // Contenido
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Detalles del plan
                                _buildPlanDetailsArea(plan),
                                const SizedBox(height: 10),

                                // Creador y participantes
                                FutureBuilder<List<Map<String, dynamic>>>(
                                  future: _futureParticipants,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                    if (snapshot.hasError) {
                                      return Text(
                                        'Error: ${snapshot.error}',
                                        style: const TextStyle(
                                          color: Colors.black,
                                        ),
                                      );
                                    }
                                    final all = snapshot.data ?? [];
                                    if (all.isEmpty) {
                                      return const Text(
                                        'No hay participantes en este plan.',
                                        style: TextStyle(
                                          color: Color.fromARGB(
                                              255, 151, 121, 215),
                                        ),
                                      );
                                    }
                                    final creator = all.firstWhere(
                                      (p) => p['isCreator'] == true,
                                      orElse: () => {},
                                    );
                                    final participants = all
                                        .where((p) => p['isCreator'] == false)
                                        .toList();

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (creator.isNotEmpty) ...[
                                          const Text(
                                            "Creador del plan",
                                            style: TextStyle(color: Colors.white),
                                          ),
                                          const SizedBox(height: 8),
                                          _buildCreatorTile(creator),
                                          const SizedBox(height: 10),
                                        ],
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
                                          ...participants
                                              .map(_buildParticipantTile),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),

                                // CHAT
                                _buildChatSection(plan),
                                const SizedBox(height: 10),

                                // ID
                                _buildPlanIDArea(plan),
                                const SizedBox(height: 10),

                                // Descripción
                                _buildPlanDescriptionArea(plan),
                                const SizedBox(height: 10),

                                // Restricción de Edad / Máx. Participantes
                                if (plan.special_plan != 1) ...[
                                  _buildAgeRestrictionArea(plan),
                                  const SizedBox(height: 10),
                                  _buildMaxParticipantsArea(plan),
                                  const SizedBox(height: 10),
                                ],

                                // Fecha del Evento
                                _buildEventDateArea(plan),
                                const SizedBox(height: 10),

                                // Creado el
                                _buildCreatedAtArea(plan),
                                const SizedBox(height: 10),

                                // Ubicación
                                _buildLocationArea(plan),
                                const SizedBox(height: 16),

                                // Botón de cerrar
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      "Cerrar",
                                      style: TextStyle(
                                        color:
                                            Color.fromARGB(255, 151, 121, 215),
                                        fontWeight: FontWeight.bold,
                                      ),
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
            ),
          ),
        ),
      ),
    );
  }
}
