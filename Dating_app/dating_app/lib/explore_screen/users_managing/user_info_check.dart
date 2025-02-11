// lib/explore_screen/users_managing/user_info_check.dart

library user_info_check; // Opcional, pero ayuda a dejar claro el 'part of'

// Imports globales
import 'dart:ui'; // Para BackdropFilter, ImageFilter, etc.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para copiar ID, etc.
import 'package:flutter_svg/flutter_svg.dart'; // Para manejar .svg

import '../../main/colors.dart';        // Para AppColors.blue
import '../../models/plan_model.dart';  // Tu modelo unificado
import 'user_info_inside_chat.dart';    // Para abrir chat

part 'frosted_plan_dialog_state.dart';  // <-- Incluimos el archivo PART

/// -----------------------------------------------------------------------------
/// PANTALLA PRINCIPAL: UserInfoCheck
/// -----------------------------------------------------------------------------
class UserInfoCheck extends StatefulWidget {
  final String userId;

  const UserInfoCheck({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<UserInfoCheck> createState() => _UserInfoCheckState();
}

class _UserInfoCheckState extends State<UserInfoCheck> {
  @override
  void initState() {
    super.initState();
    // Dejar la barra de estado transparente e íconos claros
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  // 2.1) Obtener planes activos (creados + suscritos)
  Future<List<PlanModel>> _fetchActivePlans(String userId) async {
    final List<PlanModel> activePlans = [];

    // a) Planes creados
    final createdSnap = await FirebaseFirestore.instance
        .collection('plans')
        .where('createdBy', isEqualTo: userId)
        .get();

    for (var doc in createdSnap.docs) {
      final planMap = doc.data();
      final planModel = PlanModel.fromMap(planMap);
      activePlans.add(planModel);
    }

    // b) Planes suscritos
    final subsSnap = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('userId', isEqualTo: userId)
        .get();

    for (var sDoc in subsSnap.docs) {
      final subData = sDoc.data();
      final planId = subData['id'];
      final planDoc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(planId)
          .get();
      if (planDoc.exists) {
        final planData = planDoc.data()!;
        final planModel = PlanModel.fromMap(planData);

        // Evitar duplicados
        final alreadyExists = activePlans.any((p) => p.id == planModel.id);
        if (!alreadyExists) {
          activePlans.add(planModel);
        }
      }
    }

    // Ordenar por fecha de creación
    activePlans.sort((a, b) =>
        (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
    return activePlans;
  }

  // 2.2) Obtener participantes
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(
    PlanModel plan,
  ) async {
    final List<Map<String, dynamic>> participants = [];

    final planDoc = await FirebaseFirestore.instance
        .collection('plans')
        .doc(plan.id)
        .get();
    if (planDoc.exists) {
      final planData = planDoc.data();
      final creatorId = planData?['createdBy'];

      // Agregar Creador
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
            'photoUrl': cdata['photoUrl'] ?? '',
            'isCreator': true,
          });
        }
      }
    }

    // Suscripciones
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
          'photoUrl': uData['photoUrl'] ?? '',
          'isCreator': false,
        });
      }
    }

    return participants;
  }

  // 2.3) Muestra pop‑up “frosted glass” usando nuestro diálogo
  void _showPlanDetailsFrosted(BuildContext context, PlanModel plan) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: FrostedPlanDialog(
            plan: plan,
            fetchParticipants: _fetchAllPlanParticipants,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Fondo con la imagen del usuario
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(
                  child: Text(
                    'No se encontró el usuario',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }
              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              final String photoUrl = data['photoUrl'] ?? '';
              return Positioned.fill(
                child: (photoUrl.isNotEmpty)
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.grey),
                      )
                    : Container(color: Colors.grey),
              );
            },
          ),
          // Botón Cerrar
          Positioned(
            top: 40,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: AppColors.blue, size: 40),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // Draggable Scrollable con info del usuario
          DraggableScrollableSheet(
            initialChildSize: 0.25,
            minChildSize: 0.25,
            maxChildSize: 0.8,
            builder: (context, scrollController) {
              return ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: Colors.grey.withOpacity(0.3),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          _buildDragHandle(),
                          const SizedBox(height: 16),
                          // Botones de acción (Invitar / Mensaje)
                          _buildActionButtons(),
                          const SizedBox(height: 16),
                          _buildUserInfo(),
                          _buildExtraSections(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      width: 50,
      height: 5,
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }

  Widget _buildUserInfo() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(
            child: Text(
              'No se encontró info de usuario',
              style: TextStyle(color: Colors.white),
            ),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final String name = data['name'] ?? 'Sin nombre';
        final String age = data['age']?.toString() ?? '0';
        final String gender = data['gender'] ?? 'No especificado';
        final String interest = data['interest'] ?? 'N/A';
        final String height = data['height']?.toString() ?? 'N/A';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$name, $age',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: const [
                  Icon(Icons.location_on, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Ciudad desconocida',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Interés: $interest',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Género: $gender',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Altura: $height',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExtraSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1) PLANES ACTIVOS
        _buildSectionTitle('Planes activos'),
        FutureBuilder<List<PlanModel>>(
          future: _fetchActivePlans(widget.userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            }
            final plans = snapshot.data ?? [];
            if (plans.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'No hay planes activos.',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }
            return ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                return Card(
                  color: Colors.white.withOpacity(0.1),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: ListTile(
                    title: Text(
                      plan.type,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'ID: ${plan.id}\nFecha: ${plan.formattedDate(plan.date)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    onTap: () => _showPlanDetailsFrosted(context, plan),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 20),
        // 2) PLANES CREADOS (placeholder)
        _buildSectionTitle('Planes que ha creado'),
        Container(
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          color: Colors.white.withOpacity(0.1),
          child: const Center(
            child: Text(
              'Aquí la lista de planes creados... (ejemplo placeholder)',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Votos
        _buildSectionTitle('Votos que ha recibido'),
        Row(
          children: [
            const SizedBox(width: 20),
            const Icon(Icons.star, color: Colors.amber, size: 28),
            const SizedBox(width: 6),
            const Text(
              '0 votos',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Memorias
        _buildSectionTitle('Memorias'),
        Container(
          height: 100,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          color: Colors.white.withOpacity(0.1),
          child: const Center(
            child: Text(
              'Fotos/Vídeos de eventos...',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Imágenes de perfil
        _buildSectionTitle('Imágenes del perfil'),
        Container(
          height: 100,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          color: Colors.white.withOpacity(0.1),
          child: const Center(
            child: Text(
              'Mostrar las imágenes de su galería...',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Fila de botones de acción en el draggable
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          iconPath: 'assets/agregar-usuario.svg',
          label: 'Invítale a un Plan',
          onTap: () {
            // Acción para invitar a un plan
          },
        ),
        const SizedBox(width: 16),
        _buildActionButton(
          iconPath: 'assets/mensaje.svg',
          label: null, // Sin etiqueta
          onTap: () {
            showGeneralDialog(
              context: context,
              barrierDismissible: true,
              barrierLabel: 'Cerrar',
              barrierColor: Colors.transparent,
              transitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (_, __, ___) => UserInfoInsideChat(
                chatPartnerId: widget.userId,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String iconPath,
    String? label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              iconPath,
              width: 24,
              height: 24,
              color: Colors.white,
            ),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
