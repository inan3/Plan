import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:ui' as ui;

// Asegúrate de importar el diálogo de detalles (FrostedPlanDialog)
import '../users_managing/user_info_check.dart'; // O la ruta correspondiente donde se encuentre

// Importa tu modelo de plan
import '../../models/plan_model.dart';

class PlansInMapScreen {
  /// Carga todos los documentos de "plans", obtiene la foto del usuario creador
  /// y genera un marcador personalizado con callback en onTap para mostrar los detalles.
  /// 
  /// El parámetro opcional [filters] permite filtrar los planes según:
  /// - 'planPredeterminado': cadena exacta (ignora mayúsculas) que debe coincidir con el campo 'type'
  /// - 'planBusqueda': subcadena que debe estar contenida en el campo 'type'
  Future<Set<Marker>> loadPlansMarkers(BuildContext context, {Map<String, dynamic>? filters}) async {
    final QuerySnapshot plansSnapshot =
        await FirebaseFirestore.instance.collection('plans').get();

    final Set<Marker> markers = {};

    for (var planDoc in plansSnapshot.docs) {
      final data = planDoc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      // Datos mínimos necesarios del plan
      final double? lat = data['latitude']?.toDouble();
      final double? lng = data['longitude']?.toDouble();
      final String? planType = data['type'] as String?;
      final String? userId = data['createdBy'] as String?;

      if (lat == null || lng == null || planType == null || userId == null) {
        continue;
      }

      // Aplica los filtros si existen
      if (filters != null) {
        // Si se ha seleccionado un plan predeterminado, se compara de forma exacta
        if (filters['planPredeterminado'] != null && filters['planPredeterminado'].toString().isNotEmpty) {
          if (planType.toLowerCase() != filters['planPredeterminado'].toString().toLowerCase()) {
            continue;
          }
        } 
        // Si no se seleccionó un plan predeterminado, se puede usar el texto de búsqueda
        else if (filters['planBusqueda'] != null && filters['planBusqueda'].toString().isNotEmpty) {
          if (!planType.toLowerCase().contains(filters['planBusqueda'].toString().toLowerCase())) {
            continue;
          }
        }
      }

      // Obtiene la URL de la foto de perfil del usuario
      final String? userPhotoUrl = await _getUserProfilePhoto(userId);
      if (userPhotoUrl == null) continue;

      final position = LatLng(lat, lng);

      // Construye el marcador personalizado
      final BitmapDescriptor customMarker =
          await _buildPlanMarker(userPhotoUrl, planType);

      // Calcular el anchor dinámicamente usando los mismos parámetros que en _buildPlanMarker:
      const double markerMinWidth = 120;
      const double padding = 4.0;
      const double fontSize = 20;
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: planType,
          style: const TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout(maxWidth: markerMinWidth - 2 * padding);
      final double textContainerHeight = textPainter.height + 2 * padding;
      const double avatarAreaHeight = 110;
      final double markerHeight = textContainerHeight + avatarAreaHeight;
      const double circleRadius = 40;
      final double yTip = textContainerHeight + (avatarAreaHeight / 2) + circleRadius;
      final double anchorY = yTip / markerHeight;

      // IMPORTANTE: Se establece el anclaje calculado para que la punta del marcador (canvas)
      // coincida exactamente con la ubicación del plan en el mapa.
      markers.add(
        Marker(
          markerId: MarkerId(planDoc.id),
          position: position,
          icon: customMarker,
          anchor: Offset(0.5, anchorY),
          onTap: () {
            showGeneralDialog(
              context: context,
              barrierDismissible: true,
              barrierLabel: 'Cerrar',
              barrierColor: Colors.black.withOpacity(0.4),
              transitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (context, animation, secondaryAnimation) {
                return SafeArea(
                  child: Align(
                    alignment: Alignment.center,
                    child: Material(
                      color: Colors.transparent,
                      child: FrostedPlanDialog(
                        plan: PlanModel.fromMap(data),
                        fetchParticipants: _fetchPlanParticipants,
                      ),
                    ),
                  ),
                );
              },
              transitionBuilder: (context, anim1, anim2, child) {
                return FadeTransition(
                  opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
                  child: child,
                );
              },
            );
          },
        ),
      );
    }

    return markers;
  }

  /// Función auxiliar para obtener los participantes del plan.
  Future<List<Map<String, dynamic>>> _fetchPlanParticipants(PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];

