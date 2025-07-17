import 'dart:ui'; // Para ImageFilter en el frosted glass
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // Para copiar texto al portapapeles
import 'package:flutter_svg/flutter_svg.dart';

/// Mixin que encapsula la funcionalidad de "responder un mensaje" en un chat.
mixin AnswerAMessageMixin<T extends StatefulWidget> on State<T> {
  bool _isReplying = false;
  Map<String, dynamic>? _replyingTo;

  void startReplyingTo(Map<String, dynamic> messageData) {
    setState(() {
      _isReplying = true;
      _replyingTo = messageData;
    });
  }

  void cancelReply() {
    setState(() {
      _isReplying = false;
      _replyingTo = null;
    });
  }

  bool get isReplying => _isReplying;
  Map<String, dynamic>? get replyingTo => _replyingTo;

  /// Muestra dentro de la burbuja el mensaje al que se responde
  Widget buildReplyContainer(Map<String, dynamic> replyData) {
    final String replyType = replyData['type'] ?? 'text';
    String replyText;
    switch (replyType) {
      case 'image':
        replyText = '[Foto]';
        break;
      case 'location':
        replyText = '[Ubicación]';
        break;
      case 'shared_plan':
        replyText = '[Plan compartido]';
        break;
      case 'deleted':
        replyText = '[Mensaje eliminado]';
        break;
      default:
        replyText = replyData['text'] ?? '';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        replyText,
        style: const TextStyle(color: Colors.black54, fontSize: 14),
      ),
    );
  }

  /// Muestra, sobre el TextField, la vista previa del mensaje a responder
  Widget buildReplyPreview({
    VoidCallback? onCancelReply,
  }) {
    final String replyType = _replyingTo?['type'] ?? 'text';
    // Quien envió el mensaje (si es "Tú" o el otro)
    final String senderName = _replyingTo?['senderName'] ?? '';

    String previewText;
    switch (replyType) {
      case 'image':
        previewText = '[Foto]';
        break;
      case 'location':
        previewText = '[Ubicación]';
        break;
      case 'shared_plan':
        previewText = '[Plan compartido]';
        break;
      case 'deleted':
        previewText = '[Mensaje eliminado]';
        break;
      default:
        previewText = _replyingTo?['text'] ?? '';
        break;
    }

    return Container(
      width: double.infinity,
      color: Colors.grey[300],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botón para cancelar la respuesta
          GestureDetector(
            onTap: onCancelReply ?? cancelReply,
            child: const Padding(
              padding: EdgeInsets.only(right: 8.0, top: 2.0),
              child: Icon(Icons.close, color: Colors.black54),
            ),
          ),
          // Mostramos quién lo envió + el contenido del mensaje
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quién envió el mensaje
                Text(
                  senderName,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                // Texto del mensaje (o su "tipo")
                Text(
                  previewText,
                  style: const TextStyle(color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Construye un objeto con la info del mensaje al que respondemos
  Map<String, dynamic>? buildReplyMapForSending() {
    if (!isReplying || _replyingTo == null) return null;
    return {
      'docId': _replyingTo!['docId'],
      'type': _replyingTo!['type'],
      'text': _replyingTo!['text'],
      'senderId': _replyingTo!['senderId'],
      'senderName': _replyingTo!['senderName'],
    };
  }

  // -------------------------------------------------------------------------
  // Pop-up iOS:
  //   - 4 emojis directos + ícono “+” (ahora un SVG) para más,
  //   - Bocadillo con hora y nombre en medio,
  //   - Botones Responder, Copiar y Eliminar abajo (todos con frosted glass).
  // -------------------------------------------------------------------------
  void showMessageOptionsDialog(
    BuildContext context,
    Map<String, dynamic> messageData, {
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    bool canEdit = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          // Reducimos el ancho un poco más, por ejemplo 300px
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 0),
          child: _buildFrostedDialogOptions(
            context,
            messageData,
            canEdit: canEdit,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        );
      },
    );
  }

  Widget _buildFrostedDialogOptions(
    BuildContext context,
    Map<String, dynamic> messageData, {
    bool canEdit = false,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          // Este contenedor es el fondo frosted que aplica a TODO:
          color: Colors.white.withOpacity(0.6),
          // Limitamos un poco el ancho máximo, por si la pantalla es muy grande:
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),

              // Fila de emojis (4 + +)
              _buildEmojiReactionRow(messageData),
              const SizedBox(height: 8),

              // Bocadillo para ver el mensaje con su hora y nombre
              _buildMessageBubbleForDialog(messageData),

              if (canEdit) ...[
                Divider(color: Colors.black.withOpacity(0.4), height: 1),

                // Botón "Editar"
                _buildOptionRow(
                  iconPath: 'assets/icono-escribir.svg',
                  label: 'Editar',
                  onTap: () {
                    Navigator.pop(context);
                    if (onEdit != null) onEdit();
                  },
                ),
              ],
              if (canEdit)
                Divider(color: Colors.black.withOpacity(0.4), height: 1),

              // Botón "Responder"
              _buildOptionRow(
                iconPath: 'assets/icono-responder.svg',
                label: 'Responder',
                onTap: () {
                  Navigator.pop(context);
                  startReplyingTo(messageData);
                },
              ),
              Divider(color: Colors.black.withOpacity(0.4), height: 1),

              // Botón "Copiar"
              _buildOptionRow(
                iconPath: 'assets/icono-copiar.svg',
                label: 'Copiar',
                onTap: () {
                  Navigator.pop(context);
                  final text = messageData['text'] ?? '';
                  if (text.toString().isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: text));
                  }
                },
              ),
              Divider(color: Colors.black.withOpacity(0.4), height: 1),

              // Botón "Eliminar"
              _buildOptionRow(
                iconPath: 'assets/icono-eliminar.svg',
                label: 'Eliminar',
                onTap: () {
                  Navigator.pop(context);
                  if (onDelete != null) {
                    onDelete();
                  } else {
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Fila de emojis (4 principales + botón + para abrir la cuadrícula).
  Widget _buildEmojiReactionRow(Map<String, dynamic> messageData) {
    final docId = messageData['docId']; // ID del mensaje en Firestore

    // Emojis principales
    final mainReactions = ['👍', '❤️', '😂', '😮'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Los 4 emojis principales
        ...mainReactions.map((emoji) {
          return GestureDetector(
            onTap: () async {
              if (docId != null) {
                await FirebaseFirestore.instance
                    .collection('messages')
                    .doc(docId)
                    .update({'reaction': emoji});
              }
              Navigator.pop(context); // Cierra el diálogo principal
            },
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
          );
        }).toList(),

        // El botón "+" -> en lugar de "➕", usamos un SVG con fondo circular blanco
        GestureDetector(
          onTap: () {
            _showMoreReactions(context, docId);
          },
          child: Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(6),
            child: SvgPicture.asset(
              'assets/anadir.svg',
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  /// Muestra un popup con la matriz de 5×5 emojis (50 en total) desplazable.
  /// Al seleccionar un emoji, actualiza Firestore y cierra todas las ventanas.
  void _showMoreReactions(BuildContext context, String? docId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          // También reducimos el ancho en este popup
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 0),
          child: _buildFrostedEmojiMatrix(context, docId),
        );
      },
    );
  }

  Widget _buildFrostedEmojiMatrix(BuildContext context, String? docId) {
    final List<String> frequentEmojis = [
      '😀','😃','😄','😁','😆','😅','😂','🤣','😊','😇',
      '🙂','🙃','😉','😌','😍','🥰','😘','😗','😙','😚',
      '😋','😛','😝','😜','🤪','🤨','🧐','🤓','😎','🤩',
      '🥳','😏','😒','🙄','😬','🤥','😔','😪','😴','😷',
      '🤒','🤕','🤢','🤮','🤧','😵','🤯','🥴','😭','😢',
    ];

    // GridView con 5 columnas, dentro de un SingleChildScrollView
    final grid = GridView.builder(
      shrinkWrap: true,
      itemCount: frequentEmojis.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5, // 5 emojis por fila
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final emoji = frequentEmojis[index];
        return GestureDetector(
          onTap: () async {
            if (docId != null) {
              await FirebaseFirestore.instance
                  .collection('messages')
                  .doc(docId)
                  .update({'reaction': emoji});
            }
            // Cierra TODAS las ventanas (la del grid y la original)
            if (Navigator.canPop(context)) Navigator.pop(context);
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        );
      },
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: Colors.white.withOpacity(0.6),
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 300),
          child: SingleChildScrollView(child: grid),
        ),
      ),
    );
  }

  /// "Burbuja" dentro del pop-up para mostrar quién lo envía, texto y hora
  Widget _buildMessageBubbleForDialog(Map<String, dynamic> messageData) {
    final senderName = messageData['senderName'] ?? 'Remitente';
    final text = messageData['text'] ?? 'Sin texto';
    final timestamp = messageData['timestamp'];
    String timeString = '00:00';

    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      timeString = DateFormat('HH:mm').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,  // Un poco más claro para simular un "bocadillo"
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.black87, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                timeString,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Botón con ícono y texto (Responder, Copiar, Eliminar)
  Widget _buildOptionRow({
    required String iconPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SvgPicture.asset(
              iconPath,
              width: 24,
              height: 24,
              color: Colors.black,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(color: Colors.black, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
