import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // Para copiar al portapapeles
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/plan_model.dart';
import '../../main/colors.dart';
import '../../utils/plans_list.dart' as plansData;

/// ----------------------------------------------------------------------------
/// Diálogo con efecto frosted para mostrar planes.
/// ----------------------------------------------------------------------------
class FrostedPlanDialog extends StatelessWidget {
  final PlanModel plan;
  final Future<List<Map<String, dynamic>>> Function(PlanModel) fetchParticipants;

  const FrostedPlanDialog({
    Key? key,
    required this.plan,
    required this.fetchParticipants,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ahora siempre usamos _buildSpecialPlanContent
    // para mostrar el layout grande.
    return ClipRRect(
      borderRadius: BorderRadius.circular(30.0),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.05)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: SingleChildScrollView(
            // Antes: plan.special_plan == 1 ? ... : ...
            // Ahora siempre _buildSpecialPlanContent
            child: _buildSpecialPlanContent(context),
          ),
        ),
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// (NO USADO) Contenido para planes NORMALES (special_plan == 0)
  /// Queda aquí por si deseas recuperarlo más adelante.
  /// --------------------------------------------------------------------------
  Widget _buildNormalPlanContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          plan.type,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 10),
        Text(
          plan.description,
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchParticipants(plan),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return const Text(
                "Error al cargar participantes",
                style: TextStyle(color: Colors.white),
              );
            } else {
              final participants = snapshot.data ?? [];
              return SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final participant = participants[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Column(
                        children: [
                          CircleAvatar(
                            backgroundImage: NetworkImage(participant['photoUrl']),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            participant['name'],
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }
          },
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          onPressed: () => Navigator.pop(context),
          child: const Text("Cerrar"),
        ),
      ],
    );
  }

  /// --------------------------------------------------------------------------
  /// Contenido grande (antes: solo planes ESPECIALES).
  /// Ahora lo usaremos para TODOS los planes.
  /// --------------------------------------------------------------------------
  Widget _buildSpecialPlanContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1) Tipo de plan con icono (si existe) y contenedor con "Este plan va de"
        _buildPlanTypeHeader(),

        const SizedBox(height: 20),

        // 2) Creador del plan + 3) Participantes
        FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchParticipants(plan),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Text(
                'Error al cargar participantes',
                style: TextStyle(color: Colors.white),
              );
            }
            final all = snapshot.data ?? [];
            if (all.isEmpty) {
              return const Text(
                'No hay participantes en este plan.',
                style: TextStyle(color: Colors.white),
              );
            }
            final creator = all.firstWhere(
              (p) => p['isCreator'] == true,
              orElse: () => {},
            );
            final participants =
                all.where((p) => p['isCreator'] == false).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (creator.isNotEmpty) ...[
                  const Text(
                    "Creador del plan:",
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  _buildParticipantTile(creator),
                  const SizedBox(height: 10),
                ],
                const Text(
                  "Participantes:",
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                if (participants.isEmpty)
                  const Text(
                    "No hay participantes en este plan.",
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  ...participants.map(_buildParticipantTile),
              ],
            );
          },
        ),

        const SizedBox(height: 20),

        // 4) ID del plan
        _buildPlanIdField(context),

        const SizedBox(height: 20),

        // 5) Breve descripción
        _buildBriefDescription(),

        const SizedBox(height: 20),

        // 6) Fecha del evento
        _buildPlanDate(),

        const SizedBox(height: 5),

        // 7) Creado el
        _buildPlanCreatedAt(),

        const SizedBox(height: 10),

        // 8) Ubicación con el mapa
        _buildReadOnlyLocationMap(plan),

        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          onPressed: () => Navigator.pop(context),
          child: const Text("Cerrar"),
        ),
      ],
    );
  }

  /// --------------------------------------------------------------------------
  /// (1) Cabecera que muestra el tipo de plan y, si existe, el icono correspondiente
  ///     dentro de un contenedor con el texto "Este plan va de ..."
  /// --------------------------------------------------------------------------
  Widget _buildPlanTypeHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8),
              // Si plan.iconAsset existe, lo mostramos
              if (plan.iconAsset != null && plan.iconAsset!.isNotEmpty) ...[
                SvgPicture.asset(
                  plan.iconAsset!,
                  width: 34,
                  height: 34,
                  color: Colors.amber,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: "Este plan va de \n",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Inter-Regular',
                        ),
                      ),
                      TextSpan(
                        text: plan.type,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter-Regular',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// (2) + (3) Creado con _buildParticipantTile() (ya dentro del FutureBuilder)
  /// --------------------------------------------------------------------------
  Widget _buildParticipantTile(Map<String, dynamic> userData) {
    final pic = userData['photoUrl'] ?? '';
    final name = userData['name'] ?? 'Usuario';
    final age = userData['age'] ?? '';
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
        backgroundColor: Colors.blueGrey[100],
      ),
      title: Text(
        '$name, $age',
        style: const TextStyle(
          color: Color.fromARGB(255, 151, 121, 215),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// (4) ID del plan con botón para copiar
  /// --------------------------------------------------------------------------
  Widget _buildPlanIdField(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'ID del Plan: ${plan.id}',
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.copy,
            color: Color.fromARGB(255, 151, 121, 215),
          ),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: plan.id));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ID copiado al portapapeles')),
            );
          },
        ),
      ],
    );
  }

  /// --------------------------------------------------------------------------
  /// (5) Breve descripción
  /// --------------------------------------------------------------------------
  Widget _buildBriefDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Descripción breve",
          style: TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          plan.description,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  /// --------------------------------------------------------------------------
  /// (6) Fecha del evento
  /// --------------------------------------------------------------------------
  Widget _buildPlanDate() {
    return RichText(
      text: TextSpan(
        children: [
          const TextSpan(
            text: "Fecha del evento: ",
            style: TextStyle(color: Colors.white),
          ),
          TextSpan(
            text: plan.formattedDate(plan.date),
            style: const TextStyle(
              color: Color.fromARGB(255, 151, 121, 215),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// (7) Fecha de creación (createdAt)
  /// --------------------------------------------------------------------------
  Widget _buildPlanCreatedAt() {
    return RichText(
      text: TextSpan(
        children: [
          const TextSpan(
            text: "Creado el: ",
            style: TextStyle(color: Colors.white),
          ),
          TextSpan(
            text: plan.formattedDate(plan.createdAt),
            style: const TextStyle(
              color: Color.fromARGB(255, 151, 121, 215),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// (8) Mapa de solo lectura (igual que el original)
  /// --------------------------------------------------------------------------
  Widget _buildReadOnlyLocationMap(PlanModel plan) {
    if (plan.latitude == null || plan.longitude == null) return const SizedBox();
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        children: [
          SizedBox(
            height: 240,
            width: double.infinity,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(plan.latitude!, plan.longitude!),
                zoom: 16,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('plan_location'),
                  position: LatLng(plan.latitude!, plan.longitude!),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueBlue),
                  anchor: const Offset(0.5, 0.5),
                ),
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              liteModeEnabled: true,
              onMapCreated: (controller) {},
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    plan.location,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// Pantalla principal donde se listan los planes del usuario logueado.
/// ----------------------------------------------------------------------------
class MyPlansScreen extends StatelessWidget {
  const MyPlansScreen({Key? key}) : super(key: key);

  // --------------------------------------------------------------------------
  // Método para obtener todos los participantes del plan.
  // --------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(
      PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];

    final planDoc = await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .get();
    if (planDoc.exists) {
      final planData = planDoc.data();
      final creatorId = planData?['createdBy'];
      if (creatorId != null) {
        final creatorUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(creatorId)
            .get();
        if (creatorUserDoc.exists) {
          final cdata = creatorUserDoc.data()!;
          participants.add({
            'name': cdata['name'] ?? 'Sin nombre',
            'age': cdata['age']?.toString() ?? '',
            'photoUrl': cdata['photoUrl'] ?? cdata['profilePic'] ?? '',
            'isCreator': true,
          });
        }
      }
    }

    final subsSnap = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('id', isEqualTo: plan.id)
        .get();
    for (var sDoc in subsSnap.docs) {
      final sData = sDoc.data();
      final userId = sData['userId'];
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final uData = userDoc.data()!;
        participants.add({
          'name': uData['name'] ?? 'Sin nombre',
          'age': uData['age']?.toString() ?? '',
          'photoUrl': uData['photoUrl'] ?? uData['profilePic'] ?? '',
          'isCreator': false,
        });
      }
    }

    return participants;
  }

  // --------------------------------------------------------------------------
  // (Opcional) Mapa de solo lectura
  // --------------------------------------------------------------------------
  Widget _buildReadOnlyLocationMap(PlanModel plan) {
    if (plan.latitude == null || plan.longitude == null) return const SizedBox();
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        children: [
          SizedBox(
            height: 240,
            width: double.infinity,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(plan.latitude!, plan.longitude!),
                zoom: 16,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('plan_location'),
                  position: LatLng(plan.latitude!, plan.longitude!),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueBlue),
                  anchor: const Offset(0.5, 0.5),
                ),
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              liteModeEnabled: true,
              onMapCreated: (controller) {},
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30)),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    plan.location,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Construye la pantalla con las tarjetas de planes creados por el usuario.
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(
        child: Text(
          'Debes iniciar sesión para ver tus planes.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('plans')
            .where('createdBy', isEqualTo: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No tienes planes aún.',
                  style: TextStyle(color: Colors.black)),
            );
          }

          final plans = snapshot.data!.docs
              .map((doc) =>
                  PlanModel.fromMap(doc.data() as Map<String, dynamic>))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return _buildPlanCard(context, plan, index);
            },
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Construye cada tarjeta de plan con su imagen de fondo y frosted dialog.
  // Al pulsar, se muestra el diálogo con los detalles (FrostedPlanDialog).
  // --------------------------------------------------------------------------
  Widget _buildPlanCard(BuildContext context, PlanModel plan, int index) {
    // Verificamos si el plan es especial o no
    if (plan.special_plan == 1) {
      // ... (código para tarjeta de plan especial) ...
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchAllPlanParticipants(plan),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: 100,
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueAccent, width: 2),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            );
          }
          
          final participants = snapshot.data!;
          final Widget creatorAvatar = participants.isNotEmpty &&
                  (participants[0]['photoUrl'] ?? '').toString().isNotEmpty
              ? CircleAvatar(
                  backgroundImage: NetworkImage(participants[0]['photoUrl']),
                  radius: 20,
                )
              : const CircleAvatar(radius: 20);
          final Widget participantAvatar =
              participants.length > 1 &&
                      (participants[1]['photoUrl'] ?? '').toString().isNotEmpty
                  ? CircleAvatar(
                      backgroundImage: NetworkImage(participants[1]['photoUrl']),
                      radius: 20,
                    )
                  : const SizedBox();

          // Buscamos en la lista importada el icono asociado comparando plan.iconAsset con cada item.
          String iconPath = plan.iconAsset ?? '';
          for (var item in plansData.plans) {
            if (plan.iconAsset == item['icon']) {
              iconPath = item['icon'];
              break;
            }
          }

          return GestureDetector(
            onTap: () {
              showGeneralDialog(
                context: context,
                barrierDismissible: true,
                barrierLabel: 'Cerrar',
                transitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (context, animation, secondaryAnimation) {
                  return SafeArea(
                    child: Align(
                      alignment: Alignment.center,
                      child: Material(
                        color: Colors.transparent,
                        child: FrostedPlanDialog(
                          plan: plan,
                          fetchParticipants: _fetchAllPlanParticipants,
                        ),
                      ),
                    ),
                  );
                },
                transitionBuilder: (context, anim1, anim2, child) {
                  return FadeTransition(opacity: anim1, child: child);
                },
              );
            },
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: 80,
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(color: Colors.blueAccent, width: 2),
                ),
                child: Row(
                  children: [
                    // Lado izquierdo: icono y nombre del tipo de plan
                    Row(
                      children: [
                        if (iconPath.isNotEmpty)
                          SvgPicture.asset(
                            iconPath,
                            width: 40,
                            height: 40,
                            color: Colors.amber,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          plan.type,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Lado derecho: avatares del creador y del participante
                    Row(
                      children: [
                        creatorAvatar,
                        const SizedBox(width: 8),
                        participantAvatar,
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } else {
      // Plan normal
      final String? backgroundImage = plan.backgroundImage;
      final String caption = plan.description.isNotEmpty
          ? plan.description
          : 'Descripción breve o #hashtags';
      final String commentsCount = '173';
      final String sharesCount = '227';

      return GestureDetector(
        onTap: () {
          // Al pulsar la tarjeta, se muestra el diálogo frosted
          showGeneralDialog(
            context: context,
            barrierDismissible: true,
            barrierLabel: 'Cerrar',
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (ctx, animation, secondaryAnimation) {
              return SafeArea(
                child: Align(
                  alignment: Alignment.center,
                  child: Material(
                    color: Colors.transparent,
                    child: FrostedPlanDialog(
                      plan: plan,
                      // Usa la misma función que ya tienes para traer participantes
                      fetchParticipants: _fetchAllPlanParticipants,
                    ),
                  ),
                ),
              );
            },
            transitionBuilder: (context, anim1, anim2, child) {
              return FadeTransition(
                opacity: anim1,
                child: child,
              );
            },
          );
        },
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: 330,
            margin: const EdgeInsets.only(bottom: 15),
            child: Stack(
              children: [
                // Imagen de fondo
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: (backgroundImage != null && backgroundImage.isNotEmpty)
                      ? Image.network(
                          backgroundImage,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
                // Botón para eliminar
                Positioned(
                  top: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => _confirmDeletePlan(context, plan),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Parte inferior: contadores, caption...
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, 
                          vertical: 8
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.5),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildIconText(
                                  icon: Icons.favorite_border,
                                  label: plan.likes.toString(),
                                ),
                                const SizedBox(width: 25),
                                _buildIconText(
                                  icon: Icons.chat_bubble_outline,
                                  label: commentsCount,
                                ),
                                const SizedBox(width: 25),
                                _buildIconText(
                                  icon: Icons.share,
                                  label: sharesCount,
                                ),
                                const Spacer(),
                                Row(
                                  children: const [
                                    Text(
                                      '7/10',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(
                                      Icons.person,
                                      color: AppColors.blue,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              caption,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Método alternativo para obtener participantes (NO se usa, pero si lo quieres).
  // --------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _fetchPlanParticipants(PlanModel plan) async {
    final List<Map<String, dynamic>> participants = [];

    final planDoc = await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .get();
    if (planDoc.exists) {
      final planData = planDoc.data();
      final creatorId = planData?['createdBy'];
      if (creatorId != null) {
        final creatorUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(creatorId)
            .get();
        if (creatorUserDoc.exists) {
          final cdata = creatorUserDoc.data()!;
          participants.add({
            'name': cdata['name'] ?? 'Sin nombre',
            'age': cdata['age']?.toString() ?? '',
            'photoUrl': cdata['photoUrl'] ?? cdata['profilePic'] ?? '',
            'isCreator': true,
          });
        }
      }
    }

    final subsSnap = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('id', isEqualTo: plan.id)
        .get();
    for (var sDoc in subsSnap.docs) {
      final sData = sDoc.data();
      final userId = sData['userId'];
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final uData = userDoc.data()!;
        participants.add({
          'name': uData['name'] ?? 'Sin nombre',
          'age': uData['age']?.toString() ?? '',
          'photoUrl': uData['photoUrl'] ?? uData['profilePic'] ?? '',
          'isCreator': false,
        });
      }
    }

    return participants;
  }

  // --------------------------------------------------------------------------
  // Popup de confirmación de eliminación
  // --------------------------------------------------------------------------
  void _confirmDeletePlan(BuildContext context, PlanModel plan) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("¿Eliminar este plan?"),
          content: Text("Esta acción eliminará el plan ${plan.type}."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('plans')
                    .doc(plan.id)
                    .delete();
                final subs = await FirebaseFirestore.instance
                    .collection('subscriptions')
                    .where('id', isEqualTo: plan.id)
                    .get();
                for (var doc in subs.docs) {
                  await doc.reference.delete();
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Plan ${plan.type} eliminado correctamente.')),
                );
              },
              child: const Text("Eliminar"),
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Placeholder para cuando la imagen no existe o falla
  // --------------------------------------------------------------------------
  Widget _buildPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.grey[200],
        height: 350,
        width: double.infinity,
        child: const Center(
          child: Icon(Icons.image, size: 40, color: Colors.grey),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Helper para construir un widget con ícono y texto
  // --------------------------------------------------------------------------
  Widget _buildIconText({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
