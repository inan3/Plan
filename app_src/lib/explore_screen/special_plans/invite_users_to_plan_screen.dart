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
import '../../../main/colors.dart';
import '../../services/language_service.dart';
import '../../l10n/app_localizations.dart';

/// ***************************************************************************
/// CONSTANTES DE ANCHOS Y ALTOS FIJOS (SIN MEDIAQUERY)
/// ***************************************************************************
const double kMainPopupWidth = 500; 
const double kMainPopupPadding = 20;

const double kNewPlanPopupWidth = 380; 
const double kNewPlanPopupHeight = 750; 
const double kNewPlanPadding = 20;

const double kPlanTypeSectionWidth   = 320;
const double kPlanTypeDropdownWidth  = 310;
const double kPlanTypeDropdownHeight = 365;

const double kDateTimeSectionWidth   = 300;
const double kLocationContainerHeight = 160;

/// ***************************************************************************
/// CLASE PRINCIPAL InviteUsersToPlanScreen
/// ***************************************************************************
class InviteUsersToPlanScreen {
  static void showPopup(BuildContext context, String invitedUserId) {
    showGeneralDialog(
      context: context,
      barrierLabel: AppLocalizations.of(context).invitePlanLabel,
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
              Text(
                AppLocalizations.of(context).invitePlanTitle,
                style: const TextStyle(
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
                child: Text(
                  AppLocalizations.of(context).existing,
                  style: const TextStyle(
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
                child: Text(
                  AppLocalizations.of(context).newLabel,
                  style: const TextStyle(
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
          title: Text(AppLocalizations.of(context).noPlansTitle),
          content: Text(AppLocalizations.of(context).createNewQuestion),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _onInviteNewPlan();
              },
              child: Text(AppLocalizations.of(context).accept),
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
            width: 600,
            height: 400,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withOpacity(0.3),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).selectOneOfYourPlans,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
                              child: ListTile(
                                title: Text(
                                  plan.type,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  AppLocalizations.of(context)
                                      .createdOn(plan.formattedDate(plan.createdAt)),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                onTap: () {
                                  showGeneralDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    barrierLabel: AppLocalizations.of(context).confirmInvitation,
                                    barrierColor: Colors.black54,
                                    transitionDuration:
                                        const Duration(milliseconds: 300),
                                    pageBuilder: (context, animation, secondaryAnimation) {
                                      return const SizedBox();
                                    },
                                    transitionBuilder: (context, anim1, anim2, child) {
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
                              ),
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
      SnackBar(
        content: Text(AppLocalizations.of(context)
            .planInvited
            .replaceFirst('{plan}', plan.type)),
      ),
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
      barrierLabel: AppLocalizations.of(context).newPrivatePlanLabel,
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
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Container(
                  // OJO: Quitamos el alto fijo
                  width: kNewPlanPopupWidth,
                  // height: kNewPlanPopupHeight, // <-- Eliminado
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Image.asset('assets/plan-sin-fondo.png', height: 70),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                AppLocalizations.of(context).privatePlanInviteTitle,
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
                backgroundColor: const Color.fromARGB(235, 17, 19, 135),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                "Finalizar Plan",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
                border: Border.all(
                  color: const Color.fromARGB(255, 151, 121, 215),
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  if (_selectedIconAsset != null)
                    SvgPicture.asset(
                      _selectedIconAsset!,
                      width: 28,
                      height: 28,
                      color: Colors.white,
                    ),
                  if (_selectedIconData != null)
                    Icon(_selectedIconData, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _customPlan ?? _selectedPlan ?? "Elige un plan",
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
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
          Positioned(
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 44),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.1),
                    child: Container(
                      width: kPlanTypeDropdownWidth,
                      height: kPlanTypeDropdownHeight,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 165, 159, 159)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Campo de texto para plan personalizado
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextField(
                              onChanged: (value) {
                                _customPlan = value;
                                if (value.isNotEmpty) {
                                  _selectedIconData = Icons.lightbulb;
                                  _selectedIconAsset = null;
                                }
                              },
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "Escribe tu plan...",
                                hintStyle: const TextStyle(
                                  color: Colors.white70,
                                  decoration: TextDecoration.none,
                                ),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.8)),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.8)),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                      color: Colors.white, width: 1.5),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const Divider(
                            color: Colors.white30,
                            thickness: 0.3,
                            height: 0,
                          ),
                          // Listado de planes predefinidos
                          Expanded(
                            child: ListView.builder(
                              itemCount: plans.length,
                              itemBuilder: (context, index) {
                                final item = plans[index];
                                return Container(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.white,
                                        width: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    leading: SvgPicture.asset(
                                      item['icon'],
                                      width: 28,
                                      height: 28,
                                      color: const Color.fromARGB(235, 229, 229, 252),
                                    ),
                                    title: Text(
                                      item['name'],
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedPlan = item['name'];
                                        _selectedIconAsset = item['icon'];
                                        _selectedIconData = null;
                                        _customPlan = null;
                                      });
                                      _closeDropdown();
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
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
              "Fecha y hora del Plan",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
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
                  color: const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
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
        ],
      ),
    );
  }

  Widget _buildSelectedDatesPreview() {
    if (_startDate == null) {
      return const Text(
        "Haz clic para seleccionar fecha/hora",
        style: TextStyle(color: Colors.white70),
      );
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
        const Center(
          child: Text(
            "Punto de encuentro del Plan",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _navigateToMeetingLocation,
          child: (_location != null && _location!.isNotEmpty)
              ? _buildLocationPreview()
              : ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      height: kLocationContainerHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        "Toca aquí para eleccionar ubicación",
                        style: TextStyle(color: Colors.white70),
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
              filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.3),
                padding: const EdgeInsets.all(8),
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
    final svgString = await DefaultAssetBundle.of(context).loadString(assetPath);
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
          width: 400,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
            borderRadius: BorderRadius.circular(30),
          ),
          child: TextField(
            maxLines: 3,
            onChanged: (value) => _planDescription = value,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).describePlanHint,
              hintStyle: const TextStyle(color: Colors.white70),
              border: InputBorder.none,
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------------------------
  // -------------------------- AL CREAR EL PLAN ("Finish") ---------------------------
  // ----------------------------------------------------------------------------------
  Future<void> _onFinishPlan() async {
    if (_selectedPlan == null && (_customPlan == null || _customPlan!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).choosePlanTypeMissing)),
      );
      return;
    }
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).chooseDateMissing)),
      );
      return;
    }
    if (_location == null || _location!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).chooseLocationMissing)),
      );
      return;
    }
    if (_planDescription == null || _planDescription!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).chooseDescriptionMissing)),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Armamos la fecha/hora con lo seleccionado
      DateTime dateTime;
      if (_allDay) {
        dateTime = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
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
        SnackBar(content: Text(AppLocalizations.of(context).planCreatedInvitedUser)),
      );
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)
              .planCreationError
              .replaceFirst('{error}', err.toString())),
        ),
      );
    }
  }
}

