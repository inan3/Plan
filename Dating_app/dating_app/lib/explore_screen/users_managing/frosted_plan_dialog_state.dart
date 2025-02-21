// lib/explore_screen/users_managing/frosted_plan_dialog_state.dart

import 'dart:convert';
import 'dart:ui' as ui;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../main/colors.dart';
import '../../models/plan_model.dart';

part of 'user_info_check.dart';

/// -----------------------------------------------------------------------------
/// DIÁLOGO PERSONALIZADO CON EFECTO FROSTED
/// -----------------------------------------------------------------------------
class FrostedPlanDialog extends StatefulWidget {
  final PlanModel plan;
  final Future<List<Map<String, dynamic>>> Function(PlanModel plan)
      fetchParticipants;

  const FrostedPlanDialog({
    Key? key,
    required this.plan,
    required this.fetchParticipants,
  }) : super(key: key);

  @override
  State<FrostedPlanDialog> createState() => _FrostedPlanDialogState();
}

class _FrostedPlanDialogState extends State<FrostedPlanDialog> {
  late Future<List<Map<String, dynamic>>> _futureParticipants;

  @override
  void initState() {
    super.initState();
    _futureParticipants = widget.fetchParticipants(widget.plan);
  }

  /// NUEVO: Widget que muestra el área de "Detalles del Plan de X-Plan" con efecto frosted.
Widget _buildPlanDetailsArea(
  PlanModel plan, {
  double width = 300,
}) {
  return Center(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8),
              // Si existe un iconAsset en el plan, se muestra el icono asociado
              if (plan.iconAsset != null && plan.iconAsset!.isNotEmpty) ...[
                SvgPicture.asset(
                  plan.iconAsset!,
                  width: 28,
                  height: 28,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  "Plan \n${plan.type}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter-Regular',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}




  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final screenSize = MediaQuery.of(context).size;

    return SafeArea(
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          // Se aplica el blur solo al recuadro del pop up.
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: screenSize.width * 0.92,
              constraints: BoxConstraints(
                maxHeight: screenSize.height * 0.8,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D253F),
                    Color(0xFF1B3A57),
                    Color(0xFF12232E),
                  ],
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: SingleChildScrollView(
                  // La estructura del pop up se divide en dos partes:
                  // 1. Imagen de fondo en la parte superior
                  // 2. Contenido (detalles, ubicación, participantes, etc.)
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Imagen de fondo del plan (si existe)
                      if (plan.backgroundImage != null &&
                          plan.backgroundImage!.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                          child: Image.memory(
                            base64Decode(plan.backgroundImage!),
                            width: double.infinity,
                            height: 300,
                            fit: BoxFit.cover,
                          ),
                        ),
                      // 2. Contenido del pop up con padding
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Área con efecto frosted que muestra el título, el tipo y el icono del plan.
                            _buildPlanDetailsArea(plan),
                            const SizedBox(height: 10),
                            // Fila con el ID del plan y botón para copiarlo
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: "ID del Plan: ",
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        TextSpan(
                                          text: plan.id,
                                          style: TextStyle(
                                            color: const Color.fromARGB(255, 151, 121, 215),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.copy,
                                    color: Color.fromARGB(255, 151, 121, 215),
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: plan.id));
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'ID copiado al portapapeles'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Detalles del plan: descripción, restricción de edad, etc.
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: "Descripción: ",
                                    style: TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                  TextSpan(
                                    text: plan.description,
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 151, 121, 215),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: "Restricción de Edad: ",
                                    style: TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        "${plan.minAge} - ${plan.maxAge} años",
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 151, 121, 215),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: "Máx. Participantes: ",
                                    style: TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        "${plan.maxParticipants ?? 'Sin límite'}",
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 151, 121, 215),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: "Ubicación: ",
                                    style: TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                  TextSpan(
                                    text: plan.location,
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 151, 121, 215),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: "Fecha del Evento: ",
                                    style: TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                  TextSpan(
                                    text: plan.formattedDate(plan.date),
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 151, 121, 215),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: "Creado el: ",
                                    style: TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                  TextSpan(
                                    text: plan.formattedDate(plan.createdAt),
                                    style: TextStyle(
                                      color: const Color.fromARGB(255, 151, 121, 215),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Ubicación en mapa (de solo lectura)
                            _buildReadOnlyLocationMap(plan),
                            const SizedBox(height: 16),
                            // Participantes
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: _futureParticipants,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Text(
                                    'Error: ${snapshot.error}',
                                    style:
                                        const TextStyle(color: Colors.black),
                                  );
                                }
                                final all = snapshot.data ?? [];
                                if (all.isEmpty) {
                                  return const Text(
                                    'No hay participantes en este plan.',
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 151, 121, 215),
                                    ),
                                  );
                                }
                                final creator = all.firstWhere(
                                  (p) => p['isCreator'] == true,
                                  orElse: () => {},
                                );
                                final participants = all
                                    .where((p) => p['isCreator'] == false)
                                    .toList();

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (creator.isNotEmpty) ...[
                                      const Text(
                                        "Creador del Plan:",
                                        style: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildCreatorTile(creator),
                                      const SizedBox(height: 10),
                                    ],
                                    const Text(
                                      "Participantes:",
                                      style: TextStyle(
                                        color: Colors.white,
                                      ),
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
                            const SizedBox(height: 16),
                            // Botón de cerrar
                            Align(
                              alignment: Alignment.bottomRight,
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  "Cerrar",
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 151, 121, 215),
                                    fontWeight: FontWeight.bold,
                                  ),
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
    );
  }

  /// Muestra un mapa de solo lectura con un marcador y la dirección del plan.
  Widget _buildReadOnlyLocationMap(PlanModel plan) {
    if (plan.latitude == null || plan.longitude == null) {
      return const SizedBox();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        children: [
          Container(
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
                    BitmapDescriptor.hueBlue,
                  ),
                  anchor: const Offset(0.5, 0.5),
                )
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
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

  Widget _buildCreatorTile(Map<String, dynamic> creator) {
    final pic = creator['photoUrl'] ?? '';
    final name = creator['name'] ?? 'Usuario';
    final age = creator['age'] ?? '';
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
        backgroundColor: Colors.purple[100],
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

  Widget _buildParticipantTile(Map<String, dynamic> part) {
    final pic = part['photoUrl'] ?? '';
    final name = part['name'] ?? 'Usuario';
    final age = part['age'] ?? '';
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
}
