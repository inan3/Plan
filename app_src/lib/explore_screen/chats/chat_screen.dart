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
import 'package:geolocator/geolocator.dart'; // Si lo usas
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../profile/user_images_managing.dart';

import '../../l10n/app_localizations.dart';

import '../../main/colors.dart';
import '../../models/plan_model.dart';
import '../plans_managing/frosted_plan_dialog_state.dart';
import '../users_managing/user_info_check.dart';
import 'select_plan_screen.dart';
import 'location_pick_screen.dart';
// Para abrir imagen a pantalla completa
import 'inner_chat_utils/picture_managing.dart';
// Para abrir ubicación
import 'inner_chat_utils/open_location.dart';
// Importamos el mixin para manejar la respuesta a un mensaje
import 'inner_chat_utils/answer_a_message.dart';
import '../users_managing/report_and_block_user.dart';

// Importa el widget de presencia:
import '../users_managing/user_activity_status.dart';

class ChatScreen extends StatefulWidget {
  final String chatPartnerId;
  final String chatPartnerName;
  final String? chatPartnerPhoto;

  /// Ya no vamos a usar [deletedAt] a nivel de constructor,
  /// porque ahora usaremos las fechas guardadas en userDoc.
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
  // Key for the three-dots button to get its position
  final GlobalKey _menuButtonKey = GlobalKey();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _localeInitialized = false;

  // Para notificaciones en este chat (manejo local, sin persistir)
  // Por defecto se encuentran habilitadas hasta que el usuario decida lo contrario
  bool _notificationsEnabled = true;

  // Para saber si yo tengo bloqueado a mi chatPartner
  bool _isPartnerBlocked = false;

  bool _partnerActivityPublic = true;

  // Carga futuro con icono de marcador (para ubicaciones)
  late Future<BitmapDescriptor> _markerIconFuture;

  /// Fecha en que YO borré el chat con mi partner, si aplica
  Timestamp? _myDeletedAt;

  /// Fecha en que el partner borró el chat conmigo, si aplica
  Timestamp? _theirDeletedAt;

  @override
  void initState() {
    super.initState();

    // Inicializa formato local “es”
    initializeDateFormatting('es', null).then((_) {
      setState(() {
        _localeInitialized = true;
      });
    });

    // Carga icono custom
    _markerIconFuture = _loadMarkerIcon();

    // Verificamos si el chatPartner está actualmente bloqueado por mí
    _checkIfPartnerIsBlocked();

    // Cargar las fechas de borrado (si existen)
    _loadDeletedChatDates().then((_) {
      // Tras cargar, intentamos borrar físicamente mensajes si aplica
      _deleteOldMessagesIfBothDeleted();
    }).then((_) {
      // Marca como leídos (primer intento) al entrar:
      _markMessagesAsRead();
    });
  }

