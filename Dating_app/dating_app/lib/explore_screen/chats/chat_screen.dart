import 'dart:ui'; // Para ImageFilter (frosted glass)
import 'dart:io'; // Para File al subir imagen
import 'dart:async'; // Para Completer usado en _getImageSize
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // <-- Importante
import 'package:flutter/scheduler.dart';

import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart'; // Si lo usas en tu app
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../main/colors.dart';
import '../../models/plan_model.dart';
import '../users_managing/frosted_plan_dialog_state.dart';
import '../users_managing/user_info_check.dart';
import 'select_plan_screen.dart';
import 'location_pick_screen.dart';
// Importamos nuestra función para abrir la imagen a pantalla completa
import 'inner_chat_utils/picture_managing.dart';
// Importamos nuestra función para abrir la ubicación
import 'inner_chat_utils/open_location.dart';
// Importamos el mixin para manejar la respuesta a un mensaje
import 'inner_chat_utils/answer_a_message.dart';

class ChatScreen extends StatefulWidget {
  final String chatPartnerId;
  final String chatPartnerName;
  final String? chatPartnerPhoto;
  final Timestamp? deletedAt;

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

// Mezclamos con el mixin AnswerAMessageMixin para la funcionalidad de responder
class _ChatScreenState extends State<ChatScreen> with AnswerAMessageMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _localeInitialized = false;

  // Cargamos un Future con el icono del marcador si lo usas en ubicaciones
  late Future<BitmapDescriptor> _markerIconFuture;

  @override
  void initState() {
    super.initState();

    // Inicializa formato local “es”
    initializeDateFormatting('es', null).then((_) {
      setState(() {
        _localeInitialized = true;
      });
    });

    // Marca como leídos los mensajes
    _markMessagesAsRead();

    // Carga icono custom si deseas. Si no, usa default:
    _markerIconFuture = _loadMarkerIcon();
  }

  // Ejemplo de función que carga un icono de marcador
  Future<BitmapDescriptor> _loadMarkerIcon() async {
    try {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    } catch (e) {
      print("Error al cargar icono del marcador: $e");
      return BitmapDescriptor.defaultMarker;
    }
  }

  /// Marca como leídos todos los mensajes recibidos en este chat
  Future<void> _markMessagesAsRead() async {
    try {
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
    } catch (e) {
      print("❌ Error al marcar mensajes como leídos: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildChatHeader(context),
            Expanded(child: _buildMessagesList()),

            // Si estamos respondiendo a algo, mostramos la vista previa arriba del input
            if (isReplying)
              buildReplyPreview(
                onCancelReply: () {
                  cancelReply();
                },
              ),

            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  /// Encabezado superior (con foto, nombre, botón back y menú)
  Widget _buildChatHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
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
                  // Al pulsar, abrimos UserInfoCheck
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          UserInfoCheck(userId: widget.chatPartnerId),
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
                // Acciones extra
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Lista de mensajes
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

        _markAllMessagesAsDelivered(snapshot.data!.docs);

        // Filtramos mensajes entre currentUserId <-> widget.chatPartnerId
        // y que sean posteriores a deletedAt (si existe).
        var filteredDocs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['timestamp'] is! Timestamp) return false;
          Timestamp timestamp = data['timestamp'];
          DateTime messageTime = timestamp.toDate();

          if (widget.deletedAt != null &&
              messageTime.isBefore(widget.deletedAt!.toDate())) {
            return false;
          }

          bool case1 = (data['senderId'] == currentUserId &&
              data['receiverId'] == widget.chatPartnerId);
          bool case2 = (data['senderId'] == widget.chatPartnerId &&
              data['receiverId'] == currentUserId);
          return case1 || case2;
        }).toList();

