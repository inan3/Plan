// attendance_managing.dart

import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// Para generar QR
import 'package:qr_flutter/qr_flutter.dart';
// Para escanear QR
import 'package:mobile_scanner/mobile_scanner.dart';

/// ---------------------------------------------------------------------------
/// Funciones de backend (Firestore) para manejar estado de check-in en un plan.
/// ---------------------------------------------------------------------------
class AttendanceManaging {
  /// Inicia el check-in de un plan:
  /// - Activa la bandera "checkInActive" en Firestore.
  /// - Genera un nuevo código de 6 caracteres y lo guarda en "checkInCode".
  /// - Guarda un timestamp para controlar la vigencia del código.
  static Future<void> startCheckIn(String planId) async {
    final planRef = FirebaseFirestore.instance.collection('plans').doc(planId);
    final randomCode = _generateRandomCode(6);

    final planDoc = await planRef.get();
    if (planDoc.data()?['special_plan'] == 1) return;

    await planRef.set({
      'checkInActive': true,
      'checkInCode': randomCode,
      'checkInCodeTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Finaliza el check-in de un plan (desactiva la bandera en Firestore).
  static Future<void> finalizeCheckIn(String planId) async {
    final planRef = FirebaseFirestore.instance.collection('plans').doc(planId);
    final planDoc = await planRef.get();
    if (planDoc.data()?['special_plan'] == 1) return;
    await planRef.set({
      'checkInActive': false,
    }, SetOptions(merge: true));
  }

  /// Rota (actualiza) el código de check-in para un plan cada 60s (o cuando quieras).
  /// - Genera un nuevo código de 6 caracteres y lo guarda.
  /// - Actualiza "checkInCodeTimestamp".
  static Future<void> rotateCheckInCode(String planId) async {
    final planRef = FirebaseFirestore.instance.collection('plans').doc(planId);
    final randomCode = _generateRandomCode(6);
    final planDoc = await planRef.get();
    if (planDoc.data()?['special_plan'] == 1) return;
    await planRef.set({
      'checkInCode': randomCode,
      'checkInCodeTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Cuando un usuario ingresa o escanea un código válido, se confirma su asistencia:
  /// - Se añade su uid a "checkedInUsers" en el documento del plan.
  static Future<void> confirmAttendance(String planId, String uid) async {
    final db = FirebaseFirestore.instance;
    final planRef = db.collection('plans').doc(planId);

    await db.runTransaction((transaction) async {
      final planSnap = await transaction.get(planRef);
      if (!planSnap.exists) return;

      final data = planSnap.data() as Map<String, dynamic>;
      if (data['special_plan'] == 1) return;

      final List<dynamic> checked = data['checkedInUsers'] ?? [];
      if (checked.contains(uid)) return;

      // Añade el usuario al plan
      transaction.update(planRef, {
        'checkedInUsers': FieldValue.arrayUnion([uid]),
      });

      final creatorId = data['createdBy']?.toString() ?? '';
      if (creatorId.isEmpty) return;

      final creatorRef = db.collection('users').doc(creatorId);
      final creatorSnap = await transaction.get(creatorRef);
      if (!creatorSnap.exists) return;

      final creatorData = creatorSnap.data() as Map<String, dynamic>;
      int total = creatorData['total_participants_until_now'] ?? 0;
      int maxPart = creatorData['max_participants_in_one_plan'] ?? 0;

      total += 1;
      final currentParticipants = checked.length + 1;
      if (currentParticipants > maxPart) {
        maxPart = currentParticipants;
      }

      transaction.update(creatorRef, {
        'total_participants_until_now': total,
        'max_participants_in_one_plan': maxPart,
      });
    });
  }

  /// Verifica si el código que el usuario ingresa/escanea corresponde
  /// al código actual del plan en Firestore.
  /// Retorna `true` si coincide, `false` en caso contrario.
  static Future<bool> validateCode(String planId, String code) async {
    final planRef = FirebaseFirestore.instance.collection('plans').doc(planId);
    final doc = await planRef.get();
    if (!doc.exists) return false;

    if (doc.data()?['special_plan'] == 1) return false;

    final data = doc.data()!;
    final currentCode = data['checkInCode'] ?? '';
    final isActive = data['checkInActive'] ?? false;
    if (!isActive) return false;

    return (code.trim().toLowerCase() == currentCode.toString().toLowerCase());
  }

  /// Genera un código aleatorio alfanumérico de longitud [length].
  static String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)])
        .join();
  }
}

/// ---------------------------------------------------------------------------
/// Widget para uso del creador del plan: Muestra el código QR rotatorio y
/// un contador que se reinicia cada 60s. También un botón para "Finalizar Check-in".
/// ---------------------------------------------------------------------------
class CheckInCreatorScreen extends StatefulWidget {
  final String planId;
  const CheckInCreatorScreen({Key? key, required this.planId})
      : super(key: key);

  @override
  State<CheckInCreatorScreen> createState() => _CheckInCreatorScreenState();
}

class _CheckInCreatorScreenState extends State<CheckInCreatorScreen> {
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Aquí podrías forzar AttendanceManaging.startCheckIn(widget.planId);
    // si quisieras asegurarte de que el check-in está activo.

    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Inicia/reinicia el contador de 60s y rota el código al expirar.
  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_secondsLeft <= 1) {
        // Se agotó el tiempo => rotamos el código en Firestore.
        await AttendanceManaging.rotateCheckInCode(widget.planId);

        // Reiniciamos el contador a 60.
        setState(() => _secondsLeft = 60);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Check-in para asistentes"),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('plans')
            .doc(widget.planId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: Text("Plan no existe"));
          }

          final code = data['checkInCode'] ?? '';
          final isActive = data['checkInActive'] ?? false;
          if (!isActive) {
            return const Center(
              child: Text(
                "El check-in no está activo.\nPresiona atrás para iniciar.",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          // Calculamos porcentaje para la barra circular.
          final double percentage = (_secondsLeft / 60);

          return Column(
            children: [
              const SizedBox(height: 16),
              // Contador circular
              _buildCircularCountdown(percentage, _secondsLeft),
              const SizedBox(height: 16),

              // QR dinámico
              Expanded(
                child: Center(
                  child: code.isNotEmpty
                      ? QrImageView(
                          data: code,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                        )
                      : const Text(
                          "Generando código...",
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 8),

              // Código alfanumérico en texto
              Text(
                code,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),

              // Botón Finalizar
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor:
                        Colors.white, // <-- color del texto e iconos
                  ),
                  onPressed: () async {
                    await AttendanceManaging.finalizeCheckIn(widget.planId);
                    Navigator.pop(context);
                  },
                  child: const Text("Finalizar Check-in"),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Construye el widget de cuenta regresiva circular.
  Widget _buildCircularCountdown(double percentage, int secondsLeft) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: percentage,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
            strokeWidth: 6,
          ),
          Center(
            child: Text(
              secondsLeft.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Widget para uso de PARTICIPANTES: Escanea el QR o introduce el código manual.
/// ---------------------------------------------------------------------------
class CheckInParticipantScreen extends StatefulWidget {
  final String planId;
  const CheckInParticipantScreen({Key? key, required this.planId})
      : super(key: key);

  @override
  State<CheckInParticipantScreen> createState() =>
      _CheckInParticipantScreenState();
}

class _CheckInParticipantScreenState extends State<CheckInParticipantScreen> {
  final TextEditingController _manualCodeCtrl = TextEditingController();
  String _errorMsg = ''; // para mostrar "Código incorrecto" cuando falle
  bool _scannedOk = false;

  // Controlador para mobile_scanner
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Confirmar asistencia"),
        backgroundColor: Colors.black87,
      ),
      backgroundColor: Colors.black87,
      body: Column(
        children: [
          // Mitad superior: escáner
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black,
              child: _buildQrScanner(),
            ),
          ),
          // Mitad inferior: introducir código manual
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.black54,
              ),
              child: Column(
                children: [
                  const Text(
                    "Si no puedes escanear el código QR,\ningrésalo manualmente:",
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _manualCodeCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      fillColor: Colors.white10,
                      filled: true,
                      hintText: "Código alfanumérico",
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_errorMsg.isNotEmpty)
                    Text(
                      _errorMsg,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _onSubmitManualCode,
                    child: const Text("Validar código"),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  /// Construye el escáner de QR usando [mobile_scanner].
  Widget _buildQrScanner() {
    return MobileScanner(
      controller: _scannerController,
      onDetect: (capture) async {
        final barcode = capture.barcodes.first;
        final String? code = barcode.rawValue;
        if (code != null && !_scannedOk) {
          // Evitamos escanear repetidamente
          setState(() => _scannedOk = true);
          await _processCode(code);
        }
      },
    );
  }

  /// Al pulsar "Validar código" manual
  Future<void> _onSubmitManualCode() async {
    final code = _manualCodeCtrl.text.trim();
    if (code.isEmpty) return;
    await _processCode(code);
  }

  /// Procesa el código (ya sea escaneado o introducido manualmente).
  Future<void> _processCode(String code) async {
    final isValid = await AttendanceManaging.validateCode(widget.planId, code);
    if (!isValid) {
      setState(() {
        _errorMsg = "El código es incorrecto o el check-in no está activo.";
        _scannedOk = false;
      });
      return;
    }

    // Confirmamos asistencia
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      setState(() {
        _errorMsg = "No se encontró un usuario logueado.";
        _scannedOk = false;
      });
      return;
    }

    await AttendanceManaging.confirmAttendance(widget.planId, uid);

    // Regresamos a la pantalla anterior
    if (!mounted) return;
    Navigator.pop(context);
  }
}

/// ---------------------------------------------------------------------------
/// Ejemplo de widget que podrías incrustar en tu FrostedPlanDialog, para
/// mostrar o bien un botón "Confirmar asistencia" (participante) o
/// "Iniciar Check-in" (creador) o "Finalizar Check-in", etc.,
/// según el estado del plan en Firestore.
/// ---------------------------------------------------------------------------
class CheckInActionArea extends StatelessWidget {
  final String planId;
  final bool isCreator;
  final bool alreadyCheckedIn; // El usuario actual ya confirmó su asistencia

  const CheckInActionArea({
    Key? key,
    required this.planId,
    required this.isCreator,
    required this.alreadyCheckedIn,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('plans')
          .doc(planId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        final checkInActive = data['checkInActive'] ?? false;

        // 1) Si YA hice check-in, muestro el mensaje de confirmación
        if (alreadyCheckedIn) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: const [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 32),
                SizedBox(height: 8),
                Text(
                  "Tu asistencia se ha confirmado con éxito.\n¡Disfruta del evento!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }

        // 2) Si soy el creador
        if (isCreator) {
          // 2A) No está activo => botón "Iniciar"
          if (!checkInActive) {
            return _buildButton(
              label: "Iniciar Check-in",
              color: Colors.green,
              onTap: () async {
                await AttendanceManaging.startCheckIn(planId);

                if (context.mounted) {
                  // Después de iniciar, voy a la pantalla QR
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CheckInCreatorScreen(planId: planId),
                    ),
                  );
                }
              },
            );
          } else {
            // 2B) Está activo => Botón "Ver Check-in" + "Finalizar"
            return Column(
              children: [
                _buildButton(
                  label: "Ver Check-in (QR)",
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CheckInCreatorScreen(planId: planId),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildButton(
                  label: "Finalizar Check-in",
                  color: Colors.redAccent,
                  onTap: () async {
                    await AttendanceManaging.finalizeCheckIn(planId);
                  },
                ),
              ],
            );
          }
        }

        // 3) Soy participante
        else {
          // Si checkInActive = false => no hago nada
          if (!checkInActive) {
            return const SizedBox.shrink();
          } else {
            // Botón "Confirmar asistencia"
            return _buildButton(
              label: "Confirmar asistencia",
              color: Colors.orangeAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckInParticipantScreen(planId: planId),
                  ),
                );
              },
            );
          }
        }
      },
    );
  }

  Widget _buildButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}
