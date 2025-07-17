import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:collection';
import '../../main/colors.dart';

import '../plans_managing/frosted_plan_dialog_state.dart';
import '../../models/plan_model.dart';

import '../users_managing/user_info_check.dart';
import '../profile/user_images_managing.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class _MarkerData {
  final BitmapDescriptor icon;
  final Offset anchor;
  const _MarkerData(this.icon, this.anchor);
}

class PlansInMapScreen {
  final Set<String> _userIdsWithActivePlan = {};
  final Map<String, Marker> _planMarkerCache = {};
  final Map<String, Map<String, dynamic>> _planDataCache = {};
  final LinkedHashMap<String, BitmapDescriptor> _descriptorCache =
      LinkedHashMap();
  static const int _cacheLimit = 50;
  String? _lastCreatedAt;
  DocumentSnapshot? _lastUserDoc;

  void resetUserPagination() {
    _lastUserDoc = null;
  }

  BitmapDescriptor? _getFromCache(String key) {
    final value = _descriptorCache.remove(key);
    if (value != null) {
      _descriptorCache[key] = value;
    }
    return value;
  }

  void _addToCache(String key, BitmapDescriptor descriptor) {
    if (_descriptorCache.length >= _cacheLimit) {
      _descriptorCache.remove(_descriptorCache.keys.first);
    }
    _descriptorCache[key] = descriptor;
  }

