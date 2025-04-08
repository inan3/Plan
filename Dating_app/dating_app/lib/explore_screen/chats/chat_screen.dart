import 'dart:ui'; // Para ImageFilter (frosted glass)
import 'dart:io'; // Para File al subir imagen
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // <-- Importante
import 'package:flutter/scheduler.dart';

// Paquete para escoger imágenes
import 'package:image_picker/image_picker.dart';

// Paquete para ubicación (si usas geolocator)
import 'package:geolocator/geolocator.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../main/colors.dart';
import '../../models/plan_model.dart';
import '../users_managing/frosted_plan_dialog_state.dart'; // Ajusta la ruta a tu ubicación real
import '../users_managing/user_info_check.dart';

// IMPORTAMOS LA PANTALLA DE SELECCIÓN DE PLANES
import 'select_plan_screen.dart'; // <-- Este es el nuevo widget que verás más abajo

class ChatScreen extends StatefulWidget {
  final String chatPartnerId;
  final String chatPartnerName;
  final String? chatPartnerPhoto;
  final Timestamp? deletedAt; // Si el usuario eliminó el chat, se almacenará el timestamp

  const ChatScreen({
    Key? key,
    required this.chatPartnerId,
    required this.chatPartnerName,
    this.chatPartnerPhoto,
    this.deletedAt,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Para controlar si la localización de fechas ya fue inicializada:
  bool _localeInitialized = false;

  @override
  void initState() {
    super.initState();

    // Inicializamos la localización de fechas en español localmente
    initializeDateFormatting('es', null).then((_) {
      setState(() {
        _localeInitialized = true;
      });
    });

    // Marcamos los mensajes como leídos al entrar al chat
    _markMessagesAsRead();
  }

  /// Marca como leídos todos los mensajes recibidos en este chat.
  Future<void> _markMessagesAsRead() async {
    try {
      // Mensajes enviados por el chatPartner que no han sido leídos
      QuerySnapshot unreadMessages = await FirebaseFirestore.instance
          .collection('messages')
          .where('senderId', isEqualTo: widget.chatPartnerId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      // Mensajes marcados como leídos
    } catch (e) {
      print("❌ Error al marcar mensajes como leídos: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Encabezado superior
            _buildChatHeader(context),

            // Lista de mensajes, expandida para ocupar todo el espacio sobrante
            Expanded(
              child: _buildMessagesList(),
            ),

            // Área de entrada de mensaje en la parte inferior
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  /// Construye el encabezado (barra superior) del chat
  Widget _buildChatHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Botón de retroceso
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.blue),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(width: 8),

          // Info del chat: foto + nombre (expandido)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: () {
                  // Al pulsar en cualquier parte, abrimos la pantalla del usuario:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserInfoCheck(userId: widget.chatPartnerId),
                    ),
                  );
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: widget.chatPartnerPhoto != null
                          ? NetworkImage(widget.chatPartnerPhoto!)
                          : null,
                      backgroundColor: Colors.grey[300],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.chatPartnerName,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Botón menú (3 puntos)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.more_vert, color: AppColors.blue),
              onPressed: () {
                // Acciones extra si quieres
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Lista de mensajes con separadores de fecha y auto-scroll
  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('participants', arrayContains: currentUserId)
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        // Antes de filtrar, marcamos como 'delivered' los mensajes que lo necesiten
        _markAllMessagesAsDelivered(snapshot.data!.docs);

        // Filtramos solo los mensajes entre currentUserId y chatPartnerId,
        // además de descartar los anteriores a deletedAt, si existe.
        var filteredDocs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['timestamp'] is! Timestamp) return false;
          Timestamp timestamp = data['timestamp'];
          DateTime messageTime = timestamp.toDate();

          // Si hay un deletedAt, no mostramos los mensajes anteriores a ese momento
          if (widget.deletedAt != null &&
              messageTime.isBefore(widget.deletedAt!.toDate())) {
            return false;
          }

          // Verificar que son mensajes con sender/receiver correctos
          bool case1 = (data['senderId'] == currentUserId &&
              data['receiverId'] == widget.chatPartnerId);
          bool case2 = (data['senderId'] == widget.chatPartnerId &&
              data['receiverId'] == currentUserId);

          return case1 || case2;
        }).toList();

