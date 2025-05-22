import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../plans_managing/frosted_plan_dialog_state.dart';
import '../../models/plan_model.dart';

class PlansInMapScreen {
  final Set<String> _userIdsWithActivePlan = {};

  Future<Set<Marker>> loadPlansMarkers(
    BuildContext context, {
    Map<String, dynamic>? filters,
  }) async {
    final qs = await FirebaseFirestore.instance.collection('plans').get();
    final Set<Marker> markers = {};
    final now = DateTime.now();
    for (var doc in qs.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final sp = data['special_plan'] ?? 0;
      if (sp != 0) continue;
      final startTs = data['start_timestamp'];
      if (startTs == null) continue;
      if (!(startTs as Timestamp).toDate().isAfter(now)) continue;
      final lat = data['latitude']?.toDouble();
      final lng = data['longitude']?.toDouble();
      final type = data['type'] as String?;
      final uid = data['createdBy'] as String?;
      if (lat == null || lng == null || type == null || uid == null) continue;
      if (filters != null) {
        final List<String> selected =
            (filters['selectedPlans'] as List<dynamic>?)
                    ?.map((e) => e.toString().toLowerCase())
                    .toList() ??
                [];
        final String searchText =
            (filters['planBusqueda'] ?? '').toString().toLowerCase();

        if (selected.isNotEmpty) {
          if (!selected.contains(type.toLowerCase())) {
            continue;
          }
        } else if (searchText.isNotEmpty) {
          if (!type.toLowerCase().contains(searchText)) {
            continue;
          }
        }
      }
      final photoUrl = await _getUserProfilePhoto(uid);
      if (photoUrl == null) continue;
      final pos = LatLng(lat, lng);
      final icon = await _buildPlanMarker(photoUrl, type, showText: true);
      _userIdsWithActivePlan.add(uid);
      markers.add(
        Marker(
          markerId: MarkerId(doc.id),
          position: pos,
          icon: icon,
          onTap: () {
            showGeneralDialog(
              context: context,
              barrierDismissible: true,
              barrierLabel: 'Cerrar',
              barrierColor: Colors.black.withOpacity(0.4),
              transitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (context, animation, secondaryAnimation) {
                final size = MediaQuery.of(context).size;
                return Align(
                  alignment: Alignment.center,
                  child: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
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
                  opacity:
                      CurvedAnimation(parent: anim1, curve: Curves.easeOut),
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

  Future<Set<Marker>> loadUsersWithoutPlansMarkers(
    BuildContext context, {
    Map<String, dynamic>? filters,
  }) async {
    final qs = await FirebaseFirestore.instance.collection('users').get();
    final Set<Marker> markers = {};
    for (var doc in qs.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final uid = data['uid'] ?? '';
      if (uid.isEmpty) continue;
      if (_userIdsWithActivePlan.contains(uid)) continue;
      final lat = data['latitude']?.toDouble();
      final lng = data['longitude']?.toDouble();
      if (lat == null || lng == null) continue;
      final photoUrl = data['photoUrl'] as String? ?? '';
      final pos = LatLng(lat, lng);
      final icon = await _buildNoPlanMarker(photoUrl);
      markers.add(
        Marker(
          markerId: MarkerId('noPlanUser_$uid'),
          position: pos,
          icon: icon,
          onTap: () {},
        ),
      );
    }
    return markers;
  }

  Future<List<Map<String, dynamic>>> _fetchPlanParticipants(PlanModel plan) async {
  final List<Map<String, dynamic>> parts = [];
  final doc = await FirebaseFirestore.instance.collection('plans').doc(plan.id).get();
  if (!doc.exists) return parts;
  final data = doc.data() as Map<String, dynamic>;
  final creatorId = data['createdBy'];

  // No añadimos al creador en 'parts'
  // (Si no quieres que aparezca el propio creador entre los participantes, 
  //   entonces no agregues el bloque de creador aquí)

  final rawParts = data['participants'];
  if (rawParts is List) {
    for (final uid in rawParts) {
      if (uid is String && uid != creatorId) {
        final uDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (uDoc.exists) {
          final uData = uDoc.data() as Map<String, dynamic>;
          parts.add({
            'uid': uid,
            'isCreator': false,
            'photoUrl': uData['photoUrl'] ?? '',
            'name': uData['name'] ?? 'Usuario',
            'age': (uData['age'] ?? '').toString(),
          });
        }
      }
    }
  }
  return parts;
}


  Future<String?> _getUserProfilePhoto(String userId) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;
    return data['photoUrl'] as String?;
  }

  Future<Uint8List> _downloadImageAsBytes(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) return res.bodyBytes;
    throw Exception("No se pudo descargar imagen");
  }

  Future<BitmapDescriptor> _buildPlanMarker(
    String photoUrl,
    String planType, {
    bool showText = true,
  }) async {
    try {
      final bytes = await _downloadImageAsBytes(photoUrl);
      final codec = await ui.instantiateImageCodec(bytes,
          targetWidth: 256, targetHeight: 256);
      final frame = await codec.getNextFrame();
      final avatar = frame.image;
      const double mw = 120, padding = 4, fs = 20, tm = 10, avatarArea = 110;
      double textH = 0;
      TextPainter? tp;
      if (showText) {
        tp = TextPainter(
          text: TextSpan(
            text: planType,
            style: const TextStyle(
                fontSize: fs, color: Colors.black, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        tp.layout(maxWidth: mw - 2 * padding);
        textH = tp.height + 2 * padding;
      }
      final mh = textH + avatarArea;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      if (showText && tp != null) {
        final tx = (mw - tp.width) / 2;
        final ty = tm;
        final bgRect = Rect.fromLTWH(tx - padding, ty - padding,
            tp.width + 2 * padding, tp.height + 2 * padding);
        final rrect = RRect.fromRectAndRadius(bgRect, const Radius.circular(8));
        canvas.drawRRect(rrect, Paint()..color = Colors.white);
        final border = Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawRRect(rrect, border);
        tp.paint(canvas, Offset(tx, ty));
      }
      final cy = (showText ? textH : 0) + avatarArea / 2;
      const cr = 40.0;
      final center = Offset(mw / 2, cy);
      final clipPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: cr));
      canvas.save();
      canvas.clipPath(clipPath);
      final imgRect =
          Rect.fromCenter(center: center, width: cr * 2, height: cr * 2);
      paintImage(
        canvas: canvas,
        rect: imgRect,
        image: avatar,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
      canvas.restore();
      canvas.drawCircle(
          center,
          cr,
          Paint()
            ..color = Colors.green
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
      final pic = recorder.endRecording();
      final img = await pic.toImage(mw.toInt(), mh.toInt());
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = bd!.buffer.asUint8List();
      return BitmapDescriptor.fromBytes(pngBytes);
    } catch (_) {
      return BitmapDescriptor.defaultMarker;
    }
  }

  Future<BitmapDescriptor> _buildNoPlanMarker(String photoUrl) async {
    try {
      const double sz = 100, r = 40;
      Uint8List? bytes;
      if (photoUrl.isNotEmpty) {
        bytes = await _downloadImageAsBytes(photoUrl);
      }
      ui.Image? av;
      if (bytes != null) {
        final codec = await ui.instantiateImageCodec(bytes,
            targetWidth: 256, targetHeight: 256);
        final frame = await codec.getNextFrame();
        av = frame.image;
      }
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      final center = Offset(sz / 2, sz / 2);
      if (av != null) {
        final path = Path()
          ..addOval(Rect.fromCircle(center: center, radius: r));
        canvas.save();
        canvas.clipPath(path);
        final rect =
            Rect.fromCenter(center: center, width: r * 2, height: r * 2);
        paintImage(
          canvas: canvas,
          rect: rect,
          image: av,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        );
        canvas.restore();
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..color = Colors.green
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      } else {
        canvas.drawCircle(center, r, Paint()..color = const Color(0xFFE0E0E0));
      }
      final pic = rec.endRecording();
      final img = await pic.toImage(sz.toInt(), sz.toInt());
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = bd!.buffer.asUint8List();
      return BitmapDescriptor.fromBytes(pngBytes);
    } catch (_) {
      return BitmapDescriptor.defaultMarker;
    }
  }
}