// ***************************************************************************
// Dialogo para seleccionar fecha/hora (copiado del 2do snippet)
// ***************************************************************************
class DateSelectionDialog extends StatefulWidget {
  final bool initialAllDay;
  final bool initialIncludeEndDate;
  final DateTime? initialStartDate;
  final TimeOfDay? initialStartTime;
  final DateTime? initialEndDate;
  final TimeOfDay? initialEndTime;

  const DateSelectionDialog({
    Key? key,
    required this.initialAllDay,
    required this.initialIncludeEndDate,
    required this.initialStartDate,
    required this.initialStartTime,
    required this.initialEndDate,
    required this.initialEndTime,
  }) : super(key: key);

  @override
  _DateSelectionDialogState createState() => _DateSelectionDialogState();
}

class _DateSelectionDialogState extends State<DateSelectionDialog> {
  late bool allDay;
  late bool includeEndDate;
  DateTime? startDate;
  TimeOfDay? startTime;
  DateTime? endDate;
  TimeOfDay? endTime;

  @override
  void initState() {
    super.initState();
    allDay = widget.initialAllDay;
    includeEndDate = widget.initialIncludeEndDate;
    startDate = widget.initialStartDate;
    startTime = widget.initialStartTime;
    endDate = widget.initialEndDate;
    endTime = widget.initialEndTime;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Todo el día
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context).allDay,
                          style: const TextStyle(color: Colors.white)),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            allDay = !allDay;
                            if (allDay) startTime = null;
                          });
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: allDay ? AppColors.blue : Colors.grey.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Incluir fecha final
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context).includeEndDate, style: TextStyle(color: Colors.white)),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            includeEndDate = !includeEndDate;
                            if (!includeEndDate) {
                              endDate = null;
                              endTime = null;
                            }
                          });
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: includeEndDate
                                ? AppColors.blue
                                : Colors.grey.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Fecha de inicio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context).startDate, style: TextStyle(color: Colors.white)),
                      Row(
                        children: [
                          _buildButton(
                            label: (startDate == null) ? AppLocalizations.of(context).pickDay
                                : _numericDate(startDate!),
                            onTap: _pickStartDate,
                          ),
                          const SizedBox(width: 8),
                          if (!allDay)
                            _buildButton(
                              label: (startTime == null)
                                  ? AppLocalizations.of(context).pickTime
                                  : _numericTime(startTime!),
                              onTap: _pickStartTime,
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Fecha final
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context).endDate, style: TextStyle(color: Colors.white)),
                      includeEndDate
                          ? Row(
                              children: [
                                _buildButton(
                                  label: (endDate == null)
                                      ? AppLocalizations.of(context).pickDay
                                      : _numericDate(endDate!),
                                  onTap: _pickEndDate,
                                ),
                                const SizedBox(width: 8),
                                _buildButton(
                                  label: (endTime == null)
                                      ? AppLocalizations.of(context).pickTime
                                      : _numericTime(endTime!),
                                  onTap: _pickEndTime,
                                ),
                              ],
                            )
                          : _buildButton(
                              label: AppLocalizations.of(context).notChosen,
                              onTap: () {},
                            ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'allDay': allDay,
                        'includeEndDate': includeEndDate,
                        'startDate': startDate,
                        'startTime': startTime,
                        'endDate': endDate,
                        'endTime': endTime,
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue),
                    child: Text(AppLocalizations.of(context).accept, style: TextStyle(color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: Text(
                      AppLocalizations.of(context).cancel,
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (startDate == null || startDate!.isBefore(now)) ? now : startDate!,
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        startDate = picked;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        startTime = picked;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final minDate = (startDate != null && startDate!.isAfter(now)) ? startDate! : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: (endDate == null || endDate!.isBefore(minDate)) ? minDate : endDate!,
      firstDate: minDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        endDate = picked;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: endTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      if (startDate != null && endDate != null) {
        final st = (allDay || startTime == null)
            ? DateTime(startDate!.year, startDate!.month, startDate!.day)
            : DateTime(
                startDate!.year,
                startDate!.month,
                startDate!.day,
                startTime!.hour,
                startTime!.minute,
              );
        final et = DateTime(
          endDate!.year,
          endDate!.month,
          endDate!.day,
          picked.hour,
          picked.minute,
        );
        if (!et.isAfter(st)) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(AppLocalizations.of(context).error),
              content: const Text(
                "La fecha final debe ser posterior a la fecha/hora de inicio.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context).accept),
                )
              ],
            ),
          );
          return;
        }
      }
      setState(() {
        endTime = picked;
      });
    }
  }

  String _numericDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return "$d/$m/$y";
  }

  String _numericTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return "$h:$mm";
  }
}

// ***************************************************************************
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
    (a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()),
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
                Text(
                  AppLocalizations.of(context).confirmInvitation,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).inviteConfirmationQuestion,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    child: Text(
                      AppLocalizations.of(context).cancel,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
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
                    child: Text(
                      AppLocalizations.of(context).accept,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
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
