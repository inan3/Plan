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

  // MÉTODO ESTÁTICO para actualizar estadísticas de suscripciones
  static Future<void> updateSubscriptionStats(
    String userId,
    int currentPlanParticipants,
  ) async {
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

  @override
  State<PrivilegeLevelDetails> createState() => _PrivilegeLevelDetailsState();
}

class _PrivilegeLevelDetailsState extends State<PrivilegeLevelDetails> {
  String _privilegeInfo = "Cargando nivel de privilegios..."; // Texto inicial mientras carga

  // ========================
  //   Estadísticas Firestore
  // ========================
  int _totalCreatedPlans = 0;         // Planes creados por el usuario
  int _maxParticipantsInOnePlan = 0;  // Máx. de participantes en un plan
  int _totalParticipantsUntilNow = 0; // Total de participantes acumulados

  // Requisitos de cada nivel
  static final List<_LevelRequirement> _requirements = [
    _LevelRequirement("Básico",   0,     0,     0),
    _LevelRequirement("Premium",  5,     5,     20),
    _LevelRequirement("Golden",   50,    50,    2000),
    _LevelRequirement("VIP",      500,   500,   10000),
  ];

  // Nivel de privilegio actual del usuario
  String _privilegeLevel = "Básico";

  // Ícono principal (PNG) según el nivel de privilegio
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

  // Lee estadísticas y nivel de Firestore
  Future<void> _loadPrivilegeInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        _totalCreatedPlans = data['total_created_plans'] ?? 0;
        _maxParticipantsInOnePlan = data['max_participants_in_one_plan'] ?? 0;
        _totalParticipantsUntilNow = data['total_participants_until_now'] ?? 0;

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
          _privilegeInfo = "Nivel $_privilegeLevel";
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