  Future<Set<Marker>> loadPlansMarkers(
    BuildContext context, {
    Map<String, dynamic>? filters,
  }) async {
    Query query =
        FirebaseFirestore.instance.collection('plans').orderBy('createdAt');
    if (_lastCreatedAt != null) {
      query = query.startAfter([_lastCreatedAt]);
    }

    final qs = await query.get();
    final now = DateTime.now();

    // Identificamos a qué usuarios sigue el usuario actual
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final Set<String> followedUids = {};
    final bool onlyFollowed = filters?['onlyFollowed'] == true;
    if (currentUser != null) {
      final snap = await FirebaseFirestore.instance
          .collection('followed')
          .where('userId', isEqualTo: currentUser.uid)
          .get();
      for (final doc in snap.docs) {
        final fid = doc.data()['followedId'] as String?;
        if (fid != null) followedUids.add(fid);
      }
    }
    final tasks = qs.docs.map((doc) async {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      final sp = data['special_plan'] ?? 0;
      if (sp != 0) return null;
      final startTs = data['start_timestamp'];
      if (startTs == null) return null;
      final startDate = (startTs as Timestamp).toDate();
      final DateTime? filterDate = filters?['planDate'];
      if (filterDate != null) {
        if (startDate.year != filterDate.year ||
            startDate.month != filterDate.month ||
            startDate.day != filterDate.day) {
          return null;
        }
      } else {
        if (!startDate.isAfter(now)) return null;
      }
      final lat = data['latitude']?.toDouble();
      final lng = data['longitude']?.toDouble();
      final type = data['type'] as String?;
      final uid = data['createdBy'] as String?;
      if (lat == null || lng == null || type == null || uid == null)
        return null;
      if (lat == 0.0 || lng == 0.0) return null;
      if (onlyFollowed && !followedUids.contains(uid)) {
        return null;
      }
      final String visibility = data['visibility']?.toString() ?? 'Público';
      if (visibility.toLowerCase() == 'privado') {
        return null;
      }
      if (visibility.toLowerCase() == 'solo para mis seguidores') {
        if (currentUser == null || !followedUids.contains(uid)) {
          return null;
        }
      }
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
            return null;
          }
        } else if (searchText.isNotEmpty) {
          if (!type.toLowerCase().contains(searchText)) {
            return null;
          }
        }
      }
      final photoUrl = await _getUserProfilePhoto(uid);
      if (photoUrl == null) return null;
      final pos = LatLng(lat, lng);
      final _MarkerData iconData =
          await _buildPlanMarker(photoUrl, type, showText: true);
      _userIdsWithActivePlan.add(uid);
      final marker = Marker(
        markerId: MarkerId(doc.id),
        position: pos,
        icon: iconData.icon,
        anchor: iconData.anchor,
        onTap: () {
          showGeneralDialog(
            context: context,
            barrierDismissible: true,
            barrierLabel: 'Cerrar',
            barrierColor: Colors.black.withOpacity(0.4),
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (context, animation, secondaryAnimation) {
              final size = MediaQuery.of(context).size;
              final plan = PlanModel.fromMap(data)
                ..creatorProfilePic = photoUrl;
              return Align(
                alignment: Alignment.center,
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: FrostedPlanDialog(
                      plan: plan,
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
      );
      _planMarkerCache[doc.id] = marker;
      _planDataCache[doc.id] = data;
      final String? createdAt = data['createdAt'] as String?;
      if (createdAt != null) {
        if (_lastCreatedAt == null ||
            createdAt.compareTo(_lastCreatedAt!) > 0) {
          _lastCreatedAt = createdAt;
        }
      }
      return marker;
    });
    final markersList = await Future.wait(tasks);
    for (final m in markersList) {
      if (m != null) {
        // already stored in caches above
      }
    }
    final Set<Marker> result = {};
    _planMarkerCache.forEach((id, marker) {
      final data = _planDataCache[id];
      if (data == null) return;
      final DateTime? filterDate = filters?['planDate'];
      final Timestamp? ts = data['start_timestamp'];
      DateTime? startDate = ts?.toDate();
      if (filterDate != null) {
        if (startDate == null ||
            startDate.year != filterDate.year ||
            startDate.month != filterDate.month ||
            startDate.day != filterDate.day) {
          return;
        }
      } else {
        if (startDate == null || !startDate.isAfter(now)) {
          return;
        }
      }
      if (filters != null) {
        final List<String> selected =
            (filters['selectedPlans'] as List<dynamic>?)
                    ?.map((e) => e.toString().toLowerCase())
                    .toList() ??
                [];
        final String searchText =
            (filters['planBusqueda'] ?? '').toString().toLowerCase();
        final String type = data['type']?.toString() ?? '';
        final String visibility = data['visibility']?.toString() ?? 'Público';
        if (onlyFollowed && !followedUids.contains(data['createdBy'])) {
          return;
        }
        if (selected.isNotEmpty) {
          if (!selected.contains(type.toLowerCase())) return;
        } else if (searchText.isNotEmpty) {
          if (!type.toLowerCase().contains(searchText)) return;
        }
        if (visibility.toLowerCase() == 'privado') return;
        if (visibility.toLowerCase() == 'solo para mis seguidores') {
          if (currentUser == null ||
              !followedUids.contains(data['createdBy'])) {
            return;
          }
        }
      }
      result.add(marker);
    });
    return result;
  }

// Método loadUsersWithoutPlansMarkers modificado para eliminar el filtro de hasActivePlan y filtrar longitud manualmente
  Future<Set<Marker>> loadUsersWithoutPlansMarkers(
    BuildContext context, {
    required LatLngBounds bounds,
    Map<String, dynamic>? filters,
  }) async {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('latitude', isGreaterThanOrEqualTo: bounds.southwest.latitude)
        .where('latitude', isLessThanOrEqualTo: bounds.northeast.latitude)
        .limit(50);
    if (_lastUserDoc != null) {
      query = query.startAfterDocument(_lastUserDoc!);
    }
    final qs = await query.get();
    if (qs.docs.isNotEmpty) _lastUserDoc = qs.docs.last;

    final Set<Marker> markers = {};
    final bool onlyFollowed = filters?['onlyFollowed'] == true;
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final Set<String> followedUids = {};
    if (onlyFollowed && currentUser != null) {
      final snap = await FirebaseFirestore.instance
          .collection('followed')
          .where('userId', isEqualTo: currentUser.uid)
          .get();
      for (var doc in snap.docs) {
        final fid = doc.data()['followedId'] as String?;
        if (fid != null) followedUids.add(fid);
      }
    }

    for (var doc in qs.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final uid = data['uid'] as String?;
      if (uid == null || uid.isEmpty) continue;
      if (_userIdsWithActivePlan.contains(uid)) continue;
      if (onlyFollowed && !followedUids.contains(uid)) continue;

      final lat = data['latitude']?.toDouble();
      final lng = data['longitude']?.toDouble();
      if (lat == null || lng == null || lat == 0 || lng == 0) continue;
      // Filtrar longitud fuera de bounds manualmente
      if (lng < bounds.southwest.longitude || lng > bounds.northeast.longitude)
        continue;

      String photoUrl = data['photoUrl']?.toString() ?? '';
      if (photoUrl.isEmpty) {
        final cover = data['coverPhotoUrl']?.toString() ?? '';
        photoUrl = cover.isNotEmpty ? cover : UserImagesManaging.placeholderImageUrl;
      }
      final pos = LatLng(lat, lng);
      final _MarkerData iconData = await _buildNoPlanMarker(photoUrl);
      markers.add(
        Marker(
          markerId: MarkerId('noPlanUser_$uid'),
          position: pos,
          icon: iconData.icon,
          anchor: iconData.anchor,
          onTap: () => UserInfoCheck.open(context, uid),
        ),
      );
    }
    return markers;
  }

  Future<List<Map<String, dynamic>>> _fetchPlanParticipants(
      PlanModel plan) async {
    final List<Map<String, dynamic>> parts = [];
    final doc =
        await FirebaseFirestore.instance.collection('plans').doc(plan.id).get();
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
    final photo = data['photoUrl']?.toString();
    if (photo != null && photo.isNotEmpty) return photo;
    final cover = data['coverPhotoUrl']?.toString();
    return (cover != null && cover.isNotEmpty)
        ? cover
        : UserImagesManaging.placeholderImageUrl;
  }

  Future<Uint8List> _downloadImageAsBytes(String url) async {
    final file = await DefaultCacheManager().getSingleFile(url);
    return await file.readAsBytes();
  }

  Future<_MarkerData> _buildPlanMarker(
    String photoUrl,
    String planType, {
    bool showText = true,
  }) async {
    try {
      final String finalUrl = photoUrl.isNotEmpty
          ? photoUrl
          : UserImagesManaging.placeholderImageUrl;
      final cacheKey = 'plan:' + finalUrl + ':' + planType;
      final cached = _getFromCache(cacheKey);
      if (cached != null) {
        return _MarkerData(cached, const Offset(0.5, 1.0));
      }
      final bytes = await _downloadImageAsBytes(finalUrl);
      final codec = await ui.instantiateImageCodec(bytes,
          targetWidth: 256, targetHeight: 256);
      final frame = await codec.getNextFrame();
      final avatar = frame.image;
      // Ajustamos las dimensiones del marcador para que el avatar no se
      // vea comprimido verticalmente en el mapa. Se incrementa la zona
      // destinada al avatar y su radio para mejorar la proporción final.
      const double mw = 140, padding = 4, fs = 20, tm = 29, avatarArea = 140;
      double textH = 0;
      TextPainter? tp;
      if (showText) {
        tp = TextPainter(
          text: TextSpan(
            text: planType,
            style: const TextStyle(
                fontSize: fs, color: Colors.white, fontWeight: FontWeight.bold),
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
        final rrect =
            RRect.fromRectAndRadius(bgRect, const Radius.circular(30));
        canvas.drawRRect(rrect, Paint()..color = AppColors.planColor);
        final border = Paint()
          ..color = AppColors.greyBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawRRect(rrect, border);
        tp.paint(canvas, Offset(tx, ty));
      }
      final cy = (showText ? textH : 0) + avatarArea / 2;
      const cr = 45.0;
      final center = Offset(mw / 2, cy);
      final clipPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: cr));
      canvas.save();
      canvas.clipPath(clipPath);
      final imgRect =
          Rect.fromCenter(center: center, width: cr * 2, height: cr * 2 + 10);
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
      final icon = BitmapDescriptor.fromBytes(pngBytes);
      _addToCache(cacheKey, icon);
      return _MarkerData(icon, Offset(0.5, cy / mh));
    } catch (_) {
      if (photoUrl != UserImagesManaging.placeholderImageUrl) {
        return _buildPlanMarker(
            UserImagesManaging.placeholderImageUrl, planType,
            showText: showText);
      }
      return const _MarkerData(
          BitmapDescriptor.defaultMarker, Offset(0.5, 1.0));
    }
  }

  Future<_MarkerData> _buildNoPlanMarker(String photoUrl) async {
    try {
      // Aumentamos el tamaño base del marcador de usuario sin plan para que la
      // imagen no se muestre achatada en vertical.
      const double sz = 120, r = 45;
      final String finalUrl = photoUrl.isNotEmpty
          ? photoUrl
          : UserImagesManaging.placeholderImageUrl;
      final cacheKey = 'user:' + finalUrl;
      final cached = _getFromCache(cacheKey);
      if (cached != null) {
        return _MarkerData(cached, const Offset(0.5, 0.5));
      }
      Uint8List? bytes;
      if (finalUrl.isNotEmpty) {
        bytes = await _downloadImageAsBytes(finalUrl);
      }
      ui.Image? av;
      if (bytes != null) {
        final codec = await ui.instantiateImageCodec(bytes,
            targetWidth: 64, targetHeight: 64);
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
      final icon = BitmapDescriptor.fromBytes(pngBytes);
      _addToCache(cacheKey, icon);
      return _MarkerData(icon, const Offset(0.5, 0.5));
    } catch (_) {
      if (photoUrl != UserImagesManaging.placeholderImageUrl) {
        return _buildNoPlanMarker(UserImagesManaging.placeholderImageUrl);
      }
      return const _MarkerData(
          BitmapDescriptor.defaultMarker, Offset(0.5, 1.0));
    }
  }
}
