import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../utils/plans_list.dart';
import '../../../models/plan_model.dart';
import '../../plan_creation/meeting_location_screen.dart';
import '../../plan_creation/new_plan_creation_screen.dart';
import '../../../main/colors.dart';

/// ***************************************************************************
/// CONSTANTES DE ANCHOS Y ALTOS FIJOS (SIN MEDIAQUERY)
/// ***************************************************************************
const double kMainPopupWidth = 500;
const double kMainPopupPadding = 20;

const double kNewPlanPadding = 20;

const double kPlanTypeSectionWidth = 320;
const double kPlanTypeDropdownWidth = 310; // unused
const double kPlanTypeDropdownHeight = 365; // unused

const double kDateTimeSectionWidth = 300; // unused
const double kLocationContainerHeight = 240;

/// ***************************************************************************
/// CLASE PRINCIPAL InviteUsersToPlanScreen
/// ***************************************************************************
class InviteUsersToPlanScreen {
  static void showPopup(BuildContext context, String invitedUserId) {
    showGeneralDialog(
      context: context,
      barrierLabel: "Invitar a un Plan",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) {
        return _InvitePlanPopup(invitedUserId: invitedUserId);
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: anim1,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// ***************************************************************************
/// _InvitePlanPopup: Popup con botones "Existente" / "Nuevo"
/// ***************************************************************************
class _InvitePlanPopup extends StatefulWidget {
  final String invitedUserId;
  const _InvitePlanPopup({Key? key, required this.invitedUserId})
      : super(key: key);

  @override
  State<_InvitePlanPopup> createState() => _InvitePlanPopupState();
}

class _InvitePlanPopupState extends State<_InvitePlanPopup> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 300,
          padding: EdgeInsets.all(kMainPopupPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(255, 13, 32, 53),
                Color.fromARGB(255, 72, 38, 38),
                Color(0xFF12232E),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Invítale a un plan",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  minimumSize: const Size(100, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _onInviteExistingPlan,
                child: const Text(
                  "Existente",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  minimumSize: const Size(120, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _onInviteNewPlan,
                child: const Text(
                  "Nuevo",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onInviteExistingPlan() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final activePlans = await _fetchActivePlans(currentUser.uid);
    if (activePlans.isEmpty) {
      _showNoPlansPopup();
    } else {
      _showExistingPlansPopup(activePlans);
    }
  }

  void _showNoPlansPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text("No tienes planes creados aún..."),
          content: const Text("¿Creamos uno nuevo?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _onInviteNewPlan();
              },
              child: const Text("Aceptar"),
            ),
          ],
        );
      },
    );
  }

  void _showExistingPlansPopup(List<PlanModel> activePlans) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: 400,
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
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const Text(
                  "Selecciona un plan",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Inter-Regular',
                    decoration: TextDecoration.none,
                  ),
                ),
                const Divider(color: Colors.white54),
                Expanded(
                  child: ListView.builder(
                    itemCount: activePlans.length,
                    itemBuilder: (context, index) {
                      final plan = activePlans[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              color: Colors.white.withOpacity(0.15),
                              child: Material(color: Colors.transparent, child: ListTile(
                                title: Text(
                                  plan.type,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  "Creado el: ${plan.formattedDate(plan.createdAt)}",
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                onTap: () {
                                  showGeneralDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    barrierLabel: "Confirmar invitación",
                                    barrierColor: Colors.black54,
                                    transitionDuration:
                                        const Duration(milliseconds: 300),
                                    pageBuilder: (context, animation,
                                        secondaryAnimation) {
                                      return const SizedBox();
                                    },
                                    transitionBuilder:
                                        (context, anim1, anim2, child) {
                                      return FadeTransition(
                                        opacity: CurvedAnimation(
                                          parent: anim1,
                                          curve: Curves.easeOut,
                                        ),
                                        child: ScaleTransition(
                                          scale: CurvedAnimation(
                                            parent: anim1,
                                            curve: Curves.easeOutBack,
                                          ),
                                          child: Center(
                                            child: _FrostedConfirmDialog(
                                              plan: plan,
                                              onConfirm: () {
                                                Navigator.pop(context);
                                                Navigator.pop(context);
                                                _inviteUserToExistingPlan(plan);
                                              },
                                              onCancel: () {
                                                Navigator.pop(context);
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              )),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _inviteUserToExistingPlan(PlanModel plan) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final invitedUid = widget.invitedUserId;

    await _sendInvitationNotification(
      senderUid: currentUser.uid,
      receiverUid: invitedUid,
      planId: plan.id,
      planType: plan.type,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Has invitado a tu plan: ${plan.type}")),
    );
  }

  void _onInviteNewPlan() {
    Navigator.pop(context);
    _showNewPlanForInvitation(context, widget.invitedUserId);
  }
}

/// ***************************************************************************
/// POPUP DE CREACIÓN DE PLAN PRIVADO (SIN MEDIAQUERY)
/// ***************************************************************************
void _showNewPlanForInvitation(BuildContext context, String invitedUserId) {
  showGeneralDialog(
    context: context,
    barrierLabel: "Nuevo Plan Privado",
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 500),
    // CAMBIO PRINCIPAL: Usamos SafeArea + Align + AnimatedPadding en vez de Center.
    pageBuilder: (ctx, anim1, anim2) {
      return SafeArea(
        child: Align(
          alignment: Alignment.center,
          child: Material(
            type: MaterialType.transparency,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              // Este padding se ajusta cuando aparece el teclado
              padding:
                  EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Container(
                  width: MediaQuery.of(ctx).size.width * 0.9,
                  height: MediaQuery.of(ctx).size.height * 0.9,
                  padding: const EdgeInsets.all(kNewPlanPadding),
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
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: _NewPlanInviteContent(invitedUserId: invitedUserId),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutBack,
          ),
          child: child,
        ),
      );
    },
  );
}

/// ***************************************************************************
/// _NewPlanInviteContent: Contiene la lógica de creación de plan
/// ***************************************************************************
class _NewPlanInviteContent extends StatefulWidget {
  final String invitedUserId;
  const _NewPlanInviteContent({Key? key, required this.invitedUserId})
      : super(key: key);

  @override
  State<_NewPlanInviteContent> createState() => _NewPlanInviteContentState();
}

class _NewPlanInviteContentState extends State<_NewPlanInviteContent> {
  // ========= Tipo de plan =========
  String? _selectedPlan;
  String? _customPlan;
  String? _selectedIconAsset;
  IconData? _selectedIconData;
  bool _isDropdownOpen = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  static const double _planButtonWidth = 260.0;
  static const double _dropdownWidth = 320.0;
  static const double _dropdownOffsetY = 44.0;
  static const double _dropdownOffsetX = 12;

  // ========= Fecha/hora =========
  bool _allDay = false;
  bool _includeEndDate = false;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  // ========= Ubicación =========
  String? _location;
  double? _latitude;
  double? _longitude;
  Future<BitmapDescriptor>? _markerIconFuture;

  // ========= Descripción =========
  String? _planDescription;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset('assets/plan-sin-fondo.png', height: 70),
              ),
              const SizedBox(height: 20),
              const Center(
              child: Text(
                "¡Crea tu Plan Privado e Invita!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ===== TIPO DE PLAN =====
            _buildTypeOfPlan(),

            const SizedBox(height: 20),

            // ===== FECHA Y HORA =====
            _buildDateTimeSection(),

            const SizedBox(height: 20),

            // ===== UBICACIÓN =====
            _buildLocationSelectionArea(),

            const SizedBox(height: 20),

            // ===== DESCRIPCIÓN =====
            _buildDescriptionSection(),

            const SizedBox(height: 20),

            // ===== BOTÓN FINALIZAR =====
            ElevatedButton(
              onPressed: _onFinishPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.planColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                "Crear Plan",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
          ),
        ),

        // Botón de cerrar
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 35,
              height: 35,
              decoration: const BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: AppColors.blue),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------------------------
  // ---------------------- TIPO DE PLAN (dropdown + custom) --------------------------
  // ----------------------------------------------------------------------------------
  Widget _buildTypeOfPlan() {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: _planButtonWidth,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
                border: Border.all(
                  color: const Color.fromARGB(255, 151, 121, 215),
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _customPlan ?? _selectedPlan ?? "Elige un plan",
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter-Regular',
                        fontSize: 14,
                        decoration: TextDecoration.none,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: Color.fromARGB(255, 227, 225, 231),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleDropdown() {
    if (_isDropdownOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    setState(() => _isDropdownOpen = true);
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isDropdownOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeDropdown,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(_dropdownOffsetX, _dropdownOffsetY),
            child: _buildDropdownMenu(),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownMenu() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withOpacity(0.1),
          child: Container(
            width: _dropdownWidth,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 165, 159, 159).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    alignment: WrapAlignment.start,
                    runAlignment: WrapAlignment.start,
                    spacing: 6,
                    runSpacing: 6,
                    children: plans.map((plan) {
                      final String name = plan['name'];
                      final bool selected = _selectedPlan == name;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedPlan = name;
                            _selectedIconAsset = plan['icon'];
                            _customPlan = null;
                          });
                          _closeDropdown();
                        },
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.planColor
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter-Regular',
                              fontSize: 14,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '- o -',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        _customPlan = value;
                        if (value.isNotEmpty) {
                          _selectedPlan = null;
                        }
                      });
                    },
                    style: const TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.none,
                      fontFamily: 'Inter-Regular',
                    ),
                    decoration: InputDecoration(
                      hintText: 'Escribe tu plan...',
                      hintStyle: const TextStyle(
                        color: Colors.white70,
                        decoration: TextDecoration.none,
                        fontFamily: 'Inter-Regular',
                      ),
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.8)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.8)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------------------
  // -------------------------- FECHA/HORA (igual que 2do snippet) --------------------
  // ----------------------------------------------------------------------------------
  Widget _buildDateTimeSection() {
    return GestureDetector(
      onTap: _showDateSelectionPopup,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              "Fecha y hora del plan",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Inter-Regular',
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color:
                      const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: _includeEndDate ? 140 : 100,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/icono-calendario.svg',
                          width: 30,
                          height: 30,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        _buildSelectedDatesPreview(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDatesPreview() {
    if (_startDate == null) {
      return const SizedBox.shrink(); // oculta el placeholder
    }
    final startDateText = _formatHumanReadableDateOnly(_startDate!);
    final startTimeText = (_allDay || _startTime == null)
        ? "todo el día"
        : "a las ${_formatHumanReadableTime(_startTime!)}";

    Widget? endDateWidget;
    if (_includeEndDate && _endDate != null) {
      final endDateText = _formatHumanReadableDateOnly(_endDate!);
      final endTimeText = (_allDay || _endTime == null)
          ? ""
          : " a las ${_formatHumanReadableTime(_endTime!)}";
      endDateWidget = Text(
        "Hasta $endDateText$endTimeText",
        style: const TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      );
    }

    return Column(
      children: [
        Text(
          "$startDateText${_allDay ? ' (todo el día)' : ''}"
          "${(!_allDay && _startTime != null) ? ' $startTimeText' : ''}",
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        if (endDateWidget != null) ...[
          const SizedBox(height: 6),
          endDateWidget,
        ],
      ],
    );
  }

  String _formatHumanReadableDateOnly(DateTime date) {
    final Map<int, String> weekdays = {
      1: "Lunes",
      2: "Martes",
      3: "Miércoles",
      4: "Jueves",
      5: "Viernes",
      6: "Sábado",
      7: "Domingo",
    };
    final Map<int, String> months = {
      1: "Enero",
      2: "Febrero",
      3: "Marzo",
      4: "Abril",
      5: "Mayo",
      6: "Junio",
      7: "Julio",
      8: "Agosto",
      9: "Septiembre",
      10: "Octubre",
      11: "Noviembre",
      12: "Diciembre",
    };
    String weekday = weekdays[date.weekday] ?? "";
    String monthName = months[date.month] ?? "";
    return "$weekday, ${date.day} de $monthName de ${date.year}";
  }

  String _formatHumanReadableTime(TimeOfDay time) {
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  void _showDateSelectionPopup() {
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => DateSelectionDialog(
        initialAllDay: _allDay,
        initialIncludeEndDate: _includeEndDate,
        initialStartDate: _startDate,
        initialStartTime: _startTime,
        initialEndDate: _endDate,
        initialEndTime: _endTime,
      ),
    ).then((result) {
      if (result != null) {
        setState(() {
          _allDay = result['allDay'] as bool;
          _includeEndDate = result['includeEndDate'] as bool;
          _startDate = result['startDate'] as DateTime?;
          _startTime = result['startTime'] as TimeOfDay?;
          _endDate = result['endDate'] as DateTime?;
          _endTime = result['endTime'] as TimeOfDay?;
        });
      }
    });
  }

  // ----------------------------------------------------------------------------------
  // ----------------------------- UBICACIÓN (Mapa) ------------------------------------
  // ----------------------------------------------------------------------------------
  Widget _buildLocationSelectionArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),
        const Center(
          child: Text(
            "Punto de encuentro para el Plan",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              decoration: TextDecoration.none,
              fontFamily: 'Inter-Regular',
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _navigateToMeetingLocation,
          child: (_latitude != null && _longitude != null)
              ? _buildLocationPreview()
              : ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      height: kLocationContainerHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 124, 120, 120)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icono-ubicacion.svg',
                          width: 30,
                          height: 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLocationPreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SizedBox(
            height: kLocationContainerHeight,
            width: double.infinity,
            child: FutureBuilder<BitmapDescriptor>(
              future: _markerIconFuture,
              builder: (context, snapshot) {
                final icon = snapshot.data ?? BitmapDescriptor.defaultMarker;
                if (_latitude == null || _longitude == null) {
                  return Container(color: Colors.white.withOpacity(0.2));
                }
                return GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_latitude!, _longitude!),
                    zoom: 16,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: LatLng(_latitude!, _longitude!),
                      icon: icon,
                      anchor: const Offset(0.5, 1.0),
                    ),
                  },
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  liteModeEnabled: false,
                );
              },
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.3),
                padding: const EdgeInsets.all(12),
                child: Text(
                  _location!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToMeetingLocation() async {
    final tempPlan = PlanModel(
      id: '',
      type: _customPlan ?? _selectedPlan ?? '',
      description: _planDescription ?? '',
      minAge: 18,
      maxAge: 99,
      location: _location ?? '',
      latitude: _latitude ?? 0.0,
      longitude: _longitude ?? 0.0,
      startTimestamp: DateTime.now(),
      finishTimestamp: DateTime.now().add(const Duration(days: 1)),
      createdBy: '',
    );

    final updatedPlan = await showGeneralDialog(
      context: context,
      barrierLabel: "Ubicación",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: SizedBox(
            width: 600,
            height: 400,
            child: MeetingLocationPopup(plan: tempPlan),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: anim1,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    );

    if (updatedPlan != null && updatedPlan is PlanModel) {
      setState(() {
        _location = updatedPlan.location;
        _latitude = updatedPlan.latitude;
        _longitude = updatedPlan.longitude;
      });
      _loadMarkerIcon();
    }
  }

  void _loadMarkerIcon() {
    _markerIconFuture = _getCustomSvgMarker(
      'assets/icono-ubicacion-interno.svg',
      AppColors.blue,
      width: 48,
      height: 48,
    );
    setState(() {});
  }

  Future<BitmapDescriptor> _getCustomSvgMarker(
    String assetPath,
    Color color, {
    double width = 48,
    double height = 48,
  }) async {
    // Carga el SVG como String
    final svgString =
        await DefaultAssetBundle.of(context).loadString(assetPath);
    // Reemplazamos fill por el color deseado
    final coloredSvgString = svgString.replaceAll(
      RegExp(r'fill="[^"]*"'),
      'fill="#${color.value.toRadixString(16).padLeft(8, "0")}"',
    );
    final svgDrawableRoot =
        await svg.fromSvgString(coloredSvgString, assetPath);
    final picture = svgDrawableRoot.toPicture(size: Size(width, height));
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // ----------------------------------------------------------------------------------
  // ------------------------------ DESCRIPCIÓN ---------------------------------------
  // ----------------------------------------------------------------------------------
  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            "Breve descripción del Plan",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
            borderRadius: BorderRadius.circular(30),
          ),
          child: TextField(
            maxLines: 3,
            onChanged: (value) => _planDescription = value,
            decoration: const InputDecoration(
              hintText: "Describe brevemente tu plan...",
              hintStyle: TextStyle(
                color: Colors.white70,
                fontFamily: 'Inter-Regular',
                decoration: TextDecoration.none,
              ),
              border: InputBorder.none,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Inter-Regular',
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------------------------
  // -------------------------- AL CREAR EL PLAN ("Finish") ---------------------------
  // ----------------------------------------------------------------------------------
  Future<void> _onFinishPlan() async {
    if (_selectedPlan == null &&
        (_customPlan == null || _customPlan!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Falta elegir tipo de plan.")),
      );
      return;
    }
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Falta elegir la fecha/hora del plan.")),
      );
      return;
    }
    if (_location == null || _location!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Falta elegir ubicación del plan.")),
      );
      return;
    }
    if (_planDescription == null || _planDescription!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Falta la breve descripción del plan.")),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Armamos la fecha/hora con lo seleccionado
      DateTime dateTime;
      if (_allDay) {
        dateTime =
            DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      } else {
        dateTime = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
          _startTime?.hour ?? 0,
          _startTime?.minute ?? 0,
        );
      }

      final planDoc = FirebaseFirestore.instance.collection('plans').doc();
      final planId = planDoc.id;

      final dataToSave = {
        "id": planId,
        "createdBy": currentUser.uid,
        "type": _customPlan?.isNotEmpty == true ? _customPlan : _selectedPlan,
        "description": _planDescription ?? '',
        "location": _location ?? '',
        "latitude": _latitude ?? 0.0,
        "longitude": _longitude ?? 0.0,
        "date": dateTime.toIso8601String(),
        "createdAt": DateTime.now().toIso8601String(),
        "privateInvite": true,
        "likes": 0,
        "views": 0,
        "viewedBy": [],
        "special_plan": 1,
      };

      await planDoc.set(dataToSave);

      // Enviamos notificación
      await _sendInvitationNotification(
        senderUid: currentUser.uid,
        receiverUid: widget.invitedUserId,
        planId: planId,
        planType: (dataToSave["type"] ?? "Plan").toString(),
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("¡Plan creado! Has invitado al usuario.")),
      );
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al crear el plan: $err")),
      );
    }
  }
}

// MÉTODOS AUXILIARES GLOBALES (idénticos al original)
// ***************************************************************************
Future<List<PlanModel>> _fetchActivePlans(String userId) async {
  final List<PlanModel> activePlans = [];
  final createdSnap = await FirebaseFirestore.instance
      .collection('plans')
      .where('createdBy', isEqualTo: userId)
      .get();
  for (var doc in createdSnap.docs) {
    final data = doc.data();
    final plan = PlanModel.fromMap(data);
    activePlans.add(plan);
  }
  activePlans.sort(
    (a, b) => (a.createdAt ?? DateTime.now())
        .compareTo(b.createdAt ?? DateTime.now()),
  );
  return activePlans;
}

Future<void> _sendInvitationNotification({
  required String senderUid,
  required String receiverUid,
  required String planId,
  required String planType,
}) async {
  final notiDoc = FirebaseFirestore.instance.collection('notifications').doc();
  await notiDoc.set({
    "id": notiDoc.id,
    "type": "invitation",
    "senderId": senderUid,
    "receiverId": receiverUid,
    "planId": planId,
    "planName": planType,
    "timestamp": FieldValue.serverTimestamp(),
    "read": false,
  });
}

/// ***************************************************************************
/// DIALOGO DE CONFIRMACIÓN CON FONDO FROSTED (igual al original)
/// ***************************************************************************
class _FrostedConfirmDialog extends StatelessWidget {
  final PlanModel plan;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _FrostedConfirmDialog({
    Key? key,
    required this.plan,
    required this.onConfirm,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withOpacity(0.2),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Confirmar invitación",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "¿Confirmas invitarle a este plan?",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const ui.Color.fromARGB(255, 222, 219, 219)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        plan.type,
                        style: const TextStyle(
                          color: AppColors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: onCancel,
                      child: const Text(
                        "No",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: onConfirm,
                      child: const Text(
                        "Sí",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
