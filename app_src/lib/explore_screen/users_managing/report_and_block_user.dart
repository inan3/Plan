import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Pantalla a pantalla completa para reportar a un usuario.
/// Se seleccionan hasta 6 motivos y un comentario opcional.
/// Al enviar, se guardan en la colección 'reports' de Firestore.
class ReportUserScreen extends StatefulWidget {
  final String reportedUserId;

  const ReportUserScreen({
    Key? key,
    required this.reportedUserId,
  }) : super(key: key);

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  final List<String> _reasons = [
    'Contenido inapropiado',
    'Suplantación de identidad',
    'Spam o publicitario',
    'Lenguaje o comportamiento abusivo',
    'Imágenes inapropiadas',
    'Otro (especificar)',
  ];

  // booleans para cada motivo
  final List<bool> _selected = [false, false, false, false, false, false];
  final TextEditingController _optionalCommentController =
      TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reportar Usuario"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Selecciona los motivos por los que deseas reportar este perfil",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _reasons.length,
              itemBuilder: (ctx, i) {
                return ListTile(
                  title: Text(_reasons[i]),
                  trailing: Checkbox(
                    value: _selected[i],
                    onChanged: (val) {
                      setState(() {
                        _selected[i] = val ?? false;
                      });
                    },
                  ),
                );
              },
            ),
          ),
          // Título sobre la caja de texto
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "¿Por qué quieres reportar este perfil? (opcional)",
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ),
          ),
          // Caja de texto
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _optionalCommentController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Describe brevemente...',
              ),
              maxLines: 3,
            ),
          ),
          const SizedBox(height: 16),
          // Botones
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Volver"),
              ),
              ElevatedButton(
                onPressed: _sendReport,
                child: const Text("Enviar"),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _sendReport() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Recolecta los motivos marcados
    final selectedReasons = <String>[];
    for (int i = 0; i < _reasons.length; i++) {
      if (_selected[i]) {
        selectedReasons.add(_reasons[i]);
      }
    }

    final comment = _optionalCommentController.text.trim();

    // Envía a Firestore en la colección "reports"
    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reportedUserId': widget.reportedUserId,
        'reporterUserId': currentUserId,
        'reasons': selectedReasons, // array con las razones
        'additionalComment': comment,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reporte enviado con éxito")),
      );

      Navigator.pop(context); // cierra la pantalla
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ocurrió un error al enviar reporte.")),
      );
    }
  }
}

/// Clase que centraliza la lógica para:
/// - Mostrar el popup (frosted glass) con las opciones Reportar / Bloquear.
/// - Bloquear/Desbloquear usuario.
/// - Navegar a la pantalla de Reporte.
class ReportAndBlockUser {
  /// Esta variable controla si el usuario está bloqueado o no.
  /// En un caso real, podrías obtener el estado desde tu base de datos
  /// en lugar de guardarlo en static local.
  static bool isBlocked = false;

  /// Muestra el popup con efecto frosted glass y opciones:
  /// - Reportar Perfil
  /// - Bloquear / Desbloquear
  static void showChatOptionsFrosted({
    required BuildContext context,
    required String currentUserId,
    required String chatPartnerId,
  }) {
    showDialog(
      context: context,
      barrierDismissible:
          false, // Lo controlamos manualmente con GestureDetector
      barrierColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Material(
          color: Colors.transparent, // Fondo transparente
          child: InkWell(
            // Si tocas fuera del contenedor, cierra el diálogo
            onTap: () => Navigator.pop(ctx),
            child: Stack(
              children: [
                // Alineamos la caja en la parte superior derecha.
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60, right: 10),
                    // Este GestureDetector detiene el evento de tap
                    // para que NO se propague y no se cierre el dialog
                    // cuando pulsas dentro del contenedor frosted
                    child: GestureDetector(
                      onTap: () {
                        // NO hacemos nada, simplemente evitamos que
                        // el onTap de InkWell (fuera) se dispare.
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            color: Colors.white.withOpacity(0.6),
                            width: 200,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Opción "Reportar"
                                InkWell(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    goToReportScreen(context, chatPartnerId);
                                  },
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 8),
                                      SvgPicture.asset(
                                        'assets/icono-reportar.svg',
                                        width: 24,
                                        height: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Reportar Perfil',
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(
                                  color: Colors.black54,
                                  height: 8,
                                ),
                                // Opción "Bloquear" / "Desbloquear"
                                InkWell(
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    await toggleBlockUser(
                                      context,
                                      currentUserId,
                                      chatPartnerId,
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 8),
                                      SvgPicture.asset(
                                        'assets/icono-bloquear.svg',
                                        width: 24,
                                        height: 24,
                                        color: isBlocked
                                            ? Colors.blue
                                            : Colors.red,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          isBlocked
                                              ? 'Desbloquear Perfil'
                                              : 'Bloquear Perfil',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 16,
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
              ],
            ),
          ),
        );
      },
    );
  }

  /// Navega a la pantalla de reporte
  static void goToReportScreen(BuildContext context, String reportedUserId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportUserScreen(
          reportedUserId: reportedUserId,
        ),
      ),
    );
  }

  /// Alterna entre bloquear y desbloquear usuario
  static Future<void> toggleBlockUser(
    BuildContext context,
    String currentUserId,
    String chatPartnerId,
  ) async {
    if (isBlocked) {
      // => Desbloquear
      await _unblockUser(currentUserId, chatPartnerId);
    } else {
      // => Bloquear
      await _blockUser(currentUserId, chatPartnerId);
    }

    // Actualizamos el estado local
    isBlocked = !isBlocked;

    // Mostramos popup confirmando acción
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isBlocked ? "Perfil Bloqueado" : "Perfil Desbloqueado"),
          content: Text(
            isBlocked
                ? "Este perfil ha sido bloqueado, ya no podrá interactuar contigo."
                : "Has desbloqueado a este usuario.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  /// Bloquea al usuario añadiéndolo a un array 'blockedUsers' en tu documento 'users'
  static Future<void> _blockUser(String currentUserId, String chatPartnerId) async {
  try {
    final docId = '${currentUserId}_$chatPartnerId'; 
    await FirebaseFirestore.instance
        .collection('blocked_users')
        .doc(docId)
        .set({
      'blockerId': currentUserId, // quién bloquea
      'blockedId': chatPartnerId, // quién es bloqueado
      'timestamp': FieldValue.serverTimestamp(),
    });

  } catch (e) {
  }
}

/// Desbloquea al usuario eliminando ese doc en 'blocked_users'
static Future<void> _unblockUser(String currentUserId, String chatPartnerId) async {
  try {
    final docId = '${currentUserId}_$chatPartnerId';
    await FirebaseFirestore.instance
        .collection('blocked_users')
        .doc(docId)
        .delete();

  } catch (e) {
  }
}
}
