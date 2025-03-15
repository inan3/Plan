// lib/explore_screen/users_managing/privilege_level_details.dart

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
  // Valores simulados. Reemplázalos con la lógica real de consulta.
  int _createdPlans = 2; // Ejemplo: el usuario ha creado 2 planes
  int _maxParticipantsInOnePlan = 3; // Ejemplo: en su plan más concurrido se han reunido 3 participantes
  int _totalParticipants = 10; // Ejemplo: en total se han reunido 10 participantes en todos sus planes

  // Máximos para un usuario básico
  final int _maxPlans = 5;
  final int _maxParticipantsPerPlan = 5;
  final int _maxTotalParticipants = 20;

  @override
  void initState() {
    super.initState();
    _loadPrivilegeInfo();
    // Aquí podrías disparar funciones que consulten Firestore y actualicen _createdPlans, _maxParticipantsInOnePlan y _totalParticipants.
  }

  Future<void> _loadPrivilegeInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        final level = data['privilegeLevel'] ?? 'Básico';
        setState(() {
          _privilegeInfo = "Nivel de privilegios: $level";
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

  Widget _buildProgressIndicator({required double progress, Color? color}) {
    return LinearProgressIndicator(
      value: progress,
      backgroundColor: Colors.grey[300],
      valueColor: AlwaysStoppedAnimation<Color>(
        progress == 0 ? Colors.transparent : (color ?? Colors.blue),
      ),
    );
  }

  // Widget para dibujar el triángulo (sólo bordes)
  Widget _buildTriangleIcon() {
    return CustomPaint(
      size: const Size(30, 30),
      painter: TrianglePainter(),
    );
  }

  // Widget para dibujar el cuadrado (sólo bordes)
  Widget _buildSquareIcon() {
    return CustomPaint(
      size: const Size(30, 30),
      painter: SquarePainter(),
    );
  }

  // Widget para dibujar el pentágono (sólo bordes)
  Widget _buildPentagonIcon() {
    return CustomPaint(
      size: const Size(30, 30),
      painter: PentagonPainter(),
    );
  }

  Widget _buildIndicatorsRow() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      // Triángulo para "Planes creados"
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTriangleIcon(),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: _buildProgressIndicator(
                progress: _createdPlans / _maxPlans,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Planes creados",
              style: TextStyle(color: Colors.white, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      // Cuadrado para "Máx. participantes en un plan"
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSquareIcon(),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: _buildProgressIndicator(
                progress: _maxParticipantsInOnePlan / _maxParticipantsPerPlan,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Máx. participantes\nen un plan",
              style: TextStyle(color: Colors.white, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      // Pentágono para "Total de participantes reunidos hasta ahora"
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPentagonIcon(),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: _buildProgressIndicator(
                progress: _totalParticipants / _maxTotalParticipants,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Total de participantes\nreunidos hasta ahora",
              style: TextStyle(color: Colors.white, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ],
  );
}


  @override
  Widget build(BuildContext context) {
    // Contenedor semitransparente con blur de fondo (efecto "frosted glass")
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(16),
            color: Colors.black.withOpacity(0.3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícono de privilegio básico en la parte superior
                SvgPicture.asset(
                  'assets/icono-usuario-basico.svg',
                  width: 60,
                  height: 60,
                  color: Colors.white,
                ),
                const SizedBox(height: 14),
                // Fila de indicadores
                _buildIndicatorsRow(),
                const SizedBox(height: 16),
                Text(
                  'Detalles de privilegios',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _privilegeInfo,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
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

// CustomPainter para el triángulo (sólo bordes)
class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final Path path = Path();
    path.moveTo(size.width / 2, 0); // vértice superior central
    path.lineTo(0, size.height); // esquina inferior izquierda
    path.lineTo(size.width, size.height); // esquina inferior derecha
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// CustomPainter para el cuadrado (sólo bordes)
class SquarePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// CustomPainter para el pentágono (sólo bordes)
class PentagonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final Path path = Path();
    final double w = size.width;
    final double h = size.height;
    path.moveTo(w * 0.5, 0); // vértice superior central
    path.lineTo(w, h * 0.38); // vértice superior derecho
    path.lineTo(w * 0.8, h); // vértice inferior derecho
    path.lineTo(w * 0.2, h); // vértice inferior izquierdo
    path.lineTo(0, h * 0.38); // vértice superior izquierdo
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