    final planDoc = await FirebaseFirestore.instance.collection('plans').doc(plan.id).get();
    if (planDoc.exists) {
      final planData = planDoc.data() as Map<String, dynamic>;
      final creatorId = planData['createdBy'];
      // Agrega el creador
      if (creatorId != null) {
        final creatorDoc = await FirebaseFirestore.instance.collection('users').doc(creatorId).get();
        if (creatorDoc.exists) {
          final cdata = creatorDoc.data() as Map<String, dynamic>;
          participants.add({
            'isCreator': true,
            'photoUrl': cdata['photoUrl'] ?? '',
            'name': cdata['name'] ?? 'Usuario',
            'age': (cdata['age'] ?? '').toString(),
          });
        }
      }
      // Agrega participantes (se asume que en Firestore existe un array 'participants')
      final rawParticipants = planData['participants'];
      if (rawParticipants is List) {
        for (final uid in rawParticipants) {
          if (uid is String && uid != creatorId) {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
            if (userDoc.exists) {
              final uData = userDoc.data() as Map<String, dynamic>;
              participants.add({
                'isCreator': false,
                'photoUrl': uData['photoUrl'] ?? '',
                'name': uData['name'] ?? 'Usuario',
                'age': (uData['age'] ?? '').toString(),
              });
            }
          }
        }
      }
    }

    return participants;
  }

  /// Busca en la colección "users" el documento con [userId] y devuelve la URL de su perfil.
  Future<String?> _getUserProfilePhoto(String userId) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (!userDoc.exists) return null;
    final userData = userDoc.data() as Map<String, dynamic>?;
    if (userData == null) return null;
    return userData['photoUrl'] as String?;
  }

  /// Descarga la imagen desde [imageUrl] y devuelve los bytes.
  Future<Uint8List> _downloadImageAsBytes(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception("No se pudo descargar la imagen: $imageUrl");
    }
  }

  /// Construye un marcador personalizado:
  /// - Dibuja el tipo de plan en la parte superior con un fondo dinámico (se adapta a la cantidad de líneas).
  /// - Pinta el avatar en una región circular.
  /// - Dibuja un borde verde alrededor del avatar.
  Future<BitmapDescriptor> _buildPlanMarker(String photoUrl, String planType) async {
    try {
      // 1) Descarga y procesa la imagen del avatar
      final Uint8List imageBytes = await _downloadImageAsBytes(photoUrl);
      final ui.Codec codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: 90,
        targetHeight: 90,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image avatarImage = frame.image;

      // 2) Define parámetros para el dibujo
      const double markerMinWidth = 120;
      const double padding = 4.0;
      const double fontSize = 20;
      const double textTopMargin = 10;
      
      // Se prepara el TextPainter para el tipo de plan
      final textPainter = TextPainter(
        text: TextSpan(
          text: planType,
          style: const TextStyle(
            fontSize: fontSize,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      
      // Se define un ancho máximo para el contenedor de texto (en este caso el mínimo del marcador)
      textPainter.layout(maxWidth: markerMinWidth - 2 * padding);
      
      // Calcula la altura del contenedor del texto (incluyendo padding)
      final double textContainerHeight = textPainter.height + 2 * padding;
      
      // Define la altura total del marcador sumando el área reservada para el avatar
      // Aquí se reserva 110 puntos para el área del avatar (puedes ajustar este valor según necesites)
      const double avatarAreaHeight = 110;
      final double markerHeight = textContainerHeight + avatarAreaHeight;
      final double markerWidth = markerMinWidth;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // 3) Dibuja el contenedor del texto en la parte superior
      final double textX = (markerWidth - textPainter.width) / 2;
      final double textY = textTopMargin;
      final Rect bgRect = Rect.fromLTWH(
        textX - padding,
        textY - padding,
        textPainter.width + 2 * padding,
        textPainter.height + 2 * padding,
      );
      final RRect bgRRect = RRect.fromRectAndRadius(bgRect, const Radius.circular(8));
      final Paint bgPaint = Paint()..color = Colors.white;
      canvas.drawRRect(bgRRect, bgPaint);
      final Paint textBorderPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRRect(bgRRect, textBorderPaint);
      textPainter.paint(canvas, Offset(textX, textY));

      // 4) Dibuja el avatar debajo del contenedor de texto
      final double circleCenterX = markerWidth / 2;
      final double circleCenterY = textContainerHeight + avatarAreaHeight / 2;
      const double circleRadius = 40;
      final Offset center = Offset(circleCenterX, circleCenterY);

      // 5) Recorta el canvas a la región circular y pinta el avatar centrado
      final Path clipPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: circleRadius));
      canvas.save();
      canvas.clipPath(clipPath);
      final Rect imageRect = Rect.fromCenter(
        center: center,
        width: circleRadius * 2,
        height: circleRadius * 2,
      );
      paintImage(
        canvas: canvas,
        rect: imageRect,
        image: avatarImage,
        fit: BoxFit.cover,
      );
      canvas.restore();

      // 6) Dibuja un borde verde alrededor del avatar
      final Paint avatarBorderPaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, circleRadius, avatarBorderPaint);

      // 7) Convierte el dibujo en una imagen PNG
      final ui.Picture picture = recorder.endRecording();
      final ui.Image markerImage = await picture.toImage(
        markerWidth.toInt(),
        markerHeight.toInt(),
      );
      final ByteData? byteData = await markerImage.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // 8) Retorna el BitmapDescriptor creado a partir de los bytes PNG
      return BitmapDescriptor.fromBytes(pngBytes);
    } catch (e) {
      print("Error creando marcador personalizado: $e");
      return BitmapDescriptor.defaultMarker;
    }
  }
}
