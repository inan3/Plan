// lib/explore_screen/users_managing/privilege_level_details.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrivilegeLevelDetails extends StatefulWidget {
  final String userId; // ID del usuario para buscar sus datos en Firestore

  const PrivilegeLevelDetails({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<PrivilegeLevelDetails> createState() => _PrivilegeLevelDetailsState();

  // MÉTODO ESTÁTICO para actualizar estadísticas de suscripciones
  static Future<void> updateSubscriptionStats(String userId, int currentPlanParticipants) async {
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userDocRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      int totalParticipants = data['total_participants_until_now'] ?? 0;
      int maxParticipants = data['max_participants_in_one_plan'] ?? 0;

      // Incrementamos el total de participantes en 1
      totalParticipants += 1;

      // Actualizamos el máximo si el plan actual supera el anterior
      if (currentPlanParticipants > maxParticipants) {
        maxParticipants = currentPlanParticipants;
      }

      transaction.update(userDocRef, {
        'total_participants_until_now': totalParticipants,
        'max_participants_in_one_plan': maxParticipants,
      });
    });
    print("Estadísticas de suscripción actualizadas correctamente para userId=$userId");
  }
}

class _PrivilegeLevelDetailsState extends State<PrivilegeLevelDetails> {
  String _privilegeInfo = "Cargando nivel de privilegios..."; // Texto inicial mientras carga

  // Variables que se obtienen de Firestore
  int _totalCreatedPlans = 0; // Planes creados por el usuario
  int _maxParticipantsInOnePlan = 0; // Máximo de participantes en un solo plan
  int _totalParticipantsUntilNow = 0; // Total de participantes acumulados

  // Valores máximos para las barras de progreso (solo para la interfaz)
  final int _maxPlans = 5;
  final int _maxParticipantsPerPlan = 5;
  final int _maxTotalParticipants = 20;

  // Nivel de privilegio actual del usuario
  String _privilegeLevel = "Básico";

  // Selecciona el ícono según el nivel de privilegio
  String get _privilegeIcon {
    switch (_privilegeLevel.toLowerCase()) {
      case "premium":
        return "assets/icono-usuario-premium.png";
      case "golden":
        return "assets/icono-usuario-golden.png";
      case "vip":
        return "assets/icono-usuario-vip.png";
      default:
        return "assets/icono-usuario-basico.png";
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPrivilegeInfo(); // Carga los datos al iniciar
  }

  // Carga los datos del usuario desde Firestore
  Future<void> _loadPrivilegeInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};

        // Leemos cada estadística
        _totalCreatedPlans = data['total_created_plans'] ?? 0;
        _maxParticipantsInOnePlan = data['max_participants_in_one_plan'] ?? 0;
        _totalParticipantsUntilNow = data['total_participants_until_now'] ?? 0;

        // Leemos el nivel actual
        _privilegeLevel = (data['privilegeLevel'] ?? 'Básico').toString();

        // Verificamos si el nivel debe cambiar
        await _checkAndUpdatePrivilegeLevel();

        // Volvemos a leer en caso de que se actualizara
        final updatedDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        final updatedData = updatedDoc.data() ?? {};
        _privilegeLevel = (updatedData['privilegeLevel'] ?? 'Básico').toString();

