import 'dart:ui' as ui; // Asegúrate de incluir esta línea
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Si usas una lista de planes predefinidos
import '../../../utils/plans_list.dart'; 
import '../../../models/plan_model.dart';
import '../../plan_creation/meeting_location_screen.dart';
import '../../../main/colors.dart';

/// ---------------------------------------------------------------------------
/// PANTALLA DE INVITAR USUARIOS A UN PLAN
/// ---------------------------------------------------------------------------
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
    final double popupWidth = MediaQuery.of(context).size.width * 0.66;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: popupWidth,
          padding: const EdgeInsets.all(20),
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
              // BOTÓN 1: PLAN YA EXISTENTE
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
              // BOTÓN 2: PLAN NUEVO
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

    // Se obtienen únicamente los planes creados por el usuario invitador
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
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Material(
                  color: Colors.white.withOpacity(0.3),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        const Text(
                          "Selecciona uno de tus planes",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Divider(color: Colors.white54),
                        Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
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
                                          "Creado el: ${plan.formattedDate(plan.createdAt)}",
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                        onTap: () {
                                          // Lanza el popup de confirmación frosted
                                          showGeneralDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            barrierLabel: "Confirmar invitación",
                                            barrierColor: Colors.black54,
                                            transitionDuration: const Duration(milliseconds: 300),
                                            pageBuilder: (context, animation, secondaryAnimation) {
                                              return const SizedBox();
                                            },
                                            transitionBuilder: (context, anim1, anim2, child) {
                                              return FadeTransition(
                                                opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
                                                child: ScaleTransition(
                                                  scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
                                                  child: Center(
                                                    child: _FrostedConfirmDialog(
                                                      plan: plan,
                                                      onConfirm: () {
                                                        // Cierra el diálogo y el popup de lista, luego invita
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
                ),
              ),
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

    // Envía notificación. Se usa "invitation" para que aparezca en NotificationScreen.
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

/// POPUP DE CREACIÓN DE PLAN PRIVADO (4 pasos: tipo, fecha/hora, ubicación, descripción)
void _showNewPlanForInvitation(BuildContext context, String invitedUserId) {
  showGeneralDialog(
    context: context,
    barrierLabel: "Nuevo Plan Privado",
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (context, anim1, anim2) {
      return Material(
        type: MaterialType.transparency,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20),
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
            child: Material(
              type: MaterialType.transparency,
              child: _NewPlanInviteContent(invitedUserId: invitedUserId),
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

class _NewPlanInviteContent extends StatefulWidget {
  final String invitedUserId;
  const _NewPlanInviteContent({Key? key, required this.invitedUserId})
      : super(key: key);

  @override
  State<_NewPlanInviteContent> createState() => _NewPlanInviteContentState();
}

class _NewPlanInviteContentState extends State<_NewPlanInviteContent> {
  // Paso 1: Tipo de plan
  String? _selectedPlan;
  String? _customPlan;
  String? _selectedIconAsset;
  IconData? _selectedIconData;
  bool _isDropdownOpen = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  // Paso 2: Fecha/hora
  bool _allDay = false;
  bool _includeEndDate = false;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  DateTime? _selectedDateTime; // se marca al confirmar fecha/hora

  // Paso 3: Ubicación
  String? _location;
  double? _latitude;
  double? _longitude;

  // Paso 4: Descripción
  String? _planDescription;

  // Para la barra de progreso (4 pasos)
  int _countCompletedSteps() {
    int completed = 0;
    if (_selectedPlan != null || _customPlan != null) completed++; // Tipo
    if (_selectedDateTime != null) completed++; // Fecha/hora
    if (_location != null && _location!.isNotEmpty) completed++; // Ubicación
    if (_planDescription != null && _planDescription!.isNotEmpty) completed++; // Descripción
    return completed;
  }

  Widget _buildProgressBar4Steps() {
    final completed = _countCompletedSteps();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isDone = (index + 1) <= completed;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          height: 15,
          width: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isDone ? Colors.blue : Colors.grey[300],
          ),
        );
      }),
    );
  }

  // -------------------------------------------------------------------------
  // UI: Dropdown para Tipo de Plan
  // -------------------------------------------------------------------------
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
                      width: 265,
                      height: 300,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 165, 159, 159)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
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
                                  borderSide:
                                      const BorderSide(color: Colors.white, width: 1.5),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const Divider(
                            color: Colors.white30,
                            thickness: 0.3,
                            height: 0,
                          ),
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

  // -------------------------------------------------------------------------
  // Selección de Fecha/Hora
  // -------------------------------------------------------------------------
  void _showDateSelectionPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Opción: Todo el día
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Todo el día", style: TextStyle(color: Colors.white)),
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  _allDay = !_allDay;
                                  if (_allDay) _startTime = null;
                                });
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: _allDay ? AppColors.blue : Colors.grey.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Opción: Incluir fecha final
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Incluir fecha final", style: TextStyle(color: Colors.white)),
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  _includeEndDate = !_includeEndDate;
                                  if (!_includeEndDate) {
                                    _endDate = null;
                                    _endTime = null;
                                  }
                                });
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: _includeEndDate ? AppColors.blue : Colors.grey.withOpacity(0.5),
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
                            const Text("Fecha de inicio", style: TextStyle(color: Colors.white)),
                            Row(
                              children: [
                                _buildSimpleButton(
                                  label: _startDate == null
                                      ? "Seleccionar"
                                      : _startDate!.toLocal().toString().split(' ')[0],
                                  onTap: () async {
                                    DateTime now = DateTime.now();
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: _startDate == null || _startDate!.isBefore(now)
                                          ? now
                                          : _startDate!,
                                      firstDate: now,
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        _startDate = picked;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                if (!_allDay)
                                  _buildSimpleButton(
                                    label: _startTime == null
                                        ? "Seleccionar"
                                        : _startTime!.format(context),
                                    onTap: () async {
                                      final t = await showTimePicker(
                                        context: context,
                                        initialTime: _startTime ?? TimeOfDay.now(),
                                      );
                                      if (t != null) {
                                        setDialogState(() {
                                          _startTime = t;
                                        });
                                      }
                                    },
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
                            const Text("Fecha final", style: TextStyle(color: Colors.white)),
                            _includeEndDate
                                ? Row(
                                    children: [
                                      _buildSimpleButton(
                                        label: _endDate == null
                                            ? "Seleccionar"
                                            : _endDate!.toLocal().toString().split(' ')[0],
                                        onTap: () async {
                                          DateTime firstPossible = _startDate ?? DateTime.now();
                                          if (firstPossible.isBefore(DateTime.now())) {
                                            firstPossible = DateTime.now();
                                          }
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: _endDate == null || _endDate!.isBefore(firstPossible)
                                                ? firstPossible
                                                : _endDate!,
                                            firstDate: firstPossible,
                                            lastDate: DateTime(2100),
                                          );
                                          if (picked != null) {
                                            setDialogState(() {
                                              _endDate = picked;
                                            });
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _buildSimpleButton(
                                        label: _endTime == null
                                            ? "Seleccionar"
                                            : _endTime!.format(context),
                                        onTap: () async {
                                          final t = await showTimePicker(
                                            context: context,
                                            initialTime: _endTime ?? TimeOfDay.now(),
                                          );
                                          if (t != null) {
                                            if (_startDate != null) {
                                              final startDt = DateTime(
                                                _startDate!.year,
                                                _startDate!.month,
                                                _startDate!.day,
                                                _startTime?.hour ?? 0,
                                                _startTime?.minute ?? 0,
                                              );
                                              final endDt = DateTime(
                                                _endDate!.year,
                                                _endDate!.month,
                                                _endDate!.day,
                                                t.hour,
                                                t.minute,
                                              );
                                              if (!endDt.isAfter(startDt)) {
                                                _showError("La fecha/hora final debe ser posterior a la inicial.");
                                                return;
                                              }
                                            }
                                            setDialogState(() {
                                              _endTime = t;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  )
                                : _buildSimpleButton(label: "Sin elegir", onTap: () {}),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            if (_startDate != null) {
                              DateTime finalDateTime;
                              if (!_allDay && _startTime != null) {
                                finalDateTime = DateTime(
                                  _startDate!.year,
                                  _startDate!.month,
                                  _startDate!.day,
                                  _startTime!.hour,
                                  _startTime!.minute,
                                );
                              } else {
                                finalDateTime = _startDate!;
                              }
                              setState(() {
                                _selectedDateTime = finalDateTime;
                              });
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue),
                          child: const Text("Aceptar", style: TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSimpleButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Ubicación
  // -------------------------------------------------------------------------
  void _navigateToMeetingLocation() async {
    // La línea conflictiva era 'date: DateTime.now()'. Se quita y se usan startTimestamp, finishTimestamp, o se deja nulo
    final planTemp = PlanModel(
      id: '',
      type: _customPlan ?? _selectedPlan ?? '',
      description: _planDescription ?? '',
      minAge: 18,
      maxAge: 99,
      location: _location ?? '',
      latitude: _latitude ?? 0.0,
      longitude: _longitude ?? 0.0,
      // date: DateTime.now(), // <-- Se elimina
      // Usamos startTimestamp y finishTimestamp, aunque aquí realmente no se usan para la ubicación
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
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.6,
            child: MeetingLocationPopup(plan: planTemp),
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
    }
  }

  Widget _buildLocationSelectionArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Container(
              height: 160,
              color: Colors.white.withOpacity(0.2),
              alignment: Alignment.center,
              child: _location == null || _location!.isEmpty
                  ? const Text(
                      "Seleccionar ubicación",
                      style: TextStyle(color: Colors.white70),
                    )
                  : Text(
                      _location!,
                      style: const TextStyle(color: Colors.white),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Finalizar Plan (Crea doc y envía notificación)
  // -------------------------------------------------------------------------
  bool get _areStepsComplete => _countCompletedSteps() == 4;

  Future<void> _onFinishPlan() async {
    if (!_areStepsComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Faltan campos por completar.")),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Ejemplo simple: guardamos en "plans" con un doc autogenerado
      final startTime = _startTime ?? const TimeOfDay(hour: 0, minute: 0);
      final dateTime = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
        !_allDay && _startTime != null ? _startTime!.hour : 0,
        !_allDay && _startTime != null ? _startTime!.minute : 0,
      );

      final planDoc = FirebaseFirestore.instance.collection('plans').doc();
      final planId = planDoc.id;

      final dataToSave = {
        "id": planId,
        "createdBy": currentUser.uid,
        // Si definiste plan.type en la BD, o usas "type" con tu valor
        "type": _customPlan?.isNotEmpty == true ? _customPlan : _selectedPlan,
        "description": _planDescription ?? '',
        "location": _location ?? '',
        "latitude": _latitude ?? 0.0,
        "longitude": _longitude ?? 0.0,

        // Podrías manejar start_timestamp y finish_timestamp, en lugar de "date"
        "date": dateTime.toIso8601String(), // Lo usas si así lo deseas
        "createdAt": DateTime.now().toIso8601String(),
        "privateInvite": true,
        "likes": 0,
        "special_plan": 1,
      };

      await planDoc.set(dataToSave);

      // Envía notificación de "invitation"
      await _sendInvitationNotification(
        senderUid: currentUser.uid,
        receiverUid: widget.invitedUserId,
        planId: planId,
        planType: (dataToSave["type"] ?? "Plan").toString(),
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("¡Plan creado! Has invitado al usuario.")),
      );
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al crear el plan: $err")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepsCompleted = _countCompletedSteps();
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              _buildTypeOfPlanSection(),
              const SizedBox(height: 20),
              if (_selectedPlan != null ||
                  (_customPlan != null && _customPlan!.isNotEmpty)) ...[
                _buildDateTimeSection(),
                const SizedBox(height: 20),
                if (_selectedDateTime != null) ...[
                  _buildLocationSelectionArea(),
                  const SizedBox(height: 20),
                  _buildDescriptionSection(),
                ],
              ],
              const SizedBox(height: 20),
              if (stepsCompleted == 4)
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
        ),
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
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          child: Container(
            width: 2,
            alignment: Alignment.center,
            child: _buildProgressBar4Steps(),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeOfPlanSection() {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 260,
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
                  Flexible(
                    child: Text(
                      _customPlan ?? _selectedPlan ?? "Elige un plan",
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeSection() {
    return GestureDetector(
      onTap: _showDateSelectionPopup,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white.withOpacity(0.2),
            child: Column(
              children: [
                SvgPicture.asset(
                  'assets/icono-calendario.svg',
                  width: 30,
                  height: 30,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedDateTime == null
                      ? "Seleccionar fecha/hora"
                      : "Fecha/hora seleccionada",
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Breve descripción del plan",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            decoration: TextDecoration.none,
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
            onChanged: (value) {
              setState(() {
                _planDescription = value;
              });
            },
            decoration: const InputDecoration(
              hintText: "Describe brevemente tu plan...",
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// MÉTODOS AUXILIARES GLOBALES
/// ----------------------------------------------------------------------------

/// Obtiene los planes creados por [userId].
Future<List<PlanModel>> _fetchActivePlans(String userId) async {
  final List<PlanModel> activePlans = [];

  // Solo se obtienen los planes creados por el usuario
  final createdSnap = await FirebaseFirestore.instance
      .collection('plans')
      .where('createdBy', isEqualTo: userId)
      .get();
  for (var doc in createdSnap.docs) {
    final data = doc.data();
    final plan = PlanModel.fromMap(data);
    activePlans.add(plan);
  }

  // Ordena por fecha de creación
  activePlans.sort(
    (a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()),
  );
  return activePlans;
}

/// Envía una notificación de "invitation".
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

/// ---------------------------------------------------------------------------
/// Diálogo simple con fondo frosted para confirmar la invitación a un plan.
/// ---------------------------------------------------------------------------
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
            width: MediaQuery.of(context).size.width * 0.8,
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                // Muestra el plan.type
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const ui.Color.fromARGB(255, 222, 219, 219).withOpacity(0.2),
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
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