  /// Carga la fecha en que YO borré el chat con el partner, y la fecha en que
  /// mi partner borró el chat conmigo.
  Future<void> _loadDeletedChatDates() async {
    final meDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();
    if (meDoc.exists) {
      final myData = meDoc.data()!;
      if (myData['deletedChats'] != null &&
          myData['deletedChats'][widget.chatPartnerId] != null) {
        _myDeletedAt = myData['deletedChats'][widget.chatPartnerId];
      }
    }

    final partnerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.chatPartnerId)
        .get();
    if (partnerDoc.exists) {
      final theirData = partnerDoc.data()!;
      if (theirData['deletedChats'] != null &&
          theirData['deletedChats'][currentUserId] != null) {
        _theirDeletedAt = theirData['deletedChats'][currentUserId];
      }
      _partnerActivityPublic =
          theirData['activityStatusPublic'] != false;
    }
  }

  /// Si ambos han borrado el chat, comprobamos si ya pasaron 7 días
  /// desde la fecha de borrado más reciente. De ser así, borramos de Firestore
  /// todos los mensajes anteriores a la fecha de borrado más antigua.
  Future<void> _deleteOldMessagesIfBothDeleted() async {
    if (_myDeletedAt == null || _theirDeletedAt == null) return;

    final myDate = _myDeletedAt!.toDate();
    final theirDate = _theirDeletedAt!.toDate();

    // La más antigua
    final earliest = myDate.isBefore(theirDate) ? myDate : theirDate;
    // La más reciente
    final latest = myDate.isAfter(theirDate) ? myDate : theirDate;

    final now = DateTime.now();

    // Si ya pasó una semana desde la más reciente
    if (now.isAfter(latest.add(const Duration(days: 7)))) {
      // Borramos (batch) todos los mensajes con timestamp < earliest
      try {
        final snap = await FirebaseFirestore.instance
            .collection('messages')
            .where('participants', arrayContains: currentUserId)
            .where('timestamp', isLessThan: Timestamp.fromDate(earliest))
            .get();

        if (snap.docs.isNotEmpty) {
          WriteBatch batch = FirebaseFirestore.instance.batch();
          for (var doc in snap.docs) {
            final data = doc.data() as Map<String, dynamic>;
            // Verificamos que sea realmente entre currentUserId y chatPartnerId
            final participants = data['participants'];
            if (participants is List &&
                participants.contains(widget.chatPartnerId) &&
                participants.contains(currentUserId)) {
              batch.delete(doc.reference);
            }
          }
          await batch.commit();
        }
      } catch (e) {
      }
    }
  }

  /// Marca como leídos todos los mensajes recibidos de este chat (llamada puntual)
  Future<void> _markMessagesAsRead() async {
    try {
      QuerySnapshot unreadMessages = await FirebaseFirestore.instance
          .collection('messages')
          .where('participants', arrayContains: currentUserId)
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
    }
  }

  /// Marca en tiempo real los mensajes de este chat como leídos según vayan llegando
  Future<void> _markAllMessagesAsReadInSnapshot(
      List<DocumentSnapshot> docs) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    bool needCommit = false;

    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      final senderId = data['senderId'];
      final receiverId = data['receiverId'];
      final isRead = data['isRead'] ?? false;

      // Deben ser mensajes del partner hacia mí y no leídos aún
      if (senderId == widget.chatPartnerId &&
          receiverId == currentUserId &&
          !isRead) {
        batch.update(doc.reference, {'isRead': true});
        needCommit = true;
      }
    }

    if (needCommit) {
      try {
        await batch.commit();
      } catch (e) {
      }
    }
  }

  Future<void> _checkIfPartnerIsBlocked() async {
    if (currentUserId.isEmpty || widget.chatPartnerId.isEmpty) return;

    // Para "bloqueo" => docId = '${blockerId}_${blockedId}'
    final docId = '${currentUserId}_${widget.chatPartnerId}';
    final doc = await FirebaseFirestore.instance
        .collection('blocked_users')
        .doc(docId)
        .get();

    setState(() {
      // Si existe, significa que YO he bloqueado a mi chatPartner
      _isPartnerBlocked = doc.exists;
    });
  }

  Future<BitmapDescriptor> _loadMarkerIcon() async {
    try {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    } catch (e) {
      return BitmapDescriptor.defaultMarker;
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

            // Vista previa si estamos respondiendo a algo
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

  /// Encabezado superior (foto, nombre, botón back)
  Widget _buildChatHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Botón de flecha atrás
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

          // Info del chat (avatar, nombre, estado de actividad, etc.)
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: const Color.fromARGB(255, 14, 14, 14).withOpacity(0.25),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: GestureDetector(
                    onTap: () {
                      UserInfoCheck.open(context, widget.chatPartnerId);
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.chatPartnerName,
                                style: const TextStyle(
                                  color: Colors.white, // ← blanco
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_partnerActivityPublic)
                                UserActivityStatus(
                                  userId: widget.chatPartnerId,
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
          const SizedBox(width: 8),

          // Botón de tres puntos => menú
          Container(
            key: _menuButtonKey,
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
              onPressed: _showOptionsMenu,
            ),
          ),
        ],
      ),
    );
  }

  /// Muestra el pop-up con “Habilitar/Deshabilitar notificaciones”,
  /// “Reportar perfil” y “Bloquear/Desbloquear perfil”.
  void _showOptionsMenu() {
    // Get the position and size of the three-dots button
    final RenderBox? buttonBox = _menuButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    Offset offset = Offset.zero;
    Size buttonSize = Size.zero;
    if (buttonBox != null && overlay != null) {
      offset = buttonBox.localToGlobal(Offset.zero, ancestor: overlay);
      buttonSize = buttonBox.size;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final t = AppLocalizations.of(context);
            // Cambiamos el texto según si está bloqueado o no.
            final blockText =
                _isPartnerBlocked ? t.unblockProfile : t.blockProfile;

            return Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.transparent,
                    ),
                  ),
                  // El menú flotante en sí
                  Positioned(
                    right: 10, // 220 is the menu width (for alignment)
                    top: 70,
                    child: GestureDetector(
                      onTap: () {},
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 160,
                              maxWidth: 240,
                            ),
                            color: const Color.fromARGB(255, 114, 114, 114).withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      _notificationsEnabled = !_notificationsEnabled;
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      SvgPicture.asset(
                                        _notificationsEnabled
                                            ? 'assets/icono-campana-activada.svg'
                                            : 'assets/icono-campana-desactivada.svg',
                                        width: 24,
                                        height: 24,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _notificationsEnabled
                                            ? t.disableNotifications
                                            : t.enableNotifications,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(color: Colors.white54),
                                InkWell(
                                  onTap: () {
                                    final me = FirebaseAuth.instance.currentUser;
                                    if (me == null) return;
                                    ReportAndBlockUser.goToReportScreen(
                                      context,
                                      widget.chatPartnerId,
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      SvgPicture.asset(
                                        'assets/icono-reportar.svg',
                                        width: 24,
                                        height: 24,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        t.reportProfile,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(color: Colors.white54),
                                InkWell(
                                  onTap: () async {
                                    final me = FirebaseAuth.instance.currentUser;
                                    if (me == null) return;
                                    final oldValue = _isPartnerBlocked;
                                    setState(() {
                                      _isPartnerBlocked = !_isPartnerBlocked;
                                    });
                                    setDialogState(() {});
                                    try {
                                      await ReportAndBlockUser.toggleBlockUser(
                                        context,
                                        me.uid,
                                        widget.chatPartnerId,
                                        oldValue,
                                      );
                                    } catch (e) {
                                      setState(() {
                                        _isPartnerBlocked = oldValue;
                                      });
                                      setDialogState(() {});
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      SvgPicture.asset(
                                        'assets/icono-bloquear.svg',
                                        width: 24,
                                        height: 24,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          blockText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Lista principal de mensajes
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

        // Primero marcamos como 'delivered' los mensajes que aún no se han marcado
        _markAllMessagesAsDelivered(snapshot.data!.docs);

        // También marcamos en tiempo real como 'read' todo mensaje recibido
        _markAllMessagesAsReadInSnapshot(snapshot.data!.docs);

        // Filtramos mensajes solo de este chat
        var allDocs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['timestamp'] is! Timestamp) return false;
          final timestamp = data['timestamp'] as Timestamp;

          // 1) check si es entre currentUserId y widget.chatPartnerId
          final bool case1 = (data['senderId'] == currentUserId &&
              data['receiverId'] == widget.chatPartnerId);
          final bool case2 = (data['senderId'] == widget.chatPartnerId &&
              data['receiverId'] == currentUserId);

          if (!case1 && !case2) return false;

          // 2) Comparar con _myDeletedAt
          // Si _myDeletedAt != null => ignoro todo lo anterior a esa fecha
          if (_myDeletedAt != null) {
            if (timestamp.toDate().isBefore(_myDeletedAt!.toDate())) {
              return false;
            }
          }
          // El partner puede seguir viendo si no borró, eso se controla en SU chatScreen.

          return true;
        }).toList();

        // IDEA: Cargar solo últimos N (p. ej. 30) mensajes
        const int limit = 30;
        if (allDocs.length > limit) {
          allDocs = allDocs.sublist(allDocs.length - limit);
        }

        if (allDocs.isEmpty) {
          return const Center(
            child: Text(
              "No hay mensajes en este chat.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        // Insertamos separadores de fecha
        List<dynamic> chatItems = [];
        String? lastDate;

        for (var doc in allDocs) {
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

        // Al entrar, saltar al último mensaje sin animación
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 8, bottom: 8),
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

              // Swipe a la derecha => responder
              return GestureDetector(
                onHorizontalDragUpdate: (details) {
                  if (details.delta.dx > 15) {
                    startReplyingTo({
                      'docId': item.id,
                      'type': type ?? 'text',
                      'text': data['text'] ?? '',
                      'senderId': data['senderId'],
                      'senderName': isMe ? 'Tú' : widget.chatPartnerName,
                    });
                  }
                },
                onLongPress: () {
                  showMessageOptionsDialog(
                    context,
                    {
                      'docId': item.id,
                      'type': type ?? 'text',
                      'text': data['text'] ?? '',
                      'senderId': data['senderId'],
                      'senderName': isMe ? 'Tú' : widget.chatPartnerName,
                      'timestamp': data['timestamp'],
                    },
                    onDelete: () async {
                      final docId = item.id;
                      try {
                        await FirebaseFirestore.instance
                            .collection('messages')
                            .doc(docId)
                            .update({
                          'type': 'deleted',
                          'text': 'El mensaje original ha sido eliminado.',
                        });
                      } catch (e) {
                      }
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

  /// Marca como 'delivered' los mensajes que aún no se han marcado
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
    }
  }

  /// Pequeño widget para el separador de día
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

  /// Decide qué tipo de burbuja dibujar
  Widget _buildBubbleByType(Map<String, dynamic> data, bool isMe) {
    final String? type = data['type'] as String?;
    if (type == 'shared_plan') {
      return _buildSharedPlanBubble(data, isMe);
    } else if (type == 'image') {
      return _buildImageBubble(data, isMe);
    } else if (type == 'location') {
      return _buildLocationBubble(data, isMe);
    } else if (type == 'deleted') {
      return _buildDeletedBubble(data, isMe);
    } else {
      // Texto
      return _buildTextBubble(data, isMe);
    }
  }

  /// Pequeño separador de texto
  Widget _buildTextBubble(Map<String, dynamic> data, bool isMe) {
    DateTime messageTime = DateTime.now();
    if (data['timestamp'] is Timestamp) {
      messageTime = (data['timestamp'] as Timestamp).toDate();
    }
    bool delivered = data['delivered'] ?? false;
    bool isRead = data['isRead'] ?? false;
    final replyTo = data['replyTo'] as Map<String, dynamic>?;

    final bubbleColor = isMe
        ? const Color(0xFFF9E4D5)
        : const Color.fromARGB(255, 247, 237, 250);

    Widget bubbleContent = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
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
          if (replyTo != null) buildReplyContainer(replyTo),
          Text(
            data['text'] ?? '',
            style: const TextStyle(color: Colors.black, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
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
        ],
      ),
    );

    return _buildBubbleWithReaction(data, isMe, bubbleContent);
  }

  /// Mensaje eliminado
  Widget _buildDeletedBubble(Map<String, dynamic> data, bool isMe) {
    DateTime messageTime = DateTime.now();
    if (data['timestamp'] is Timestamp) {
      messageTime = (data['timestamp'] as Timestamp).toDate();
    }
    bool delivered = data['delivered'] ?? false;
    bool isRead = data['isRead'] ?? false;

    final bubbleColor =
        isMe ? const Color(0xFFF9E4D5) : const Color(0xFFEBD6F2);

    Widget bubbleContent = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
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
          Row(
            children: [
              SvgPicture.asset(
                'assets/icono-eliminar.svg',
                width: 20,
                height: 20,
                color: Colors.grey[700],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data['text'] ?? 'El mensaje original ha sido eliminado',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
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
        ],
      ),
    );

    return _buildBubbleWithReaction(data, isMe, bubbleContent);
  }

  /// Apila la burbuja + la reacción (si existe)
  Widget _buildBubbleWithReaction(
      Map<String, dynamic> data, bool isMe, Widget bubble) {
    final reaction = data['reaction'];
    if (reaction == null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: bubble,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            bubble,
            Positioned(
              bottom: -12,
              right: isMe ? 30 : null,
              left: isMe ? null : 30,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.4),
                      blurRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  reaction,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
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
    final replyTo = data['replyTo'] as Map<String, dynamic>?;

    final bubble = Align(
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
                          return const Center(
                              child: CircularProgressIndicator());
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
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12),
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

    return _buildBubbleWithReaction(data, isMe, bubble);
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
    final replyTo = data['replyTo'] as Map<String, dynamic>?;

    final bubble = Align(
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

    return _buildBubbleWithReaction(data, isMe, bubble);
  }

  /// Para obtener el tamaño de la imagen (así ajustamos la burbuja)
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
    final replyTo = data['replyTo'] as Map<String, dynamic>?;

    final bubbleColor =
        isMe ? const Color(0xFFF9E4D5) : const Color(0xFFEBD6F2);

    final bubble = Align(
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
            final double maxWidth = MediaQuery.of(context).size.width * 0.65;

            double displayWidth = imageSize.width;
            double displayHeight = imageSize.height;

            // Ajuste de tamaño si excede el maxWidth
            if (displayWidth > maxWidth) {
              final double ratio = maxWidth / displayWidth;
              displayWidth = maxWidth;
              displayHeight = displayHeight * ratio;
            }

            return Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (replyTo != null) buildReplyContainer(replyTo),
                GestureDetector(
                  onTap: () {
                    // Abrimos imagen a pantalla completa
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
                            color: Colors.black54, fontSize: 12),
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

    return _buildBubbleWithReaction(data, isMe, bubble);
  }

  /// Abre los detalles del plan
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
    }
  }

  /// Incluimos 'uid' en cada participante
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

  /// Input inferior: escribir y enviar
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
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).writeMessage,
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
        return SafeArea(
          child: Container(
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
                  label: AppLocalizations.of(context).shareLocation,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _handleSendLocationWithPicker();
                  },
                ),
                _buildFloatingOption(
                  svgPath: 'assets/plan-sin-fondo.png',
                  label: AppLocalizations.of(context).sharePlan,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPlanSelection();
                  },
                ),
                _buildFloatingOption(
                  svgPath: 'assets/icono-imagen.svg',
                  label: AppLocalizations.of(context).sharePhoto,
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleSelectImage();
                  },
                ),
              ],
            ),
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

  /// Enviar ubicación
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
          'replyTo': buildReplyMapForSending(),
        });
        cancelReply();
      }
    }
  }

  /// Selección de plan
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

      String planStartDateString = '';
      if (plan.startTimestamp != null) {
        planStartDateString =
            DateFormat('d MMM yyyy, HH:mm', 'es').format(plan.startTimestamp!);
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
        'replyTo': buildReplyMapForSending(),
      });
    }
    cancelReply();
  }

  /// Seleccionar imagen
  Future<void> _handleSelectImage() async {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.2),
      builder: (_) {
        final t = AppLocalizations.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library, color: Colors.blue),
                    title: Text(t.pickFromGallery),
                    onTap: () async {
                      Navigator.pop(context);
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (image != null) {
                        _uploadAndSendImage(image);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: Colors.blue),
                    title: Text(t.takePhoto),
                    onTap: () async {
                      Navigator.pop(context);
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.camera,
                      );
                      if (image != null) {
                        _uploadAndSendImage(image);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _uploadAndSendImage(XFile imageFile) async {
    try {
      if (await UserImagesManaging.checkExplicit(File(imageFile.path))) {
        await UserImagesManaging.showExplicitDialog(context);
        return;
      }
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
    }
  }

  /// Enviar mensaje de texto
  void _sendMessage() async {
    String messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    // Verificar si me han bloqueado
    final docId = '${widget.chatPartnerId}_$currentUserId';
    final blockedDoc = await FirebaseFirestore.instance
        .collection('blocked_users')
        .doc(docId)
        .get();

    if (blockedDoc.exists) {
      // Significa que tu chatPartnerId ha bloqueado a currentUserId
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La otra persona te ha bloqueado.")),
      );
      return; // no enviamos nada
    }

    // Si no está bloqueado, enviamos el mensaje
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
        'replyTo': buildReplyMapForSending(),
      });

      _messageController.clear();

      // Bajamos el scroll al final sin animación
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      });

      cancelReply();
    } catch (e) {
    }
  }
}