        setState(() {
          _privilegeInfo = "Nivel de privilegios: $_privilegeLevel";
        });
      } else {
        setState(() {
          _privilegeInfo = "No se encontró información de privilegios.";
        });
      }
    } catch (e) {
      setState(() {
        _privilegeInfo = "Error al cargar: $e";
      });
    }
  }

  // Verifica y actualiza el nivel de privilegios según las condiciones
  Future<void> _checkAndUpdatePrivilegeLevel() async {
    String newLevel = "premium";//_privilegeLevel;

    // Condiciones de ejemplo para subir de nivel
    if (_totalCreatedPlans >= 500 &&
        _maxParticipantsInOnePlan >= 500 &&
        _totalParticipantsUntilNow >= 10000) {
      newLevel = "VIP";
    } else if (_totalCreatedPlans >= 50 &&
        _maxParticipantsInOnePlan >= 50 &&
        _totalParticipantsUntilNow >= 2000) {
      newLevel = "Golden";
    } else if (_totalCreatedPlans >= 5 &&
        _maxParticipantsInOnePlan >= 5 &&
        _totalParticipantsUntilNow >= 20) {
      newLevel = "Premium";
    } else {
      newLevel = "Básico";
    }

    // Si el nivel cambió, lo actualizamos en Firestore
    if (newLevel != _privilegeLevel) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'privilegeLevel': newLevel});
      print("Nivel actualizado de $_privilegeLevel a $newLevel");
    }
  }

  // Construye una barra de progreso con el valor actual dentro (centrado) y el máximo afuera
  Widget _buildProgressWithText({
    required int currentValue,
    required int maxValue,
    double width = 80,
    double height = 10,
    double borderRadius = 5,
    Color? progressColor,
  }) {
    final double progress =
        maxValue == 0 ? 0 : (currentValue / maxValue).clamp(0.0, 1.0);
    const double estimatedTextWidth = 20.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color.fromARGB(255, 108, 104, 104),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress == 0
                          ? Colors.transparent
                          : (progressColor ?? Colors.white),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -2,
                left: (width * progress - estimatedTextWidth)
                    .clamp(0.0, double.infinity),
                child: Container(
                  width: estimatedTextWidth,
                  alignment: Alignment.center,
                  child: Text(
                    "$currentValue",
                    style: TextStyle(
                      color: progress == 0 ? Colors.white : Colors.black,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          "$maxValue",
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildTriangleIcon() {
    // Ícono para "Planes creados"
    return SvgPicture.asset(
      'assets/icono-calendario.svg',
      width: 30,
      height: 30,
      color: Colors.white,
    );
  }

  Widget _buildSquareIcon() {
    // Ícono para "Máx. participantes en un plan"
    return SvgPicture.asset(
      'assets/icono-seguidores.svg',
      width: 30,
      height: 30,
      color: Colors.white,
    );
  }

  Widget _buildPentagonIcon() {
    // Ícono para "Total de participantes reunidos"
    return SvgPicture.asset(
      'assets/icono-seguidores.svg',
      width: 30,
      height: 30,
      color: Colors.white,
    );
  }

  /// Construye la fila de íconos y barras de progreso
  Widget _buildIndicatorsRow() {
    return Column(
      children: [
        // Fila 1: Íconos
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: Center(child: _buildTriangleIcon())),
            Expanded(child: Center(child: _buildSquareIcon())),
            Expanded(child: Center(child: _buildPentagonIcon())),
          ],
        ),
        const SizedBox(height: 10),
        // Fila 2: Barras de progreso
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Center(
                child: _buildProgressWithText(
                  currentValue: _totalCreatedPlans,
                  maxValue: _maxPlans,
                  progressColor: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: _buildProgressWithText(
                  currentValue: _maxParticipantsInOnePlan,
                  maxValue: _maxParticipantsPerPlan,
                  progressColor: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: _buildProgressWithText(
                  currentValue: _totalParticipantsUntilNow,
                  maxValue: _maxTotalParticipants,
                  progressColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        // Fila 3: Textos descriptivos
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    "Planes creados",
                    style: TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    "Máx. participantes",
                    style: TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    "en un plan",
                    style: TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    "Total de participantes",
                    style: TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    "reunidos hasta ahora",
                    style: TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Construye el popup con los indicadores
  @override
  Widget build(BuildContext context) {
    // Popup con fondo degradado y desenfoque
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85, // 85% del ancho
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 13, 32, 53),
                        Color.fromARGB(255, 72, 38, 38),
                        Color(0xFF12232E),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícono del nivel actual
                Image.asset(
                  _privilegeIcon,
                  width: 60,
                  height: 60,
                ),
                const SizedBox(height: 8),
                // Texto del nivel
                Text(
                  _privilegeInfo,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                // Indicadores (íconos, barras, textos)
                _buildIndicatorsRow(),
                const SizedBox(height: 16),
                // Botón para cerrar
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Cierra el popup
                  },
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
