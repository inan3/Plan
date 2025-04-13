import 'dart:ui'; // Para ImageFilter (frosted glass)
import 'dart:io'; // Para File al subir imagen
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
// Añade tu plugin de Google Maps
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../main/colors.dart';
import '../../models/plan_model.dart';
import '../users_managing/frosted_plan_dialog_state.dart';
import '../users_managing/user_info_check.dart';
import 'select_plan_screen.dart';
import 'location_pick_screen.dart';

// 1) Importa tu nueva función de open_location (para abrir la ubicación externamente)
import 'inner_chat_utils/open_location.dart';

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

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _localeInitialized = false;

  // (Opcional) Si quieres un marcador custom para el GoogleMap de la burbuja:
  // Preparamos un Future<BitmapDescriptor> para no recargar en cada burbuja
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

    // Carga icono custom si deseas. Si no, puedes usar default:
    // _markerIconFuture = Future.value(BitmapDescriptor.defaultMarker);
    _markerIconFuture = _loadMarkerIcon();
  }

  // Ejemplo de función que carga un icono de marcador (puede ser SVG, PNG, etc.)
  Future<BitmapDescriptor> _loadMarkerIcon() async {
    try {
      // Retorna un marcador por defecto, o personaliza si quieres
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
                // Acciones extra (en desarrollo)
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

              if (type == 'shared_plan') {
                return _buildSharedPlanBubble(data, isMe);
              } else if (type == 'image') {
                return _buildImageBubble(data, isMe);
              } else if (type == 'location') {
                return _buildLocationBubble(data, isMe);
              } else {
                // texto
                return _buildTextBubble(data, isMe);
              }
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

  /// Aquí incrustamos un GoogleMap en modo lite, con un marcador y la dirección
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
        // Al pulsar, abrimos la ubicación en Maps externamente
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
              // Mapa en modo lite, con un solo marcador
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
                          liteModeEnabled: true, // Mapa estático
                        );
                      },
                    ),
                  ),
                )
              else
                // Si no hay coords
                Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: const Icon(Icons.map, size: 50, color: Colors.grey),
                ),

              // Texto de la dirección
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  (address != null && address.isNotEmpty)
                      ? address
                      : 'Ubicación compartida',
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                ),
              ),

              // Hora y checkmarks
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

  Widget _buildSharedPlanBubble(Map<String, dynamic> data, bool isMe) {
  final String planId = data['planId'] ?? '';
  final String planTitle = data['planTitle'] ?? 'Título';
  final String planDesc = data['planDescription'] ?? 'Descripción';
  final String planImage = data['planImage'] ?? '';
  final String planLink = data['planLink'] ?? '';
  
  // Recuperamos la fecha de inicio formateada:
  final String planStartDate = data['planStartDate'] ?? '';

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
          // Gestor del tap en la imagen
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
                // --- Mensaje de “¡Échale un vistazo...” ---
                const Text(
                  "¡Échale un vistazo a este plan!",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),

                // --- Título del plan ---
                Text(
                  planTitle,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                
                // --- Descripción ---
                Text(
                  planDesc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 4),

                // --- Fecha de inicio si la hay ---
                if (planStartDate.isNotEmpty)
                  Text(
                    "Fecha de inicio: $planStartDate",
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                
                const SizedBox(height: 8),

                // (Opcional) Link o un "Ver más"
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

                // --- Hora del mensaje y checks ---
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
    PlanModel plan,
  ) async {
    final List<Map<String, dynamic>> participants = [];

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
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
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
              // Ubicación
              _buildFloatingOption(
                svgPath: 'assets/icono-ubicacion.svg',
                label: 'Ubicación',
                onTap: () async {
                  Navigator.pop(ctx);
                  await _handleSendLocationWithPicker();
                },
              ),
              // Plan
              _buildFloatingOption(
                svgPath: 'assets/plan-sin-fondo.png',
                label: 'Plan',
                onTap: () {
                  Navigator.pop(ctx);
                  _showPlanSelection();
                },
              ),
              // Foto
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
        // Envía el mensaje con 'type': 'location'
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
        });
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
    final planDoc = await FirebaseFirestore.instance
        .collection('plans')
        .doc(planId)
        .get();
    if (!planDoc.exists) continue;

    final planData = planDoc.data() as Map<String, dynamic>;
    final plan = PlanModel.fromMap(planData);

    // Si plan.startTimestamp existe, lo formateas en una cadena:
    String planStartDateString = '';
    if (plan.startTimestamp != null) {
      final date = plan.startTimestamp!;
      planStartDateString = DateFormat('d MMM yyyy, HH:mm', 'es').format(date);
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
      // Nuevo campo con la fecha de inicio formateada:
      'planStartDate': planStartDateString, 
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'delivered': false,
    });
  }
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
      });
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
      });

      _messageController.clear();
      _scrollToBottom();
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
