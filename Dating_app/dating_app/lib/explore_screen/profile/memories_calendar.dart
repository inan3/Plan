import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../main/colors.dart';
import '../../models/plan_model.dart';
import 'plan_memories_screen.dart'; // Asegúrate de importar tu pantalla de memorias

class MemoriesCalendar extends StatefulWidget {
  final String userId;

  /// Callback opcional que se llama cuando se pulsa un día con al menos un plan.
  /// Ahora recibe directamente un PlanModel en lugar de un Map.
  final void Function(PlanModel plan)? onPlanSelected;

  const MemoriesCalendar({
    Key? key,
    required this.userId,
    this.onPlanSelected,
  }) : super(key: key);

  @override
  _MemoriesCalendarState createState() => _MemoriesCalendarState();
}

class _MemoriesCalendarState extends State<MemoriesCalendar> {
  late DateTime _currentMonth;
  bool _localeInitialized = false;

  /// Mapa que guarda, para cada fecha (YYYY-MM-DD), la lista de [PlanModel].
  /// Ejemplo:
  /// { 
  ///   "2023-09-15": [
  ///       PlanModel(id: "xxx", iconAsset: "assets/icono-cafe.svg", ...),
  ///       ...
  ///   ] 
  /// }
  Map<String, List<PlanModel>> _plansByDate = {};

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es', null).then((_) {
      setState(() {
        _localeInitialized = true;
        _currentMonth = DateTime.now();
      });
      _fetchUserPlans();
    });
  }

  /// Carga los planes en Firestore filtrando por 'createdBy' = widget.userId.
  /// Luego convierte cada doc en un PlanModel y lo guarda en _plansByDate.
  Future<void> _fetchUserPlans() async {
    try {
      final querySnap = await FirebaseFirestore.instance
          .collection('plans')
          .where('createdBy', isEqualTo: widget.userId)
          .get();

      final Map<String, List<PlanModel>> tempMap = {};

      for (final doc in querySnap.docs) {
        final data = doc.data();

        // Usamos "start_timestamp" como campo de fecha
        if (data['start_timestamp'] == null) continue;

        // Convertimos a PlanModel
        PlanModel plan = PlanModel.fromMap(data);

        // Si el doc no trae id en 'map', forzamos a que plan.id sea doc.id.
        if (plan.id.isEmpty) {
          plan = _copyPlanWithNewId(plan, doc.id);
        }

        final DateTime? planDate = plan.startTimestamp;
        if (planDate == null) continue;

        final String dateKey = DateFormat('yyyy-MM-dd').format(planDate);

        tempMap.putIfAbsent(dateKey, () => []);
        tempMap[dateKey]!.add(plan);
      }

      setState(() {
        _plansByDate = tempMap;
      });
    } catch (e) {
      debugPrint("[_fetchUserPlans] Error: $e");
    }
  }

  /// Crea un nuevo PlanModel con el mismo contenido que [original],
  /// pero con el id sobreescrito por [newId].
  ///
  /// Así evitamos modificar plan_model.dart ni usar copyWith().
  PlanModel _copyPlanWithNewId(PlanModel original, String newId) {
    return PlanModel(
      id: newId,
      type: original.type,
      description: original.description,
      minAge: original.minAge,
      maxAge: original.maxAge,
      maxParticipants: original.maxParticipants,
      location: original.location,
      latitude: original.latitude,
      longitude: original.longitude,
      startTimestamp: original.startTimestamp,
      finishTimestamp: original.finishTimestamp,
      createdBy: original.createdBy,
      creatorName: original.creatorName,
      creatorProfilePic: original.creatorProfilePic,
      createdAt: original.createdAt,
      backgroundImage: original.backgroundImage,
      visibility: original.visibility,
      iconAsset: original.iconAsset,
      participants: original.participants,
      likes: original.likes,
      special_plan: original.special_plan,
      images: original.images,
      originalImages: original.originalImages,
      videoUrl: original.videoUrl,
      creatorProfilePrivacy: original.creatorProfilePrivacy,
    );
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  /// Al pulsar un día, revisamos si hay planes. Si no, popup "sin memorias".
  /// Si sí hay planes, se distingue entre planes futuros y planes caducados.
  /// Si [widget.onPlanSelected] no es null, se llama pasando el primer plan.
  void _onDayTapped(DateTime date) {
  final dateKey = DateFormat('yyyy-MM-dd').format(date);
  final dayPlans = _plansByDate[dateKey];
  final String formattedDate = DateFormat.yMMMMd('es').format(date);

  if (dayPlans == null || dayPlans.isEmpty) {
    // No hay planes => popup "sin memorias".
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(formattedDate),
        content: const Text("No hay memorias para este día."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  } else {
    // Tomamos el primer plan de ese día (o podrías mostrar lista)
    final PlanModel plan = dayPlans.first;

    // En lugar de callback o popup => abrimos la nueva pantalla:
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanMemoriesScreen(
          plan: plan,
          fetchParticipants: (PlanModel p) async {
            // O la misma lógica que usas en SubscribedPlansScreen / MyPlansScreen
            // Para ejemplo:
            final List<Map<String, dynamic>> participants = [];
            final subsSnap = await FirebaseFirestore.instance
                .collection('subscriptions')
                .where('id', isEqualTo: p.id)
                .get();

            for (var sDoc in subsSnap.docs) {
              final sData = sDoc.data();
              final userId = sData['userId'];
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get();
              if (userDoc.exists && userDoc.data() != null) {
                final uData = userDoc.data()!;
                participants.add({
                  'uid': userId,
                  'name': uData['name'] ?? 'Sin nombre',
                  'age': uData['age']?.toString() ?? '',
                  'photoUrl': uData['photoUrl'] ?? uData['profilePic'] ?? '',
                  'isCreator': (p.createdBy == userId),
                });
              }
            }
            return participants;
          },
        ),
      ),
    );
  }
}


  /// Popup para planes futuros (aún no celebrados).
  void _showUpcomingPlanPopup(DateTime date, List<PlanModel> dayPlans) {
    final String formattedDate = DateFormat.yMMMMd('es').format(date);
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text("$formattedDate - Próximo Plan"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: dayPlans.map((plan) {
              final String planId = plan.id;
              final String? icon = plan.iconAsset; // plan.iconAsset no es parte oficial, agrégalo a tu PlanModel si deseas
              return ListTile(
                leading: _buildPlanIcon(icon ?? '', plan.startTimestamp),
                title: Text("Plan ID: $planId"),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cerrar"),
            ),
          ],
        );
      },
    );
  }

  /// Popup para planes caducados
  void _showExpiredPlanPopup(DateTime date, List<PlanModel> dayPlans) {
    final String formattedDate = DateFormat.yMMMMd('es').format(date);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color.fromARGB(0, 255, 255, 255),
        insetPadding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Memorias',
                style: GoogleFonts.roboto(
                  color: AppColors.white,
                  fontSize: 26,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(20.0),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  constraints: const BoxConstraints(maxHeight: 500),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 150,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Text(
                            "Fotos y videos subidos...",
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Cerrar"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (!_localeInitialized) return const SizedBox.shrink();
    final String monthYear = DateFormat.yMMMM('es').format(_currentMonth);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousMonth,
            icon: const Icon(Icons.chevron_left, color: Colors.white),
          ),
          Text(
            // Capitaliza la primera letra
            monthYear[0].toUpperCase() + monthYear.substring(1),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysOfWeekRow() {
    final daysOfWeek = ["Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do"];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: daysOfWeek.map((day) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: Text(
                day,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarDays() {
    if (!_localeInitialized) {
      return const Expanded(child: SizedBox.shrink());
    }
    final firstDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth =
        DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);

    List<Widget> dayWidgets = [];
    // Rellenar huecos de la primera semana (si el mes no empieza en lunes)
    for (int i = 1; i < firstWeekday; i++) {
      dayWidgets.add(Container());
    }
    // Agregar los días del mes
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      dayWidgets.add(_buildDayCell(day, date));
    }
    return Expanded(
      child: GridView.count(
        crossAxisCount: 7,
        children: dayWidgets,
      ),
    );
  }

  Widget _buildDayCell(int dayNumber, DateTime date) {
    final bool isToday = (date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day);

    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final dayPlans = _plansByDate[dateKey];
    final bool hasPlans = (dayPlans != null && dayPlans.isNotEmpty);

    String iconPath = '';
    DateTime? planDate;
    if (hasPlans) {
      final PlanModel plan = dayPlans.first;
      iconPath = plan.iconAsset ?? '';
      planDate = plan.startTimestamp;
    }

    return GestureDetector(
      onTap: () => _onDayTapped(date),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
          color: isToday ? Colors.blue.shade100 : Colors.white,
        ),
        child: hasPlans
            ? Stack(
                children: [
                  // Número del día en la esquina superior izquierda (más pequeño)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Text(
                      "$dayNumber",
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: isToday ? Colors.blue : Colors.black87,
                      ),
                    ),
                  ),
                  // Icono centrado con color según si ya pasó o no
                  Center(
                    child: (iconPath.isNotEmpty)
                        ? _buildPlanIcon(iconPath, planDate)
                        : const Icon(Icons.event),
                  ),
                ],
              )
            : Center(
                child: Text(
                  "$dayNumber",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.blue : Colors.black87,
                  ),
                ),
              ),
      ),
    );
  }

  /// Construye el ícono del plan; si la fecha del plan es futura se pinta de AppColors.blue, si ya pasó se pinta de negro.
  Widget _buildPlanIcon(String iconPath, DateTime? planDate) {
    final Color iconColor;
    if (planDate != null && planDate.isAfter(DateTime.now())) {
      iconColor = AppColors.blue;
    } else {
      iconColor = Colors.black;
    }

    if (iconPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        iconPath,
        width: 24,
        height: 24,
        color: iconColor,
        placeholderBuilder: (ctx) => const Icon(Icons.event),
      );
    } else {
      return Image.asset(
        iconPath,
        width: 24,
        height: 24,
        color: iconColor,
        errorBuilder: (_, __, ___) => const Icon(Icons.event),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double side = MediaQuery.of(context).size.width * 0.95;
    return Center(
      child: Container(
        width: side,
        height: side * 1.3,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
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
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                "Memorias",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            _buildHeader(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _buildDaysOfWeekRow(),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildCalendarDays(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
