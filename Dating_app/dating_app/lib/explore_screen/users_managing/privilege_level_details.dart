import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrivilegeLevelDetails extends StatefulWidget {
  final String userId;

  const PrivilegeLevelDetails({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<PrivilegeLevelDetails> createState() => _PrivilegeLevelDetailsState();
}

class _PrivilegeLevelDetailsState extends State<PrivilegeLevelDetails> {
  String _privilegeInfo = "Cargando nivel de privilegios...";

  // Variables obtenidas de Firestore.
  int _totalCreatedPlans = 0;
  int _maxParticipantsInOnePlan = 0;
  int _totalParticipantsUntilNow = 0;

  // Valores máximos para la interfaz (solo para mostrar barras de progreso).
  final int _maxPlans = 5;
  final int _maxParticipantsPerPlan = 5;
  final int _maxTotalParticipants = 20;

  // Nivel de privilegio actual del usuario.
  String _privilegeLevel = "Básico";

  // Obtener el icono según el nivel
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

        // Cargamos los campos desde Firestore.
        _totalCreatedPlans = data['total_created_plans'] ?? 0;
        _maxParticipantsInOnePlan = data['max_participants_in_one_plan'] ?? 0;
        _totalParticipantsUntilNow = data['total_participants_until_now'] ?? 0;

        // Leemos el nivel actual en la BD (por si ya lo tuviera).
        _privilegeLevel = (data['privilegeLevel'] ?? 'Básico').toString();

        // Tras cargar los datos, verificamos si debe cambiar de nivel.
        await _checkAndUpdatePrivilegeLevel();

        // Volvemos a leer el nivel (por si se actualizó).
        final updatedDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        final updatedData = updatedDoc.data() ?? {};
        _privilegeLevel = (updatedData['privilegeLevel'] ?? 'Básico').toString();

        setState(() {
          // Mantenemos la misma variable para el texto, pero ya contiene la frase completa
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

  /// Verifica y actualiza el nivel de privilegios según las condiciones.
  Future<void> _checkAndUpdatePrivilegeLevel() async {
    // Lógica de salto de nivel:
    // Premium -> si 5 planes, máx. 5 participantes, total 20
    // Golden  -> si 50 planes, máx. 50 participantes, total 2000
    // VIP     -> si 500 planes, máx. 500 participantes, total 10000

    String newLevel = _privilegeLevel; // Mantenemos el nivel actual

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

    // Si hay un cambio de nivel, actualizamos en Firestore.
    if (newLevel != _privilegeLevel) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'privilegeLevel': newLevel});
    }
  }

  Widget _buildProgressIndicator({
    required double progress,
    Color? color,
    double width = 100,
    double height = 10,
    double borderRadius = 5,
  }) {
    return Container(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: const Color.fromARGB(255, 108, 104, 104),
          valueColor: AlwaysStoppedAnimation<Color>(
            progress == 0 ? Colors.transparent : (color ?? Colors.blue),
          ),
        ),
      ),
    );
  }

  // Íconos de ejemplo en la interfaz
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
    return Column(
      children: [
        // Fila 1: Íconos SVG
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Center(child: _buildTriangleIcon()),
            ),
            Expanded(
              child: Center(child: _buildSquareIcon()),
            ),
            Expanded(
              child: Center(child: _buildPentagonIcon()),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Fila 2: Barras de progreso
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Center(
                child: _buildProgressIndicator(
                  progress: _maxPlans == 0
                      ? 0
                      : _totalCreatedPlans / _maxPlans,
                  color: Colors.white,
                  width: 80,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: _buildProgressIndicator(
                  progress: _maxParticipantsPerPlan == 0
                      ? 0
                      : _maxParticipantsInOnePlan / _maxParticipantsPerPlan,
                  color: Colors.white,
                  width: 80,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: _buildProgressIndicator(
                  progress: _maxTotalParticipants == 0
                      ? 0
                      : _totalParticipantsUntilNow / _maxTotalParticipants,
                  color: Colors.white,
                  width: 80,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        // Fila 3: Textos
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

  @override
  Widget build(BuildContext context) {
    // Popup con fondo degradado.
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(16),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1) Mostramos el icono del nivel actual
                Image.asset(
                  _privilegeIcon,
                  width: 60,
                  height: 60,
                ),
                // 2) Justo debajo, el texto con el nivel (tamaño reducido a 10)
                const SizedBox(height: 8),
                Text(
                  _privilegeInfo, // Ej: "Nivel de privilegios: Premium"
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
                // Separación y luego las barras de progreso
                const SizedBox(height: 14),
                _buildIndicatorsRow(),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Cerrar el popup
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
