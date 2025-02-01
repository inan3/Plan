import 'dart:ui'; // Para BackdropFilter e ImageFilter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para copiar ID
import '../../main/colors.dart'; // Donde tengas tu AppColors.blue u otros

// -----------------------------------------------------------------------------
// 1) MODELO DE PLAN
// -----------------------------------------------------------------------------
class PlanModel {
  final String id;
  final String type;
  final String description;
  final int? minAge;
  final int? maxAge;
  final int? maxParticipants;
  final String location;
  final DateTime date;
  final DateTime createdAt;
  final String createdBy;

  PlanModel({
    required this.id,
    required this.type,
    required this.description,
    required this.minAge,
    required this.maxAge,
    required this.maxParticipants,
    required this.location,
    required this.date,
    required this.createdAt,
    required this.createdBy,
  });

  // Maneja parseo de Timestamp/String
  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate(); 
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  // Formatear fecha
  String formattedDate(DateTime d) => "${d.day}/${d.month}/${d.year}";

  factory PlanModel.fromMap(Map<String, dynamic> map) {
    return PlanModel(
      id: map['id'] ?? '',
      type: map['type'] ?? 'Plan sin tipo',
      description: map['description'] ?? '',
      minAge: map['minAge'],
      maxAge: map['maxAge'],
      maxParticipants: map['maxParticipants'],
      location: map['location'] ?? '',
      date: _parseDate(map['date']),
      createdAt: _parseDate(map['createdAt']),
      createdBy: map['createdBy'] ?? '',
    );
  }
}

// -----------------------------------------------------------------------------
// 2) PANTALLA PRINCIPAL: UserInfoCheck
// -----------------------------------------------------------------------------
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
    // Dejar barra de estado transparente e íconos claros
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
    activePlans.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return activePlans;
  }

  // 2.2) Obtener participantes
  Future<List<Map<String, dynamic>>> _fetchAllPlanParticipants(PlanModel plan) async {
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

  // 2.3) Muestra pop-up “frosted glass”
  void _showPlanDetailsFrosted(BuildContext context, PlanModel plan) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',  // Evita excepción
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: _FrostedPlanDialog(
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
          // Fondo con imagen del usuario
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
                  child: Text('No se encontró el usuario', style: TextStyle(color: Colors.white)),
                );
              }

              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              final String photoUrl = data['photoUrl'] ?? '';
              return Positioned.fill(
                child: (photoUrl.isNotEmpty)
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey),
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
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Draggable Sheet con la info del usuario
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

                          // Info básica (nombre, edad, etc.)
                          _buildUserInfo(),
                          // Secciones Extra
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
            child: Text('No se encontró info de usuario',
                style: TextStyle(color: Colors.white)),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final String name = data['name'] ?? 'Sin nombre';
        final String age = data['age'] ?? '0';
        final String gender = data['gender'] ?? 'No especificado';
        final String interest = data['interest'] ?? 'N/A';
        final String height = data['height'] ?? 'N/A';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$name, $age',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 8),
              // Ciudad placeholder
              Row(
                children: const [
                  Icon(Icons.location_on, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Ciudad desconocida',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Interés: $interest',
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 4),
              Text('Género: $gender',
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 4),
              Text('Altura: $height',
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
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
                child: Text('No hay planes activos.',
                    style: TextStyle(color: Colors.white70)),
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
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: ListTile(
                    title: Text(plan.type,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        )),
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
            const Text('0 votos',
                style: TextStyle(color: Colors.white, fontSize: 16)),
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
}

// -----------------------------------------------------------------------------
// 3) DIÁLOGO PERSONALIZADO CON EFECTO FROSTED
// SEPARA "Creador del Plan" y "Participantes"
// -----------------------------------------------------------------------------
class _FrostedPlanDialog extends StatefulWidget {
  final PlanModel plan;
  final Future<List<Map<String, dynamic>>> Function(PlanModel plan) fetchParticipants;

  const _FrostedPlanDialog({
    Key? key,
    required this.plan,
    required this.fetchParticipants,
  }) : super(key: key);

  @override
  State<_FrostedPlanDialog> createState() => _FrostedPlanDialogState();
}

class _FrostedPlanDialogState extends State<_FrostedPlanDialog> {
  late Future<List<Map<String, dynamic>>> _futureParticipants;

  @override
  void initState() {
    super.initState();
    _futureParticipants = widget.fetchParticipants(widget.plan);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final screenSize = MediaQuery.of(context).size;

    return SafeArea(
      child: Stack(
        children: [
          // Fondo difuminado
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.grey.withOpacity(0.3)),
            ),
          ),
          // Tarjeta blanca en el centro
          Center(
            child: Container(
              width: screenSize.width * 0.85,
              constraints: BoxConstraints(
                maxHeight: screenSize.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Material(
                color: Colors.transparent,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Título
                      Text(
                        "Detalles del Plan: ${plan.type}",
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ID + copiar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "ID del Plan: ${plan.id}",
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.blue),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: plan.id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('ID copiado al portapapeles'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Datos
                      Text("Descripción: ${plan.description}",
                          style: const TextStyle(color: Colors.black)),
                      Text("Restricción de Edad: ${plan.minAge} - ${plan.maxAge} años",
                          style: const TextStyle(color: Colors.black)),
                      Text("Máximo Participantes: ${plan.maxParticipants ?? 'Sin límite'}",
                          style: const TextStyle(color: Colors.black)),
                      Text("Ubicación: ${plan.location}",
                          style: const TextStyle(color: Colors.black)),
                      Text(
                        "Fecha del Evento: ${plan.formattedDate(plan.date)}",
                        style: const TextStyle(color: Colors.black),
                      ),
                      Text(
                        "Creado el: ${plan.formattedDate(plan.createdAt)}",
                        style: const TextStyle(color: Colors.black),
                      ),
                      const SizedBox(height: 10),

                      // FutureBuilder: Creador + Participantes
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _futureParticipants,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.black),
                            );
                          }
                          final all = snapshot.data ?? [];
                          if (all.isEmpty) {
                            return const Text(
                              'No hay participantes en este plan.',
                              style: TextStyle(color: Colors.black),
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
                              // Encabezado "Creador del Plan:"
                              if (creator.isNotEmpty) ...[
                                const Text(
                                  "Creador del Plan:",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildCreatorTile(creator),
                                const SizedBox(height: 10),
                              ],

                              // Encabezado "Participantes:"
                              const Text(
                                "Participantes:",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),

                              if (participants.isEmpty)
                                const Text(
                                  "No hay participantes en este plan.",
                                  style: TextStyle(color: Colors.black),
                                )
                              else
                                ...participants.map(_buildParticipantTile).toList(),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Botón Cerrar
                      Align(
                        alignment: Alignment.bottomRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cerrar", style: TextStyle(color: Colors.blue)),
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
      title: Text('$name, $age', style: const TextStyle(color: Colors.black)),
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
      title: Text('$name, $age', style: const TextStyle(color: Colors.black)),
    );
  }
}
