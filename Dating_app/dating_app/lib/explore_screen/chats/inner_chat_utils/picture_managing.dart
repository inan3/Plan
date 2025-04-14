import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:screen_protector/screen_protector.dart';

/// Función para navegar a la vista de la imagen completa.
void openFullImage(BuildContext context, String imageUrl) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FullImageViewerScreen(imageUrl: imageUrl),
    ),
  );
}

class FullImageViewerScreen extends StatefulWidget {
  final String imageUrl;

  const FullImageViewerScreen({Key? key, required this.imageUrl})
      : super(key: key);

  @override
  State<FullImageViewerScreen> createState() => _FullImageViewerScreenState();
}

class _FullImageViewerScreenState extends State<FullImageViewerScreen> {
  bool _showPrivacyMessage = false;
  StreamSubscription? _screenRecordSubscription;

  @override
  void initState() {
    super.initState();
    _blockScreenshots();
  }

  @override
  void dispose() {
    _unblockScreenshots();
    super.dispose();
  }

  /// Bloquea capturas y agrega listeners (Android + iOS).
  Future<void> _blockScreenshots() async {
    try {
      // Evita las capturas tanto en Android como en iOS
      await ScreenProtector.preventScreenshotOn();

      // Agrega listeners para detectar capturas y screen recording (solo iOS).
      ScreenProtector.addListener(
        _onScreenshotTaken,
        _onScreenRecord,
      );
    } catch (e) {
      debugPrint("Error al bloquear capturas: $e");
    }
  }

  /// Restaura la posibilidad de capturas
  Future<void> _unblockScreenshots() async {
    try {
      await ScreenProtector.preventScreenshotOff();
      ScreenProtector.removeListener();
      _screenRecordSubscription?.cancel();
    } catch (e) {
      debugPrint("Error al desbloquear capturas: $e");
    }
  }

  /// Callback que se dispara en iOS cuando se toma una captura.
  /// En Android NO existe el callback, solo se bloquea (FLAG_SECURE).
  void _onScreenshotTaken() {
    debugPrint("Captura detectada en iOS!");
    _showPrivacyWarning();
  }

  /// Callback que se dispara en iOS cuando inicia/termina una grabación de pantalla.
  /// [isRecording] es true si se está grabando, false si terminó.
  void _onScreenRecord(bool isRecording) {
    debugPrint("Screen recording: $isRecording");
    // Si quisieras mostrar el mismo mensaje cuando empieza a grabar, podrías:
    // if (isRecording) _showPrivacyWarning();
  }

  /// Muestra el mensaje de privacidad unos segundos
  void _showPrivacyWarning() {
    setState(() {
      _showPrivacyMessage = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showPrivacyMessage = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Imagen con zoom
          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context), // Cierra al hacer tap
              child: InteractiveViewer(
                child: Image.network(widget.imageUrl),
              ),
            ),
          ),

          // Botón "Volver atrás" en esquina superior derecha
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Mensaje de privacidad si _showPrivacyMessage es true
          if (_showPrivacyMessage)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.2,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Icono candado (usando SVG)
                    SvgPicture.asset(
                      'assets/icono-candado.svg',
                      width: 40,
                      height: 40,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Por cuestiones de seguridad de los usuarios, no se pueden "
                      "hacer capturas a las imágenes",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