        // Si no hay mensajes tras filtrar:
        if (filteredDocs.isEmpty) {
          return const Center(
            child: Text(
              "No hay mensajes en este chat.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        // Creamos una lista "chatItems" donde insertamos
        // los separadores de fecha y los mensajes.
        List<dynamic> chatItems = [];
        String? lastDate;

        for (var doc in filteredDocs) {
          var data = doc.data() as Map<String, dynamic>;
          // Obtenemos la fecha del mensaje
          final timestamp = data['timestamp'] as Timestamp;
          final dateTime = timestamp.toDate();

          // Formateamos la fecha en el estilo deseado (solo si Intl está inicializado)
          String dayString;
          if (_localeInitialized) {
            dayString = DateFormat('d MMM yyyy', 'es').format(dateTime);
          } else {
            // Si Intl no está listo, usamos un formateo sencillo
            dayString = "${dateTime.day}/${dateTime.month}/${dateTime.year}";
          }

          // Si es un día distinto al último que registramos, insertamos separador
          if (lastDate == null || dayString != lastDate) {
            chatItems.add({'dayMarker': dayString});
            lastDate = dayString;
          }
          // Insertamos el propio documento del mensaje
          chatItems.add(doc);
        }

        // Hacemos auto-scroll al final después de dibujar (post-frame).
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          itemCount: chatItems.length,
          itemBuilder: (context, index) {
            final item = chatItems[index];

            // Si es un separador de fecha (un mapa con 'dayMarker')
            if (item is Map<String, dynamic> && item.containsKey('dayMarker')) {
              return _buildDayMarker(item['dayMarker']);
            }

            // Si es un DocumentSnapshot con datos del mensaje
            if (item is DocumentSnapshot) {
              var data = item.data() as Map<String, dynamic>;
              bool isMe = data['senderId'] == currentUserId;
              final String? type = data['type'] as String?;

              if (type == 'shared_plan') {
                return _buildSharedPlanBubble(data, isMe);
              } else if (type == 'image') {
                return _buildImageBubble(data, isMe);
              } else if (type == 'location') {
                return _buildLocationBubble(data, isMe);
              } else {
                // Caso texto normal
                return _buildTextBubble(data, isMe);
              }
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  /// Pequeño widget que muestra la fecha en el centro del chat, estilo WhatsApp
  Widget _buildDayMarker(String dayString) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              dayString,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Marca como 'delivered' todos los mensajes nuevos que el usuario actual ha recibido.
  Future<void> _markAllMessagesAsDelivered(List<DocumentSnapshot> docs) async {
    final undeliveredDocs = docs.where((doc) {
      var data = doc.data() as Map<String, dynamic>;
      bool isReceiver = data['receiverId'] == currentUserId;
      bool delivered = data['delivered'] ?? false;
      return isReceiver && !delivered; // si soy receptor y no está entregado
    }).toList();

    if (undeliveredDocs.isEmpty) return;

    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in undeliveredDocs) {
      batch.update(doc.reference, {'delivered': true});
    }

    try {
      await batch.commit();
    } catch (e) {
      print("❌ Error al marcar mensajes como entregados: $e");
    }
  }

  /// Burbuja para mensajes de texto
  Widget _buildTextBubble(Map<String, dynamic> data, bool isMe) {
    DateTime messageTime = DateTime.now();
    if (data['timestamp'] is Timestamp) {
      messageTime = (data['timestamp'] as Timestamp).toDate();
    }

    bool delivered = data['delivered'] ?? false;
    bool isRead = data['isRead'] ?? false;

    // Color crema para el emisor, lila crema para el receptor
    final bubbleColor = isMe
        ? const Color(0xFFF9E4D5) // Crema
        : const Color.fromARGB(255, 247, 237, 250); // Lila

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                data['text'] ?? '',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('HH:mm').format(messageTime),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isRead
                          ? Icons.done_all
                          : (delivered ? Icons.done_all : Icons.done),
                      size: 16,
                      color: isRead
                          ? Colors.green
                          : (delivered ? Colors.grey : Colors.grey),
                    ),
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Burbuja para mensajes que comparten un plan
  Widget _buildSharedPlanBubble(Map<String, dynamic> data, bool isMe) {
    final String planId = data['planId'] ?? '';
    final String planTitle = data['planTitle'] ?? 'Título';
    final String planDesc = data['planDescription'] ?? 'Descripción';
    final String planImage = data['planImage'] ?? '';
    final String planLink = data['planLink'] ?? '';

    DateTime messageTime = DateTime.now();
    if (data['timestamp'] is Timestamp) {
      messageTime = (data['timestamp'] as Timestamp).toDate();
    }

    bool delivered = data['delivered'] ?? false;
    bool isRead = data['isRead'] ?? false;

    final bubbleColor = isMe
        ? const Color(0xFFF9E4D5)
        : const Color(0xFFEBD6F2);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.65,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Imagen / preview del plan
            GestureDetector(
              onTap: () => _openPlanDetails(planId),
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  image: planImage.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(planImage),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: planImage.isEmpty
                    ? const Center(
                        child: Icon(Icons.image, size: 40, color: Colors.grey),
                      )
                    : null,
              ),
            ),
            // Texto del plan
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    planTitle,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    planDesc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  // Enlace (si existe)
                  if (planLink.isNotEmpty)
                    InkWell(
                      onTap: () => _openPlanDetails(planId),
                      child: Text(
                        planLink,
                        style: TextStyle(
                          color: isMe ? Colors.blue : Colors.blueAccent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment:
                        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(messageTime),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead
                              ? Icons.done_all
                              : (delivered ? Icons.done_all : Icons.done),
                          size: 16,
                          color: isRead
                              ? Colors.green
                              : (delivered ? Colors.grey : Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Burbuja para mensajes de imagen
  Widget _buildImageBubble(Map<String, dynamic> data, bool isMe) {
    final String imageUrl = data['imageUrl'] ?? '';

    DateTime messageTime = DateTime.now();
    if (data['timestamp'] is Timestamp) {
      messageTime = (data['timestamp'] as Timestamp).toDate();
    }

    bool delivered = data['delivered'] ?? false;
    bool isRead = data['isRead'] ?? false;

    final bubbleColor = isMe
        ? const Color(0xFFF9E4D5)
        : const Color(0xFFEBD6F2);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.65,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Imagen
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey[300],
                      height: 200,
                      child: const Icon(
                        Icons.image,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
            ),
            // Hora + checks
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('HH:mm').format(messageTime),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isRead
                          ? Icons.done_all
                          : (delivered ? Icons.done_all : Icons.done),
                      size: 16,
                      color: isRead
                          ? Colors.green
                          : (delivered ? Colors.grey : Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Burbuja para mensajes de ubicación
  Widget _buildLocationBubble(Map<String, dynamic> data, bool isMe) {
    final double? lat = data['latitude'];
    final double? lng = data['longitude'];

    DateTime messageTime = DateTime.now();
    if (data['timestamp'] is Timestamp) {
      messageTime = (data['timestamp'] as Timestamp).toDate();
    }

    bool delivered = data['delivered'] ?? false;
    bool isRead = data['isRead'] ?? false;

    final bubbleColor = isMe
        ? const Color(0xFFF9E4D5)
        : const Color(0xFFEBD6F2);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.65,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: InkWell(
          onTap: () {
            // Aquí podrías abrir Google Maps, o una pantalla con un Map widget
            // Por ejemplo: openMap(lat, lng);
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 40),
                Text(
                  lat != null && lng != null
                      ? 'Ubicación: ($lat, $lng)'
                      : 'Ubicación no disponible',
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment:
                      isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(messageTime),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isRead
                            ? Icons.done_all
                            : (delivered ? Icons.done_all : Icons.done),
                        size: 16,
                        color: isRead
                            ? Colors.green
                            : (delivered ? Colors.grey : Colors.grey),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Abre el plan con un FrostedPlanDialog
  void _openPlanDetails(String planId) async {
    try {
      final planDoc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(planId)
          .get();

      if (!planDoc.exists || planDoc.data() == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("El plan no existe o fue borrado.")),
        );
        return;
      }

      final planData = planDoc.data()!;
      final plan = PlanModel.fromMap(planData);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => FrostedPlanDialog(
            plan: plan,
            fetchParticipants: _fetchPlanParticipants,
          ),
        ),
      );
    } catch (e) {
      print("Error al abrir plan: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPlanParticipants(PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];

    // 1) Cargamos creador
    final docPlan = await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .get();
    if (docPlan.exists) {
      final planMap = docPlan.data();
      final creatorId = planMap?['createdBy'];
      if (creatorId != null) {
        final creatorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(creatorId)
            .get();
        if (creatorDoc.exists && creatorDoc.data() != null) {
          final cdata = creatorDoc.data()!;
          participants.add({
            'name': cdata['name'] ?? 'Sin nombre',
            'age': cdata['age']?.toString() ?? '',
            'photoUrl': cdata['photoUrl'] ?? '',
            'isCreator': true,
          });
        }
      }
    }

    // 2) Suscritos
    final subsSnap = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('id', isEqualTo: plan.id)
        .get();
    for (var sDoc in subsSnap.docs) {
      final data = sDoc.data();
      final uid = data['userId'];
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        final udata = userDoc.data()!;
        participants.add({
          'name': udata['name'] ?? 'Sin nombre',
          'age': udata['age']?.toString() ?? '',
          'photoUrl': udata['photoUrl'] ?? '',
          'isCreator': false,
        });
      }
    }

    return participants;
  }

  /// Área de entrada de mensaje
  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Botón "+"
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: AppColors.blue),
              onPressed: _showAttachmentOptions, // <-- Aquí la nueva función
            ),
          ),
          const SizedBox(width: 8),
          // Campo de texto
          Expanded(
            child: Container(
              height: 48,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: "Escribe un mensaje...",
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Botón "Send"
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: AppColors.blue),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  /// Muestra el bottom sheet con las 3 opciones: Ubicación, Plan, Foto
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // OPCIÓN 1: Ubicación
              _buildFloatingOption(
                svgPath: 'assets/icono-ubicacion.svg',
                label: 'Ubicación',
                onTap: () async {
                  Navigator.pop(ctx);
                  await _handleSendLocation();
                },
              ),
              // OPCIÓN 2: Plan
              _buildFloatingOption(
                svgPath: 'assets/plan-sin-fondo.png',
                label: 'Plan',
                onTap: () {
                  Navigator.pop(ctx);
                  _showPlanSelection();
                },
              ),
              // OPCIÓN 3: Foto
              _buildFloatingOption(
                svgPath: 'assets/icono-imagen.svg',
                label: 'Foto',
                onTap: () {
                  Navigator.pop(ctx);
                  _handleSelectImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Botón circular con ícono y texto debajo
  Widget _buildFloatingOption({
    required String svgPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            // Ajusta para svg:
            // child: Center(child: SvgPicture.asset(svgPath, width: 30, height: 30)),
            child: Center(
              child: Image.asset(
                svgPath,
                width: 30,
                height: 30,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black),
        ),
      ],
    );
  }

  /// Envía la ubicación actual (tipo 'location')
  Future<void> _handleSendLocation() async {
    try {
      // Pide permisos y obtén posición con geolocator, por ejemplo:
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // No hay GPS habilitado
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // El usuario denegó permisos
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        // El usuario denegó permanente
        return;
      }

      // Ahora sí obten la posición
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': currentUserId,
        'receiverId': widget.chatPartnerId,
        'participants': [currentUserId, widget.chatPartnerId],
        'type': 'location',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'delivered': false,
      });
    } catch (e) {
      print("Error al obtener/enviar ubicación: $e");
    }
  }

  /// Abre la pantalla de selección de planes
  void _showPlanSelection() async {
    final selectedPlans = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const SelectPlanScreen(),
      ),
    );

    if (selectedPlans == null || selectedPlans.isEmpty) return;

    // Enviamos cada plan como 'shared_plan'
    for (String planId in selectedPlans) {
      final planDoc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(planId)
          .get();
      if (!planDoc.exists) continue;

      final planData = planDoc.data() as Map<String, dynamic>;
      final plan = PlanModel.fromMap(planData);

      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': currentUserId,
        'receiverId': widget.chatPartnerId,
        'participants': [currentUserId, widget.chatPartnerId],
        'type': 'shared_plan',
        'planId': plan.id,
        'planTitle': plan.type, // o lo que quieras mostrar
        'planDescription': plan.description,
        'planImage': plan.backgroundImage ?? '',
        'planLink': '',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'delivered': false,
      });
    }
  }

  /// Escoger imagen (cámara o galería)
  Future<void> _handleSelectImage() async {
    final picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Seleccionar imagen'),
          content: const Text('Elige desde dónde obtener la foto'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.camera,
                );
                if (image != null) {
                  _uploadAndSendImage(image);
                }
              },
              child: const Text('Cámara'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  _uploadAndSendImage(image);
                }
              },
              child: const Text('Galería'),
            ),
          ],
        );
      },
    );
  }

  /// Sube la imagen a Firebase Storage y envía el mensaje
  Future<void> _uploadAndSendImage(XFile imageFile) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(File(imageFile.path));
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': currentUserId,
        'receiverId': widget.chatPartnerId,
        'participants': [currentUserId, widget.chatPartnerId],
        'type': 'image',
        'imageUrl': downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'delivered': false,
      });
    } catch (e) {
      print("Error subiendo/enviando imagen: $e");
    }
  }

  /// Enviar mensaje de texto
  void _sendMessage() async {
    String messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': currentUserId,
        'receiverId': widget.chatPartnerId,
        'participants': [currentUserId, widget.chatPartnerId],
        'type': 'text',
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'delivered': false,
      });

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print("❌ Error al enviar mensaje: $e");
    }
  }

  /// Auto-scroll al final del ListView
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }
}