        if (filteredDocs.isEmpty) {
          return const Center(
            child: Text(
              "No hay mensajes en este chat.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        // Insertamos separadores de fecha en la lista final
        List<dynamic> chatItems = [];
        String? lastDate;

        for (var doc in filteredDocs) {
          var data = doc.data() as Map<String, dynamic>;
          final timestamp = data['timestamp'] as Timestamp;
          final dateTime = timestamp.toDate();

          String dayString;
          if (_localeInitialized) {
            dayString = DateFormat('d MMM yyyy', 'es').format(dateTime);
          } else {
            dayString = "${dateTime.day}/${dateTime.month}/${dateTime.year}";
          }

          if (lastDate == null || dayString != lastDate) {
            chatItems.add({'dayMarker': dayString});
            lastDate = dayString;
          }
          chatItems.add(doc);
        }

        // Desplazamos el scroll al final cuando hay nuevos mensajes
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          itemCount: chatItems.length,
          itemBuilder: (context, index) {
            final item = chatItems[index];
            if (item is Map<String, dynamic> && item.containsKey('dayMarker')) {
              return _buildDayMarker(item['dayMarker']);
            }
            if (item is DocumentSnapshot) {
              var data = item.data() as Map<String, dynamic>;
              bool isMe = data['senderId'] == currentUserId;
              final String? type = data['type'] as String?;

              // Detectamos swipe (para responder directo) y long press (para diálogo)
              return GestureDetector(
                onHorizontalDragUpdate: (details) {
                  // Si se arrastra a la derecha con cierta distancia
                  if (details.delta.dx > 15) {
                    startReplyingTo({
                      'docId': item.id,
                      'type': type ?? 'text',
                      'text': data['text'] ?? '',
                      'senderId': data['senderId'],
                    });
                  }
                },
                onLongPress: () {
                  // Abrimos el diálogo frosted con 4 opciones
                  showMessageOptionsDialog(
                    context,
                    {
                      'docId': item.id,
                      'type': type ?? 'text',
                      'text': data['text'] ?? '',
                      'senderId': data['senderId'],
                    },
                    // Opcional: puedes personalizar "onReact" y "onDelete"
                    onDelete: () async {
                      // Ejemplo de borrado en Firestore (sólo si el user es dueño o tienes permiso)
                      final docId = item.id;
                      try {
                        await FirebaseFirestore.instance
                            .collection('messages')
                            .doc(docId)
                            .delete();
                        debugPrint('Mensaje $docId eliminado');
                      } catch (e) {
                        debugPrint('Error eliminando mensaje: $e');
                      }
                    },
                    onReact: () {
                      debugPrint('Usuario reaccionó al mensaje');
                      // Implementa aquí tu lógica de reacciones
                    },
                  );
                },
                child: _buildBubbleByType(data, isMe),
              );
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  /// Marca mensajes como 'delivered'
  Future<void> _markAllMessagesAsDelivered(List<DocumentSnapshot> docs) async {
    final undeliveredDocs = docs.where((doc) {
      var data = doc.data() as Map<String, dynamic>;
      bool isReceiver = data['receiverId'] == currentUserId;
      bool delivered = data['delivered'] ?? false;
      return isReceiver && !delivered;
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

  /// Función helper para decidir qué burbuja dibujar según el 'type'
  Widget _buildBubbleByType(Map<String, dynamic> data, bool isMe) {
    final String? type = data['type'] as String?;

    if (type == 'shared_plan') {
      return _buildSharedPlanBubble(data, isMe);
    } else if (type == 'image') {
      return _buildImageBubble(data, isMe);
    } else if (type == 'location') {
      return _buildLocationBubble(data, isMe);
    } else {
      // Texto
      return _buildTextBubble(data, isMe);
    }
  }

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

  /// Burbuja de texto
  Widget _buildTextBubble(Map<String, dynamic> data, bool isMe) {
    DateTime messageTime = DateTime.now();
    if (data['timestamp'] is Timestamp) {
      messageTime = (data['timestamp'] as Timestamp).toDate();
    }
    bool delivered = data['delivered'] ?? false;
    bool isRead = data['isRead'] ?? false;

    final bubbleColor = isMe
        ? const Color(0xFFF9E4D5)
        : const Color.fromARGB(255, 247, 237, 250);

    // Si este mensaje responde a otro, leemos data['replyTo']
    final replyTo = data['replyTo'] as Map<String, dynamic>?;

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
              // Cajita gris que muestra el mensaje original
              if (replyTo != null) buildReplyContainer(replyTo),

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

  /// Burbuja de ubicación
  Widget _buildLocationBubble(Map<String, dynamic> data, bool isMe) {
    final double? lat = data['latitude'];
    final double? lng = data['longitude'];
    final String? address = data['address'];

    DateTime messageTime = DateTime.now();
    if (data['timestamp'] is Timestamp) {
      messageTime = (data['timestamp'] as Timestamp).toDate();
    }
    bool delivered = data['delivered'] ?? false;
    bool isRead = data['isRead'] ?? false;

    final bubbleColor =
        isMe ? const Color(0xFFF9E4D5) : const Color(0xFFEBD6F2);

    // Si este mensaje responde a otro
    final replyTo = data['replyTo'] as Map<String, dynamic>?;

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
            if (lat != null && lng != null) {
              openLocation(lat: lat, lng: lng, address: address);
            }
          },
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Cajita gris de respuesta original
              if (replyTo != null) buildReplyContainer(replyTo),

              if (lat != null && lng != null)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: FutureBuilder<BitmapDescriptor>(
                      future: _markerIconFuture,
                      builder: (ctx, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final icon = snapshot.data!;
                        return GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(lat, lng),
                            zoom: 14,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('location-marker'),
                              position: LatLng(lat, lng),
                              icon: icon,
                            ),
                          },
                          zoomControlsEnabled: false,
                          scrollGesturesEnabled: false,
                          rotateGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                          liteModeEnabled: true,
                        );
                      },
                    ),
                  ),
                )
              else
                Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: const Icon(Icons.map, size: 50, color: Colors.grey),
                ),

              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  (address != null && address.isNotEmpty)
                      ? address
                      : 'Ubicación compartida',
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
                child: Row(
                  mainAxisAlignment:
                      isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(messageTime),
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
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
      ),
    );
  }

  /// Burbuja de plan compartido
  Widget _buildSharedPlanBubble(Map<String, dynamic> data, bool isMe) {
    final String planId = data['planId'] ?? '';
    final String planTitle = data['planTitle'] ?? 'Título';
    final String planDesc = data['planDescription'] ?? 'Descripción';
    final String planImage = data['planImage'] ?? '';
    final String planLink = data['planLink'] ?? '';
    final String planStartDate = data['planStartDate'] ?? '';

    DateTime messageTime = DateTime.now();
    if (data['timestamp'] is Timestamp) {
      messageTime = (data['timestamp'] as Timestamp).toDate();
    }
    bool delivered = data['delivered'] ?? false;
    bool isRead = data['isRead'] ?? false;

    final bubbleColor =
        isMe ? const Color(0xFFF9E4D5) : const Color(0xFFEBD6F2);

    // Si este mensaje responde a otro
    final replyTo = data['replyTo'] as Map<String, dynamic>?;

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
            if (replyTo != null) buildReplyContainer(replyTo),

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
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  const Text(
                    "¡Échale un vistazo a este plan!",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    planTitle,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    planDesc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 4),
                  if (planStartDate.isNotEmpty)
                    Text(
                      "Fecha de inicio: $planStartDate",
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 8),
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

  /// Para obtener el tamaño de la imagen en la red (ancho y alto).
  Future<Size> _getImageSize(String imageUrl) async {
    final Completer<Size> completer = Completer();

    final ImageStream imageStream =
        NetworkImage(imageUrl).resolve(const ImageConfiguration());
    late ImageStreamListener listener;

    listener = ImageStreamListener((ImageInfo info, bool _) {
      final myImage = info.image;
      final size = Size(
        myImage.width.toDouble(),
        myImage.height.toDouble(),
      );
      completer.complete(size);
      imageStream.removeListener(listener);
    }, onError: (dynamic exception, StackTrace? stackTrace) {
      completer.completeError(exception, stackTrace);
      imageStream.removeListener(listener);
    });

    imageStream.addListener(listener);

    return completer.future;
  }

  /// Burbuja de imagen
  Widget _buildImageBubble(Map<String, dynamic> data, bool isMe) {
    final String imageUrl = data['imageUrl'] ?? '';

    DateTime messageTime = DateTime.now();
    if (data['timestamp'] is Timestamp) {
      messageTime = (data['timestamp'] as Timestamp).toDate();
    }
    bool delivered = data['delivered'] ?? false;
    bool isRead = data['isRead'] ?? false;

    final bubbleColor =
        isMe ? const Color(0xFFF9E4D5) : const Color(0xFFEBD6F2);

    // Si este mensaje responde a otro
    final replyTo = data['replyTo'] as Map<String, dynamic>?;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
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
        child: FutureBuilder<Size>(
          future: _getImageSize(imageUrl),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.65,
                height: 150,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.65,
                height: 150,
                color: Colors.grey[300],
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image,
                  size: 40,
                  color: Colors.grey,
                ),
              );
            }

            final Size imageSize = snapshot.data!;
            final double maxWidth =
                MediaQuery.of(context).size.width * 0.65;

            double displayWidth = imageSize.width;
            double displayHeight = imageSize.height;

            if (displayWidth > maxWidth) {
              final double ratio = maxWidth / displayWidth;
              displayWidth = maxWidth;
              displayHeight = displayHeight * ratio;
            }

            return Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Cajita gris si hay reply
                if (replyTo != null) buildReplyContainer(replyTo),

                GestureDetector(
                  onTap: () {
                    // Abrir imagen a pantalla completa
                    openFullImage(context, imageUrl);
                  },
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: SizedBox(
                      width: displayWidth,
                      height: displayHeight,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
            );
          },
        ),
      ),
    );
  }

  /// Abre detalles del plan
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
            fetchParticipants: _fetchPlanParticipantsWithUid,
          ),
        ),
      );
    } catch (e) {
      print("Error al abrir plan: $e");
    }
  }

  /// Incluir 'uid' en cada participante
  Future<List<Map<String, dynamic>>> _fetchPlanParticipantsWithUid(
      PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];

    final docPlan =
        await FirebaseFirestore.instance.collection('plans').doc(plan.id).get();

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
            'uid': creatorId,
            'name': cdata['name'] ?? 'Sin nombre',
            'age': cdata['age']?.toString() ?? '',
            'photoUrl': cdata['photoUrl'] ?? '',
            'isCreator': true,
          });
        }
      }
    }

    // Suscriptores
    final subsSnap = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('id', isEqualTo: plan.id)
        .get();
    for (var sDoc in subsSnap.docs) {
      final data = sDoc.data();
      final uid = data['userId'];
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final uData = userDoc.data()!;
        participants.add({
          'uid': uid,
          'name': uData['name'] ?? 'Sin nombre',
          'age': uData['age']?.toString() ?? '',
          'photoUrl': uData['photoUrl'] ?? '',
          'isCreator': false,
        });
      }
    }

    return participants;
  }

  /// Área inferior para escribir mensaje + botón de envío
  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
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
              onPressed: _showAttachmentOptions,
            ),
          ),
          const SizedBox(width: 8),
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
              _buildFloatingOption(
                svgPath: 'assets/icono-ubicacion.svg',
                label: 'Ubicación',
                onTap: () async {
                  Navigator.pop(ctx);
                  await _handleSendLocationWithPicker();
                },
              ),
              _buildFloatingOption(
                svgPath: 'assets/plan-sin-fondo.png',
                label: 'Plan',
                onTap: () {
                  Navigator.pop(ctx);
                  _showPlanSelection();
                },
              ),
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
            child: Center(
              child: svgPath.toLowerCase().endsWith('.svg')
                  ? SvgPicture.asset(
                      svgPath,
                      width: 30,
                      height: 30,
                      color: AppColors.blue,
                    )
                  : Image.asset(
                      svgPath,
                      width: 50,
                      height: 50,
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

  /// Muestra LocationPickScreen para elegir la ubicación
  Future<void> _handleSendLocationWithPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationPickScreen(),
      ),
    );

    if (result != null) {
      final lat = result['latitude'] as double?;
      final lng = result['longitude'] as double?;
      final address = result['address'] as String?;

      if (lat != null && lng != null) {
        await FirebaseFirestore.instance.collection('messages').add({
          'senderId': currentUserId,
          'receiverId': widget.chatPartnerId,
          'participants': [currentUserId, widget.chatPartnerId],
          'type': 'location',
          'latitude': lat,
          'longitude': lng,
          'address': address ?? '',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'delivered': false,
          // Incluimos la info de "replyTo" (si está activo)
          'replyTo': buildReplyMapForSending(),
        });
        // Limpiamos el estado de “responder”
        cancelReply();
      }
    }
  }

  void _showPlanSelection() async {
    final selectedPlans = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const SelectPlanScreen(),
      ),
    );
    if (selectedPlans == null || selectedPlans.isEmpty) return;

    for (String planId in selectedPlans) {
      final planDoc =
          await FirebaseFirestore.instance.collection('plans').doc(planId).get();
      if (!planDoc.exists) continue;

      final planData = planDoc.data() as Map<String, dynamic>;
      final plan = PlanModel.fromMap(planData);

      // Si plan.startTimestamp existe, lo formateas en una cadena
      String planStartDateString = '';
      if (plan.startTimestamp != null) {
        final date = plan.startTimestamp!;
        planStartDateString =
            DateFormat('d MMM yyyy, HH:mm', 'es').format(date);
      }

      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': currentUserId,
        'receiverId': widget.chatPartnerId,
        'participants': [currentUserId, widget.chatPartnerId],
        'type': 'shared_plan',
        'planId': plan.id,
        'planTitle': plan.type,
        'planDescription': plan.description,
        'planImage': plan.backgroundImage ?? '',
        'planLink': '',
        'planStartDate': planStartDateString,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'delivered': false,
        // Info de “replyTo”
        'replyTo': buildReplyMapForSending(),
      });
    }
    cancelReply();
  }

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
        'replyTo': buildReplyMapForSending(),
      });

      cancelReply();
    } catch (e) {
      print("Error subiendo/enviando imagen: $e");
    }
  }

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
        // Guardamos si es respuesta a otro mensaje
        'replyTo': buildReplyMapForSending(),
      });

      _messageController.clear();
      _scrollToBottom();

      // Cancelamos modo responder
      cancelReply();
    } catch (e) {
      print("❌ Error al enviar mensaje: $e");
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }
}
