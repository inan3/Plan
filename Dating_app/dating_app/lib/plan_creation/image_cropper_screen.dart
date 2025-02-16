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
    _cropController.crop();
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
              aspectRatio: 4 / 3,
              onCropped: (CropResult result) {
                setState(() => _isCropping = false);
                // Usamos addPostFrameCallback para evitar llamar a Navigator.pop
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Verificamos el tipo del resultado mediante if/else
                  if (result is CropSuccess) {
                    // En caso de éxito, se obtiene la imagen recortada en result.image
                    Navigator.pop(context, result.image);
                  } else if (result is CropFailure) {
                    // En caso de error, se puede manejar el error (aquí simplemente volvemos)
                    Navigator.pop(context);
                  } else {
                    Navigator.pop(context);
                  }
                });
              },
              initialRectBuilder: InitialRectBuilder.withBuilder((viewportRect, imageRect) {
                return Rect.fromLTRB(
                  viewportRect.left + 24,
                  viewportRect.top + 32,
                  viewportRect.right - 24,
                  viewportRect.bottom - 32,
                );
              }),
              baseColor: Colors.blue.shade900,
              maskColor: Colors.white.withAlpha(100),
              overlayBuilder: (context, rect) {
                return CustomPaint(painter: MyPainter(rect));
              },
              progressIndicator: const CircularProgressIndicator(),
              radius: 20,
              // La firma correcta para onMoved es: (Rect viewportRect, Rect imageRect)
              onMoved: (viewportRect, imageRect) {
                // Aquí puedes hacer algo con los rectángulos actuales
              },
              onImageMoved: (newImageRect) {
                // Si lo necesitas, implementa algo aquí
              },
              onStatusChanged: (status) {
                // Puedes reaccionar ante el cambio de estado si lo deseas
              },
              willUpdateScale: (newScale) {
                // Si devolvemos false, se cancela el escalado
                return newScale < 5;
              },
              cornerDotBuilder: (size, edgeAlignment) =>
                  const DotControl(color: Colors.blue),
              clipBehavior: Clip.none,
              interactive: true,
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

class MyPainter extends CustomPainter {
  final Rect rect;
  MyPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant MyPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}
