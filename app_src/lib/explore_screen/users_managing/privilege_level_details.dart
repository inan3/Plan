// lib/explore_screen/users_managing/privilege_level_details.dart

import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrivilegeLevelDetails extends StatefulWidget {
  final String userId; // ID del usuario para buscar sus datos en Firestore
  final bool
      showAllInfo; // controla si se muestran las indicaciones y las insignias

  const PrivilegeLevelDetails({
    Key? key,
    required this.userId,
    this.showAllInfo = true,
  }) : super(key: key);

  // MÉTODO ESTÁTICO para actualizar estadísticas de suscripciones
  // (ahora SÓLO sube total_participants_until_now y max_participants_in_one_plan,
  //  partiendo de la idea de que "currentPlanParticipants" = .length de checkedInUsers)
  static Future<void> updateSubscriptionStats(
    String userId,
    int currentPlanParticipants,
  ) async {
    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(userId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDocRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      int totalParticipants = data['total_participants_until_now'] ?? 0;
      int maxParticipants = data['max_participants_in_one_plan'] ?? 0;

      // Sube el total en 1 si un nuevo usuario confirmó
      totalParticipants += 1;

      // Actualizamos el "maxParticipants" si el plan actual supera el anterior
      if (currentPlanParticipants > maxParticipants) {
        maxParticipants = currentPlanParticipants;
      }

      transaction.update(userDocRef, {
        'total_participants_until_now': totalParticipants,
        'max_participants_in_one_plan': maxParticipants,
      });
    });
    // OJO: Ya no tocamos total_created_plans aquí,
    // porque se recalcula en user_info_check.
  }

  @override
  State<PrivilegeLevelDetails> createState() => _PrivilegeLevelDetailsState();
}

class _PrivilegeLevelDetailsState extends State<PrivilegeLevelDetails> {
  String _privilegeInfo = "Cargando nivel de privilegios...";

  // Estadísticas Firestore
  int _totalCreatedPlans = 0;
  int _maxParticipantsInOnePlan = 0;
  int _totalParticipantsUntilNow = 0;

  static final List<_LevelRequirement> _requirements = [
    _LevelRequirement("Básico", 0, 0, 0),
    _LevelRequirement("Premium", 5, 5, 20),
    _LevelRequirement("Golden", 50, 50, 2000),
    _LevelRequirement("VIP", 500, 500, 10000),
  ];

  String _privilegeLevel = "Básico";

