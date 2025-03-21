import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../users_managing/frosted_plan_dialog_state.dart';
import '../../models/plan_model.dart';

class PlansInMapScreen {
  /// Para llevar registro de qué usuarios tienen al menos un plan activo
  final Set<String> _userIdsWithActivePlan = {};

  /// Carga todos los documentos de "plans" y genera un marcador personalizado
  /// para planes vigentes (special_plan == 0 y finish_timestamp > ahora).
  Future<Set<Marker>> loadPlansMarkers(
    BuildContext context, {
    Map<String, dynamic>? filters,
  }) async {
    // 1) Consulta todos los "plans" en la colección
    final QuerySnapshot plansSnapshot =
        await FirebaseFirestore.instance.collection('plans').get();

    final Set<Marker> markers = {};
    final now = DateTime.now(); // Para comparar con finish_timestamp

    // 2) Itera cada documento de la colección "plans"
    for (var planDoc in plansSnapshot.docs) {
      final data = planDoc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      // 2.1) Verifica si es un plan especial (special_plan != 0) => NO se muestra
      final int specialPlan = data['special_plan'] ?? 0;
      if (specialPlan != 0) {
        continue;
      }

      // 2.2) Verifica si el plan ya caducó (finish_timestamp <= ahora) => NO se muestra
      final Timestamp? finishTs = data['finish_timestamp'] as Timestamp?;
      if (finishTs == null) {
        // Si no trae finish_timestamp, asumimos que no procede mostrarlo
        continue;
      }
      final DateTime finishDate = finishTs.toDate();
      if (!finishDate.isAfter(now)) {
        // Si finishDate NO es posterior a now, está caducado
        continue;
      }

      // 2.3) Verifica campos esenciales (lat, lng, type, createdBy)
      final double? lat = data['latitude']?.toDouble();
      final double? lng = data['longitude']?.toDouble();
      final String? planType = data['type'] as String?;
      final String? userId = data['createdBy'] as String?;
      if (lat == null || lng == null || planType == null || userId == null) {
        continue; // Falta información esencial
      }

      // 2.4) Aplica filtros opcionales (planPredeterminado, planBusqueda)
      if (filters != null) {
        // Filtro exacto, p.ej. "planPredeterminado": "Deportes"
        if (filters['planPredeterminado'] != null &&
            filters['planPredeterminado'].toString().isNotEmpty) {
          if (planType.toLowerCase() !=
              filters['planPredeterminado'].toString().toLowerCase()) {
            continue;
          }
        }
        // Filtro de búsqueda parcial, p.ej. "planBusqueda": "fútbol"
        else if (filters['planBusqueda'] != null &&
            filters['planBusqueda'].toString().isNotEmpty) {
          if (!planType.toLowerCase().contains(
                filters['planBusqueda'].toString().toLowerCase(),
              )) {
            continue;
          }
        }
      }

      // 2.5) Obten la foto de perfil del creador, si existe
      final String? userPhotoUrl = await _getUserProfilePhoto(userId);
      if (userPhotoUrl == null) continue;

      // 2.6) Construye el marcador (BitmapDescriptor personalizado)
      final position = LatLng(lat, lng);
      final BitmapDescriptor customMarker = await _buildPlanMarker(
        userPhotoUrl,
        planType,
        showText: true,
      );

      // 2.7) Guardamos este userId en _userIdsWithActivePlan, pues tiene un plan activo
      _userIdsWithActivePlan.add(userId);

      // 2.8) Agrega el Marker al Set, con su callback onTap para mostrar detalles (FrostedPlanDialog)
      markers.add(
        Marker(
          markerId: MarkerId(planDoc.id),
          position: position,
          icon: customMarker,
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

    // 3) Retorna el conjunto de marcadores (solo planes activos)
    return markers;
  }

  /// Carga los usuarios "sin plan activo":
  /// Es decir, todos los usuarios que NO estén en [_userIdsWithActivePlan].
  /// De esta manera, si alguien tiene planes especiales o caducados, igual
  /// se mostrará como "sin plan activo" en el mapa.
  Future<Set<Marker>> loadUsersWithoutPlansMarkers(
    BuildContext context, {
    Map<String, dynamic>? filters,
  }) async {
    final usersCollection = FirebaseFirestore.instance.collection('users');

    // 1) Obtiene todos los usuarios
    final usersSnapshot = await usersCollection.get();
    final Set<Marker> userMarkers = {};

    for (var userDoc in usersSnapshot.docs) {
      final data = userDoc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final String userId = data['uid'] ?? '';
      if (userId.isEmpty) continue;

      // Si el usuario ya tiene un plan activo, lo excluimos (no marcamos "sin plan")
      if (_userIdsWithActivePlan.contains(userId)) {
        continue;
      }

      // Consigue lat/lng
      final double? lat = data['latitude']?.toDouble();
      final double? lng = data['longitude']?.toDouble();
      if (lat == null || lng == null) {
        continue;
      }

      final position = LatLng(lat, lng);

      // Foto de perfil (opcional)
      final String? userPhotoUrl = data['photoUrl'] as String?;
      // Construimos el marcador (sin texto de plan, solo avatar)
      final BitmapDescriptor customMarker = await _buildNoPlanMarker(
        userPhotoUrl ?? '',
      );

      // Agregamos el marcador de "usuario sin plan activo"
      userMarkers.add(
        Marker(
          markerId: MarkerId('noPlanUser_$userId'),
          position: position,
          icon: customMarker,
          onTap: () {
            // Aquí puedes abrir un diálogo con info del usuario,
            // un perfil simplificado o lo que desees.
          },
        ),
      );
    }

    return userMarkers;
  }

  /// Función auxiliar para obtener los participantes del plan (para el FrostedPlanDialog).
  Future<List<Map<String, dynamic>>> _fetchPlanParticipants(PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];

    final planDoc = await FirebaseFirestore.instance.collection('plans').doc(plan.id).get();
    if (planDoc.exists) {
      final planData = planDoc.data() as Map<String, dynamic>;
      final creatorId = planData['createdBy'];
      // Agrega el creador
      if (creatorId != null) {
        final creatorDoc =
            await FirebaseFirestore.instance.collection('users').doc(creatorId).get();
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
            final userDoc =
                await FirebaseFirestore.instance.collection('users').doc(uid).get();
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

  /// Auxiliar para obtener la URL de foto de perfil del usuario [userId].
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

  /// Construye el marcador para un plan, con mayor calidad en el avatar.
  Future<BitmapDescriptor> _buildPlanMarker(
    String photoUrl,
    String planType, {
    bool showText = true,
  }) async {
    try {
      // (1) Descargamos la imagen con calidad original
      final Uint8List imageBytes = await _downloadImageAsBytes(photoUrl);

      // (2) Decodifica en alta resolución (ej: 256x256).
      final ui.Codec codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: 256,
        targetHeight: 256,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image avatarImage = frame.image;

      // Parámetros de tamaño del marcador
      const double markerMinWidth = 120;
      const double padding = 4.0;
      const double fontSize = 20;
      const double textTopMargin = 10;

      // Se calcula el área para el texto solo si showText es true.
      double textContainerHeight = 0;
      TextPainter? textPainter;
      if (showText) {
        textPainter = TextPainter(
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
        textPainter.layout(maxWidth: markerMinWidth - 2 * padding);
        textContainerHeight = textPainter.height + 2 * padding;
      }

      const double avatarAreaHeight = 110;
      final double markerHeight = textContainerHeight + avatarAreaHeight;
      final double markerWidth = markerMinWidth;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      // (3) Si showText es true, pinta fondo y texto
      if (showText && textPainter != null) {
        final double textX = (markerWidth - textPainter.width) / 2;
        final double textY = textTopMargin;
        final Rect bgRect = Rect.fromLTWH(
          textX - padding,
          textY - padding,
          textPainter.width + 2 * padding,
          textPainter.height + 2 * padding,
        );
        final RRect bgRRect =
            RRect.fromRectAndRadius(bgRect, const Radius.circular(8));
        final Paint bgPaint = Paint()..color = Colors.white;
        canvas.drawRRect(bgRRect, bgPaint);

        final Paint textBorderPaint = Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawRRect(bgRRect, textBorderPaint);

        textPainter.paint(canvas, Offset(textX, textY));
      }

      // (4) Avatar
      final double currentTextContainerHeight =
          showText ? textContainerHeight : 0;
      final double circleCenterX = markerWidth / 2;
      final double circleCenterY = currentTextContainerHeight + avatarAreaHeight / 2;
      const double circleRadius = 40;
      final Offset center = Offset(circleCenterX, circleCenterY);

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
        filterQuality: FilterQuality.high,
      );
      canvas.restore();

      // Borde verde alrededor del avatar
      final Paint avatarBorderPaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, circleRadius, avatarBorderPaint);

      final ui.Picture picture = recorder.endRecording();
      final ui.Image markerImage = await picture.toImage(
        markerWidth.toInt(),
        markerHeight.toInt(),
      );
      final ByteData? byteData =
          await markerImage.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      return BitmapDescriptor.fromBytes(pngBytes);
    } catch (e) {
      print("Error creando marcador personalizado: $e");
      return BitmapDescriptor.defaultMarker;
    }
  }

  /// Construye un marcador sólo con el avatar (sin texto), para usuarios sin plan activo.
  Future<BitmapDescriptor> _buildNoPlanMarker(String photoUrl) async {
    try {
      // Tamaño final del lienzo
      const double markerSize = 100;
      const double avatarRadius = 40;

      Uint8List? imageBytes;
      if (photoUrl.isNotEmpty) {
        imageBytes = await _downloadImageAsBytes(photoUrl);
      }

      ui.Image? avatarImage;
      if (imageBytes != null) {
        final ui.Codec codec = await ui.instantiateImageCodec(
          imageBytes,
          targetWidth: 256,
          targetHeight: 256,
        );
        final ui.FrameInfo frame = await codec.getNextFrame();
        avatarImage = frame.image;
      }

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final Offset center = Offset(markerSize / 2, markerSize / 2);

      if (avatarImage != null) {
        final Path clipPath = Path()
          ..addOval(Rect.fromCircle(center: center, radius: avatarRadius));
        canvas.save();
        canvas.clipPath(clipPath);

        final Rect imageRect = Rect.fromCenter(
          center: center,
          width: avatarRadius * 2,
          height: avatarRadius * 2,
        );
        paintImage(
          canvas: canvas,
          rect: imageRect,
          image: avatarImage,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        );
        canvas.restore();

        // Borde verde alrededor del avatar
        final Paint borderPaint = Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(center, avatarRadius, borderPaint);
      } else {
        // Si no hay foto, un círculo gris
        final Paint circlePaint = Paint()..color = const Color(0xFFE0E0E0);
        canvas.drawCircle(center, avatarRadius, circlePaint);
      }

      final ui.Picture picture = recorder.endRecording();
      final ui.Image markerImage = await picture.toImage(
        markerSize.toInt(),
        markerSize.toInt(),
      );
      final ByteData? byteData =
          await markerImage.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      return BitmapDescriptor.fromBytes(pngBytes);
    } catch (e) {
      print("Error creando marcador de usuario sin plan: $e");
      return BitmapDescriptor.defaultMarker;
    }
  }
}
