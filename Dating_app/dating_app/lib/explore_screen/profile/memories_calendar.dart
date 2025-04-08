import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../main/colors.dart';

class MemoriesCalendar extends StatefulWidget {
  final String userId;

  const MemoriesCalendar({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  _MemoriesCalendarState createState() => _MemoriesCalendarState();
}

class _MemoriesCalendarState extends State<MemoriesCalendar> {
  late DateTime _currentMonth;
  bool _localeInitialized = false;

  /// Mapa que guarda, para cada fecha (YYYY-MM-DD), la lista de planes.
  /// Ejemplo:
  /// { "2023-09-15": [ {"planId": "xxx", "iconAsset": "assets/icono-cafe.svg", "planDate": DateTime(...)}, ... ] }
  Map<String, List<Map<String, dynamic>>> _plansByDate = {};

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
  Future<void> _fetchUserPlans() async {
    try {
      final querySnap = await FirebaseFirestore.instance
          .collection('plans')
          .where('createdBy', isEqualTo: widget.userId)
          .get();

      final Map<String, List<Map<String, dynamic>>> tempMap = {};

      for (final doc in querySnap.docs) {
        final data = doc.data();

        // Usamos "start_timestamp" como campo de fecha
        if (data['start_timestamp'] == null) continue;

        final Timestamp timestamp = data['start_timestamp'] as Timestamp;
        final DateTime planDate = timestamp.toDate();

        final String dateKey = DateFormat('yyyy-MM-dd').format(planDate);
        final String? iconAsset = data['iconAsset'];

        final planInfo = {
          'planId': doc.id,
          'iconAsset': iconAsset ?? '',
          'planDate': planDate,
        };

        tempMap.putIfAbsent(dateKey, () => []);
        tempMap[dateKey]!.add(planInfo);
      }

      setState(() {
        _plansByDate = tempMap;
      });
    } catch (e) {
      debugPrint("[_fetchUserPlans] Error: $e");
    }
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

  /// Al pulsar un día, se decide qué popup mostrar según si el plan ya pasó o no.
  void _onDayTapped(DateTime date) {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final dayPlans = _plansByDate[dateKey];
    final String formattedDate = DateFormat.yMMMMd('es').format(date);

    if (dayPlans == null || dayPlans.isEmpty) {
      // No hay planes para ese día.
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(formattedDate),
          content: const Text(
              "El usuario no tiene memorias para este día en concreto."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cerrar"),
            ),
          ],
        ),
      );
    } else {
      // Usamos el primer plan para determinar si es futuro o ya pasado.
      final DateTime planDate = dayPlans.first['planDate'] as DateTime;
      if (planDate.isAfter(DateTime.now())) {
        // Plan futuro: mostramos el popup de plan por venir.
        _showUpcomingPlanPopup(date, dayPlans);
      } else {
        // Plan caducado: mostramos el popup con la UI de memorias.
        _showExpiredPlanPopup(date, dayPlans);
      }
    }
  }

  /// Popup para planes futuros (aún no celebrados).
  void _showUpcomingPlanPopup(
      DateTime date, List<Map<String, dynamic>> dayPlans) {
    final String formattedDate = DateFormat.yMMMMd('es').format(date);
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text("$formattedDate - Próximo Plan"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: dayPlans.map((plan) {
              final String icon = plan['iconAsset'] as String? ?? '';
              final String planId = plan['planId'] as String? ?? '';
              return ListTile(
                leading: _buildPlanIcon(icon, plan['planDate'] as DateTime),
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

  /// Popup para planes caducados: se mostrará una UI similar a la de my_plans_screen.dart,
  /// donde se presentarán fotos y videos subidos desde la fecha de inicio del plan.
  void _showExpiredPlanPopup(
      DateTime date, List<Map<String, dynamic>> dayPlans) {
    final String formattedDate = DateFormat.yMMMMd('es').format(date);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        // Color transparente para permitir ver el difuminado
        backgroundColor: const Color.fromARGB(0, 255, 255, 255),
        // Margen alrededor del diálogo
        insetPadding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Memorias', // Texto superior
                style: GoogleFonts.roboto(
                  color: AppColors.white,
                  fontSize: 26,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Efecto Frosted Glass
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
                      // Aquí, tu lista de fotos y videos
                      Text(
                        "$formattedDate",
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Placeholder donde colocarás tus items multimedia
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

                      // Botón "Cerrar"
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
    for (int i = 1; i < firstWeekday; i++) {
      dayWidgets.add(Container());
    }
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

    String firstIcon = '';
    DateTime? planDate;
    if (hasPlans) {
      final planInfo = dayPlans.first;
      firstIcon = planInfo['iconAsset'] as String? ?? '';
      planDate = planInfo['planDate'] as DateTime?;
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
                    child: (firstIcon.isNotEmpty)
                        ? _buildPlanIcon(firstIcon, planDate)
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
