import 'dart:ui'; // Para ImageFilter en el frosted glass
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // Para copiar texto al portapapeles
import 'package:flutter_svg/flutter_svg.dart';

/// Mixin que encapsula la funcionalidad de "responder un mensaje" en un chat.
/// Se puede incluir en tu State de la pantalla de chat para no duplicar código
/// y mantenerlo más ordenado.
mixin AnswerAMessageMixin<T extends StatefulWidget> on State<T> {
  /// Controla si estamos respondiendo algún mensaje.
  bool _isReplying = false;
  Map<String, dynamic>? _replyingTo;

  /// Llamar a este método para activar el modo de respuesta (por ejemplo,
  /// al hacer swipe o long press en un mensaje).
  /// [messageData] es la info del mensaje al que respondemos.
  void startReplyingTo(Map<String, dynamic> messageData) {
    setState(() {
      _isReplying = true;
      _replyingTo = messageData;
    });
  }

  /// Cancela el modo de respuesta.
  void cancelReply() {
    setState(() {
      _isReplying = false;
      _replyingTo = null;
    });
  }

  /// Devuelve `true` si estamos en modo de respuesta.
  bool get isReplying => _isReplying;

  /// Devuelve la información del mensaje al que respondemos.
  Map<String, dynamic>? get replyingTo => _replyingTo;

  /// Este método se puede usar en tu burbuja de mensaje para dibujar la cajita gris
  /// con el contenido del mensaje al que se está respondiendo.
  Widget buildReplyContainer(Map<String, dynamic> replyData) {
    final String replyType = replyData['type'] ?? 'text';
    // Texto de ejemplo, en caso de foto/ubicación/plan, etc.
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

  /// Widget para mostrar, encima del TextField, la vista previa de a qué mensaje
  /// estamos respondiendo. Esto se puede incluir en la parte inferior de tu ChatScreen
  /// si `isReplying` es true.
  Widget buildReplyPreview({
    VoidCallback? onCancelReply,
  }) {
    final String replyType = _replyingTo?['type'] ?? 'text';
    // Texto simplificado para mostrar en la previa.
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
      default:
        previewText = _replyingTo?['text'] ?? '';
        break;
    }

    return Container(
      width: double.infinity,
      color: Colors.grey[300],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onCancelReply ?? cancelReply,
            child: const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Icon(Icons.close, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              previewText,
              style: const TextStyle(color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Crea el objeto que guardamos en Firestore si estamos respondiendo a algo.
  Map<String, dynamic>? buildReplyMapForSending() {
    if (!isReplying || _replyingTo == null) return null;

    // Devuelve un mapa con la información que quieras guardar en Firestore.
    // Normalmente con docId, type y lo esencial para representarlo en la burbuja.
    return {
      'docId': _replyingTo!['docId'],
      'type': _replyingTo!['type'],
      'text': _replyingTo!['text'],
      'senderId': _replyingTo!['senderId'],
    };
  }

  // -------------------------------------------------------------------------
  // NUEVA SECCIÓN: al mantener pulsado un mensaje, mostramos un diálogo con
  // las 4 opciones: Reaccionar, Responder, Copiar, Eliminar.
  // -------------------------------------------------------------------------

  /// Llamar a esta función desde onLongPress en la burbuja para mostrar el diálogo.
  /// [messageData] es la info del mensaje; p.ej. para "copiar" y "eliminar".
  void showMessageOptionsDialog(
    BuildContext context,
    Map<String, dynamic> messageData, {
    VoidCallback? onReact,
    VoidCallback? onDelete,
  }) {
    // Opcional: podrías verificar aquí si el usuario es dueño del mensaje para eliminarlo, etc.
    // El "frosted glass" lo logramos con un Dialog -> BackdropFilter -> Container translúcido

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54, // Fondo oscuro semitransparente
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent, // Deja ver el blur
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: _buildFrostedDialogOptions(context, messageData,
              onReact: onReact,
              onDelete: onDelete),
        );
      },
    );
  }

  /// Construye el contenido "frosted" con las 4 opciones.  
  /// Puedes personalizar la posición para anclarlo debajo de la burbuja si deseas.
  Widget _buildFrostedDialogOptions(
    BuildContext context,
    Map<String, dynamic> messageData, {
    VoidCallback? onReact,
    VoidCallback? onDelete,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: Colors.white.withOpacity(0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reaccionar
              _buildOptionRow(
                context,
                iconPath: 'assets/icono-reaccionar.svg',
                label: 'Reaccionar',
                onTap: () {
                  Navigator.pop(context);
                  if (onReact != null) {
                    onReact();
                  } else {
                    // Aquí iría tu lógica de reacciones
                    debugPrint('El usuario reaccionó al mensaje');
                  }
                },
              ),
              const Divider(color: Colors.black, height: 1),
              // Responder
              _buildOptionRow(
                context,
                iconPath: 'assets/icono-responder.svg',
                label: 'Responder',
                onTap: () {
                  Navigator.pop(context);
                  startReplyingTo(messageData); // Activa el modo Responder
                },
              ),
              const Divider(color: Colors.black, height: 1),
              // Copiar
              _buildOptionRow(
                context,
                iconPath: 'assets/icono-copiar.svg',
                label: 'Copiar',
                onTap: () {
                  Navigator.pop(context);
                  final text = messageData['text'] ?? '';
                  if (text.toString().isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: text));
                    debugPrint('¡Mensaje copiado al portapapeles!');
                  }
                },
              ),
              const Divider(color: Colors.black, height: 1),
              // Eliminar
              _buildOptionRow(
                context,
                iconPath: 'assets/icono-eliminar.svg',
                label: 'Eliminar',
                onTap: () {
                  Navigator.pop(context);
                  if (onDelete != null) {
                    onDelete();
                  } else {
                    // Ejemplo de borrado de Firestore (si es tuyo o tienes permiso):
                    // final docId = messageData['docId'];
                    // if (docId != null) {
                    //   FirebaseFirestore.instance.collection('messages').doc(docId).delete();
                    //   debugPrint('Mensaje $docId eliminado');
                    // }
                    debugPrint('El usuario quiere eliminar el mensaje');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye una fila con ícono SVG y texto, ambos en color negro.
  /// [onTap] define la acción a realizar al pulsar la opción.
  Widget _buildOptionRow(
    BuildContext context, {
    required String iconPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white, // Fondo blanco para el botón
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
