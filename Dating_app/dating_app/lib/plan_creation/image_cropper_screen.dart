import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';

class ImageCropperScreen extends StatefulWidget {
  final Uint8List imageData;
  const ImageCropperScreen({Key? key, required this.imageData}) : super(key: key);

  @override
  _ImageCropperScreenState createState() => _ImageCropperScreenState();
}

class _ImageCropperScreenState extends State<ImageCropperScreen> {
  final CropController _cropController = CropController();
  bool _isCropping = false;

  Future<void> _performCrop() async {
    if (_isCropping) return;
    setState(() => _isCropping = true);
    _cropController.crop(); // O _cropController.cropCircle() si quieres recorte circular
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recortar imagen'),
        backgroundColor: Colors.black87,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Crop(
              controller: _cropController,
              image: widget.imageData,
              aspectRatio: 4 / 4,
              // En la 2.0.0, para extraer los bytes recortados, usa 'croppedImage'
              onCropped: (CropResult result) {
                setState(() => _isCropping = false);
                if (result is CropSuccess) {
                  // 'result.croppedImage' es Uint8List con la imagen recortada
                  Navigator.pop(context, result.croppedImage);
                } else {
                  // CropFailure u otro caso
                  Navigator.pop(context);
                }
              },

              // Fijamos el rectángulo inicial con un margen alrededor
              initialRectBuilder: InitialRectBuilder.withBuilder(
                (viewportRect, imageRect) {
                  return Rect.fromLTRB(
                    viewportRect.left + 24,
                    viewportRect.top + 32,
                    viewportRect.right - 24,
                    viewportRect.bottom - 32,
                  );
                },
              ),
              baseColor: Colors.blue.shade900,
              maskColor: Colors.white.withAlpha(100),
              radius: 20,

              // Usamos un widget personalizado para representar el punto en la esquina
              cornerDotBuilder: (dotSize, edgeAlignment) => const _CustomDot(
                size: 12.0,
                color: Colors.blue,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isCropping ? null : _performCrop,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
              ),
              child: _isCropping
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Confirmar recorte",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget personalizado para dibujar puntos en las esquinas
class _CustomDot extends StatelessWidget {
  final double size;
  final Color color;

  const _CustomDot({
    Key? key,
    this.size = 12.0,
    this.color = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