  // Condiciones para subir de nivel
  Future<void> _checkAndUpdatePrivilegeLevel() async {
    String newLevel = _privilegeLevel; // actual

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

    if (newLevel != _privilegeLevel) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'privilegeLevel': newLevel});
      print("Nivel actualizado de $_privilegeLevel a $newLevel");
    }
  }

  // ============================
  //   BARRAS DE PROGRESO
  // ============================

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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color.fromARGB(255, 108, 104, 104),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress == 0
                        ? Colors.transparent
                        : (progressColor ?? Colors.white),
                  ),
                  minHeight: height,
                ),
              ),
              Text(
                "$currentValue",
                style: TextStyle(
                  color: progress == 0 ? Colors.white : Colors.black,
                  fontSize: 10,
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
    return SvgPicture.asset(
      'assets/icono-calendario.svg',
      width: 30,
      height: 30,
      color: Colors.white,
    );
  }

  Widget _buildSquareIcon() {
    return SvgPicture.asset(
      'assets/icono-seguidores.svg',
      width: 30,
      height: 30,
      color: Colors.white,
    );
  }

  Widget _buildPentagonIcon() {
    return SvgPicture.asset(
      'assets/icono-seguidores.svg',
      width: 30,
      height: 30,
      color: Colors.white,
    );
  }

  Widget _buildIndicatorsRow() {
    // Calculamos el umbral según el siguiente nivel (o el actual si ya es VIP)
    final int currentIndex = _mapPrivilegeToIndex(_privilegeLevel);
    final int? nextIndex = _getNextLevelIndex(currentIndex);
    final _LevelRequirement thresholdReq = nextIndex != null
        ? _requirements[nextIndex]
        : _requirements[currentIndex];

    final int maxPlansBar = thresholdReq.minPlans;
    final int maxMaxPartsBar = thresholdReq.minMaxParts;
    final int maxTotalPartsBar = thresholdReq.minTotalParts;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: Center(child: _buildTriangleIcon())),
            Expanded(child: Center(child: _buildSquareIcon())),
            Expanded(child: Center(child: _buildPentagonIcon())),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Center(
                child: _buildProgressWithText(
                  currentValue: _totalCreatedPlans,
                  maxValue: maxPlansBar,
                  progressColor: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: _buildProgressWithText(
                  currentValue: _maxParticipantsInOnePlan,
                  maxValue: maxMaxPartsBar,
                  progressColor: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: _buildProgressWithText(
                  currentValue: _totalParticipantsUntilNow,
                  maxValue: maxTotalPartsBar,
                  progressColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
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

  int _mapPrivilegeToIndex(String level) {
    switch (level.toLowerCase()) {
      case 'premium':
        return 1;
      case 'golden':
        return 2;
      case 'vip':
        return 3;
      default:
        return 0; // "básico"
    }
  }

  int? _getNextLevelIndex(int currentLevelIndex) {
    if (currentLevelIndex >= _requirements.length - 1) {
      return null;
    }
    return currentLevelIndex + 1;
  }

  Widget _buildNextLevelHint() {
    final int currentIndex = _mapPrivilegeToIndex(_privilegeLevel);
    final int? nextIndex = _getNextLevelIndex(currentIndex);
    if (nextIndex == null) {
      // Ya estás en VIP
      return Column(
        children: const [
          SizedBox(height: 8),
          Text(
            "¡Felicidades! Ya estás en el nivel más alto de privilegios.",
            style: TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final _LevelRequirement nextReq = _requirements[nextIndex];

    int neededPlans = nextReq.minPlans - _totalCreatedPlans;
    if (neededPlans < 0) neededPlans = 0;

    bool needMaxParts = (_maxParticipantsInOnePlan < nextReq.minMaxParts);
    int neededMaxPartsThreshold = nextReq.minMaxParts;

    int neededTotalParts = nextReq.minTotalParts - _totalParticipantsUntilNow;
    if (neededTotalParts < 0) neededTotalParts = 0;

    List<String> parts = [];
    if (neededPlans > 0) {
      parts.add("crear $neededPlans plan${neededPlans > 1 ? 'es' : ''}");
    }
    if (needMaxParts) {
      parts.add("un plan que supere el umbral máximo de $neededMaxPartsThreshold participantes");
    }
    if (neededTotalParts > 0) {
      parts.add("reunir $neededTotalParts participantes más en tus siguientes planes");
    }

    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }

    String missing;
    if (parts.length == 1) {
      missing = parts.first;
    } else if (parts.length == 2) {
      missing = "${parts[0]} y ${parts[1]}";
    } else {
      missing = "${parts[0]}, ${parts[1]} y ${parts[2]}";
    }

    final String nextLevelName = nextReq.name;
    String message = "Te falta $missing para pasar al nivel de privilegio $nextLevelName";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 14),
      child: Row(
        children: [
          SvgPicture.asset(
            "assets/icono-informacion.svg",
            width: 20,
            height: 20,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color.fromARGB(255, 181, 181, 181),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===============================
  //   ÍCONOS DE PRIVILEGIO + Popup
  // ===============================

  // Para escala de grises (icónos bloqueados)
  final _grayscaleFilter = const ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  Widget _buildPrivilegeIconButton({
    required String pngPath,
    required bool isUnlocked,
    required String levelName,
  }) {
    return InkWell(
      onTap: () {
        _showPrivilegeInfoPopup(levelName);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ColorFiltered(
            colorFilter: isUnlocked
                ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                : _grayscaleFilter,
            child: Image.asset(
              pngPath,
              width: 40,
              height: 40,
            ),
          ),
          if (!isUnlocked)
            Positioned(
              right: -2,
              bottom: -2,
              child: SvgPicture.asset(
                'assets/icono-candado.svg',
                width: 18,
                height: 18,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  /// Muestra el popup “frosted glass” con texto en blanco según el nivel
  void _showPrivilegeInfoPopup(String levelName) {
    String titleText;
    String contentText;

    switch (levelName.toLowerCase()) {
      case 'premium':
        titleText = "Nivel Premium";
        contentText = "El nivel Premium es el segundo nivel. "
            "Para pasar al siguiente nivel de Golden debes alcanzar los siguientes objetivos:\n"
            "- Crear 50 planes.\n"
            "- Alcanzar el máximo de 50 participantes en un solo plan.\n"
            "- Reunir un total de 2000 participantes sumando todos tus planes.";
        break;
      case 'golden':
        titleText = "Nivel Golden";
        contentText = "El nivel Golden es el penúltimo nivel. "
            "Para pasar al siguiente nivel de VIP debes alcanzar los siguientes objetivos:\n"
            "- Crear 500 planes.\n"
            "- Alcanzar el máximo de 500 participantes en un solo plan.\n"
            "- Reunir un total de 10000 participantes sumando todos tus planes.";
        break;
      case 'vip':
        titleText = "Nivel VIP";
        contentText = "El nivel VIP es el nivel más alto. Este nivel te permite crear planes sin límite y planes de pago.";
        break;
      default: // Básico
        titleText = "Nivel Básico";
        contentText = "El nivel básico es el más bajo de todos. "
            "Para pasar al siguiente nivel de Premium debes alcanzar los siguientes objetivos:\n"
            "- Crear 5 planes.\n"
            "- Alcanzar el máximo de 5 participantes en un solo plan.\n"
            "- Reunir un total de 20 participantes sumando todos tus planes.";
        break;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 88, 88, 88).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titleText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      contentText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          "Cerrar",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrivilegeIconsRow() {
    final currentIndex = _mapPrivilegeToIndex(_privilegeLevel);

    final iconPaths = [
      "assets/icono-usuario-basico.png",
      "assets/icono-usuario-premium.png",
      "assets/icono-usuario-golden.png",
      "assets/icono-usuario-vip.png",
    ];
    final iconNames = ["Básico", "Premium", "Golden", "VIP"];

    Widget arrow = const Icon(Icons.arrow_forward, color: Colors.grey, size: 20);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPrivilegeIconButton(
          pngPath: iconPaths[0],
          isUnlocked: 0 <= currentIndex,
          levelName: iconNames[0],
        ),
        arrow,
        _buildPrivilegeIconButton(
          pngPath: iconPaths[1],
          isUnlocked: 1 <= currentIndex,
          levelName: iconNames[1],
        ),
        arrow,
        _buildPrivilegeIconButton(
          pngPath: iconPaths[2],
          isUnlocked: 2 <= currentIndex,
          levelName: iconNames[2],
        ),
        arrow,
        _buildPrivilegeIconButton(
          pngPath: iconPaths[3],
          isUnlocked: 3 <= currentIndex,
          levelName: iconNames[3],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // A) Fondo difuminado y tamaño dinámico
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.95,
                maxHeight: MediaQuery.of(context).size.height * 0.90,
              ),
              child: SingleChildScrollView(
                child: Container(
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
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ícono principal del nivel actual (PNG)
                      Image.asset(
                        _privilegeIcon,
                        width: 60,
                        height: 60,
                      ),
                      const SizedBox(height: 8),

                      // Texto de estado del nivel de privilegios
                      Text(
                        _privilegeInfo,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),

                      _buildIndicatorsRow(),
                      const SizedBox(height: 12),

                      _buildNextLevelHint(),
                      const SizedBox(height: 16),

                      _buildPrivilegeIconsRow(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // B) Botón "X" para cerrar
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelRequirement {
  final String name;          
  final int minPlans;         
  final int minMaxParts;      
  final int minTotalParts;    

  const _LevelRequirement(
    this.name,
    this.minPlans,
    this.minMaxParts,
    this.minTotalParts,
  );
}