  String get _privilegeIcon {
    final normalized = _privilegeLevel.toLowerCase().replaceAll('á', 'a');
    switch (normalized) {
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
    _loadPrivilegeInfo();
  }

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
        final me = FirebaseAuth.instance.currentUser;
        if (me != null && me.uid == widget.userId) {
          await _checkAndUpdatePrivilegeLevel(); // solo si es su propio perfil
        }

        // Volvemos a leer en caso de que se actualizara
        final updatedDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        final updatedData = updatedDoc.data() ?? {};
        _privilegeLevel =
            (updatedData['privilegeLevel'] ?? 'Básico').toString();

        setState(() {
          _privilegeInfo = _privilegeLevel;
        });
      } else {
        setState(() {
          _privilegeInfo = Localizations.localeOf(context).languageCode == 'en'
              ? 'No privilege information found.'
              : 'No se encontró información de privilegios.';
        });
      }
    } catch (e) {
      setState(() {
        _privilegeInfo = Localizations.localeOf(context).languageCode == 'en'
            ? 'Error loading: $e'
            : 'Error al cargar: $e';
      });
    }
  }

  Future<void> _checkAndUpdatePrivilegeLevel() async {
    String newLevel = _privilegeLevel;

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
    }
  }

  // ---------- UI ---------- //

  Widget _buildIndicatorsRow() {
    // Ajustamos dinámicamente el ancho del progress bar para evitar overflows
    final double screenWidth = MediaQuery.of(context).size.width;
    // Reservamos un 90 % del ancho total y restamos el espacio del padding interno
    final double barWidthCandidate = (screenWidth * 0.90) / 3 - 36;
    final double w = math.max(60, barWidthCandidate);

    final int currentIndex = _mapPrivilegeToIndex(_privilegeLevel);
    final int? nextIndex = _getNextLevelIndex(currentIndex);
    final _LevelRequirement thresholdReq = nextIndex != null
        ? _requirements[nextIndex]
        : _requirements[currentIndex];

    final int maxPlansBar = thresholdReq.minPlans;
    final int maxMaxPartsBar = thresholdReq.minMaxParts;
    final int maxTotalPartsBar = thresholdReq.minTotalParts;

    Widget createdPlansText = Column(
      children: const [
        Text(
          "Planes creados",
          style: TextStyle(color: Colors.white, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );

    Widget maxPartsText = Column(
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
    );

    Widget totalPartsText = Column(
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
    );

    Widget firstColumn = SizedBox(
      width: w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTriangleIcon(),
          const SizedBox(height: 8),
          _buildProgressWithText(
            currentValue: _totalCreatedPlans,
            maxValue: maxPlansBar,
            width: w,
          ),
          const SizedBox(height: 4),
          createdPlansText,
        ],
      ),
    );

    Widget secondColumn = SizedBox(
      width: w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSquareIcon(),
          const SizedBox(height: 8),
          _buildProgressWithText(
            currentValue: _maxParticipantsInOnePlan,
            maxValue: maxMaxPartsBar,
            width: w,
          ),
          const SizedBox(height: 4),
          maxPartsText,
        ],
      ),
    );

    Widget thirdColumn = SizedBox(
      width: w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPentagonIcon(),
          const SizedBox(height: 8),
          _buildProgressWithText(
            currentValue: _totalParticipantsUntilNow,
            maxValue: maxTotalPartsBar,
            width: w,
          ),
          const SizedBox(height: 4),
          totalPartsText,
        ],
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        firstColumn,
        secondColumn,
        thirdColumn,
      ],
    );
  }

  Widget _buildNextLevelHint() {
    final normalized = _privilegeLevel.toLowerCase().replaceAll('á', 'a');

    late final String message;
    switch (normalized) {
      case 'premium':
        message =
            'Crea 50 planes, logra 50 participantes en un solo plan y reúne 2000 participantes en total para pasar al nivel de privilegio Golden.';
        break;
      case 'golden':
        message =
            'Crea 500 planes, logra 500 participantes en un solo plan y reúne 10000 participantes en total para pasar al nivel de privilegio VIP.';
        break;
      case 'vip':
        message = 'Estás disfrutando del nivel de privilegio VIP.';
        break;
      default:
        message =
            'Crea 5 planes, logra 5 participantes en un solo plan y reúne 20 participantes en total para pasar al nivel de privilegio Premium.';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 14),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icono-informacion.svg',
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

  Widget _buildPrivilegeIconsRow() {
    final currentIndex = _mapPrivilegeToIndex(_privilegeLevel);
    final iconPaths = [
      "assets/icono-usuario-basico.png",
      "assets/icono-usuario-premium.png",
      "assets/icono-usuario-golden.png",
      "assets/icono-usuario-vip.png",
    ];
    final iconNames = ["Básico", "Premium", "Golden", "VIP"];

    Widget arrow =
        const Icon(Icons.arrow_forward, color: Colors.grey, size: 20);

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

  final _grayscaleFilter = const ColorFilter.matrix([
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
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

  void _showPrivilegeInfoPopup(String levelName) {
    String titleText;
    String contentText;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    switch (levelName.toLowerCase()) {
      case 'premium':
        titleText = isEn ? 'Premium Level' : 'Nivel Premium';
        contentText = isEn
            ? 'The Premium level is the second. To reach Golden:\n- Create 50 plans.\n- Up to 50 participants in a plan.\n- 2000 participants in total.'
            : 'El nivel Premium es el segundo nivel. Para pasar al siguiente nivel de Golden:\n- Crear 50 planes.\n- Máximo de 50 participantes en un plan.\n- 2000 participantes en total.';
        break;
      case 'golden':
        titleText = isEn ? 'Golden Level' : 'Nivel Golden';
        contentText = isEn
            ? 'The Golden level is the penultimate. To reach VIP:\n- Create 500 plans.\n- Reach 500 participants in one plan.\n- 10000 participants in total.'
            : 'El nivel Golden es el penúltimo nivel. Para pasar a VIP:\n- Crear 500 planes.\n- Alcanzar 500 participantes en un plan.\n- 10000 participantes en total.';
        break;
      case 'vip':
        titleText = isEn ? 'VIP Level' : 'Nivel VIP';
        contentText =
            isEn ? 'This is the highest level with no limits.' : 'Este es el nivel más alto, sin límites.';
        break;
      default:
        titleText = isEn ? 'Basic Level' : 'Nivel Básico';
        contentText = isEn
            ? 'The Basic level is the lowest. To reach Premium:\n- Create 5 plans.\n- Reach 5 participants in one plan.\n- 20 participants in total.'
            : 'El nivel Básico es el más bajo. Para pasar a Premium:\n- Crear 5 planes.\n- Alcanzar 5 participantes en un plan.\n- 20 participantes en total.';
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
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
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
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            "$maxValue",
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
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

  // Reutilizamos el mismo icono para el pentágono por simplicidad
  Widget _buildPentagonIcon() {
    return SvgPicture.asset(
      'assets/icono-seguidores.svg',
      width: 30,
      height: 30,
      color: Colors.white,
    );
  }

  int _mapPrivilegeToIndex(String level) {
    final normalized = level.toLowerCase().replaceAll('á', 'a');
    switch (normalized) {
      case 'premium':
        return 1;
      case 'golden':
        return 2;
      case 'vip':
        return 3;
      default:
        return 0; // "Básico"
    }
  }

  int? _getNextLevelIndex(int currentLevelIndex) {
    if (currentLevelIndex >= _requirements.length - 1) {
      return null;
    }
    return currentLevelIndex + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
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
                      Image.asset(_privilegeIcon, width: 60, height: 60),
                      const SizedBox(height: 8),
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
                      if (widget.showAllInfo) ...[
                        const SizedBox(height: 12),
                        _buildNextLevelHint(),
                        const SizedBox(height: 16),
                        _buildPrivilegeIconsRow(),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
