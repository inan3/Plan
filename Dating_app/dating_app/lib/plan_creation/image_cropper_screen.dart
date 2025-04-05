import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

class ImageCropperScreen extends StatefulWidget {
  final Uint8List imageData;
  const ImageCropperScreen({Key? key, required this.imageData}) : super(key: key);

  @override
  _ImageCropperScreenState createState() => _ImageCropperScreenState();
}

class _ImageCropperScreenState extends State<ImageCropperScreen> {
  File? _tempImageFile;

  @override
  void initState() {
    super.initState();
    _createTempFile();
  }

  /// Crea un archivo temporal a partir de los bytes recibidos.
  Future<void> _createTempFile() async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(widget.imageData);
    setState(() {
      _tempImageFile = file;
    });
  }

  /// Invoca ImageCropper para recortar la imagen en formato cuadrado (1:1).
  Future<void> _cropImage() async {
    if (_tempImageFile == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: _tempImageFile!.path,
      // Fijamos el recorte en 1:1
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Ajustar a la cuadrícula',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: Colors.deepOrange,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Recortar Imagen',
          aspectRatioLockEnabled: true,
        ),
        WebUiSettings(
          context: context,
        ),
      ],
    );

    if (croppedFile != null) {
      final croppedBytes = await File(croppedFile.path).readAsBytes();
      Navigator.pop(context, croppedBytes);
    } else {
      // Si se cancela el recorte, regresa sin datos.
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tempImageFile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recortar Imagen')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recortar Imagen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _cropImage,
          )
        ],
      ),
      body: Center(
        child: Image.file(_tempImageFile!),
      ),
    );
  }
}
