import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import '../main/colors.dart';
import 'plan_description_screen.dart';
import '../models/plan_model.dart';

class NewPlanCreationScreen {
  /// Método estático para mostrar el pop-up sobre la ventana actual
  static void showPopup(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierLabel: "Nuevo Plan",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return Center(
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
                  Color(0xFF0D253F),
                  Color(0xFF1B3A57),
                  Color(0xFF12232E),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: _NewPlanPopupContent(),
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
}

class _NewPlanPopupContent extends StatefulWidget {
  @override
  __NewPlanPopupContentState createState() => __NewPlanPopupContentState();
}

class __NewPlanPopupContentState extends State<_NewPlanPopupContent> {
  // VARIABLES ORIGINALES
  String? _selectedPlan;
  String? _customPlan;
  IconData? _selectedIcon;
  bool _isDropdownOpen = false;
  OverlayEntry? _overlayEntry;
  double _separatorSpacing = 20.0;

  // Para posicionar dinámicamente el menú desplegable
  final LayerLink _layerLink = LayerLink();

  // Variables de ejemplo
  DateTime? _selectedDateTime;
  String? _location;
  int? _maxParticipants;
  int? _minAge;
  int? _maxAge;
  String? _planDescription;
  String? _selectedImage;

  // Ajustes de márgenes
  double headerHorizontalInset = 0;
  double fieldsHorizontalInset = 20;

  // Lista de planes (se elimina el ítem "Otro (Especificar)")
  final List<Map<String, dynamic>> _plans = [
    {'icon': Icons.sports_basketball, 'name': 'Baloncesto'},
    {'icon': Icons.book, 'name': 'Biblioteca'},
    {'icon': Icons.local_dining, 'name': 'Cena'},
    {'icon': Icons.shopping_cart, 'name': 'Compras'},
    {'icon': Icons.movie, 'name': 'Cine'},
    {'icon': Icons.coffee, 'name': 'Café'},
    {'icon': Icons.directions_bike, 'name': 'Ciclismo'},
    {'icon': Icons.music_note, 'name': 'Concierto'},
    {'icon': Icons.nature_people, 'name': 'Excursión'},
    {'icon': Icons.snowboarding, 'name': 'Esquí'},
  ];

  // Lógica dropdown
  void _toggleDropdown() {
    if (_isDropdownOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    setState(() {
      _isDropdownOpen = true;
    });
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context)!.insert(_overlayEntry!);
  }

  void _closeDropdown() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    setState(() {
      _isDropdownOpen = false;
    });
  }

  // Pop-up de selección de Plan con parámetros personalizables
  // Se incluye un TextField en la parte superior para input de texto personalizado
  OverlayEntry _createOverlayEntry() {
    // Calcula la posición exacta del "botón" dropdown.
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (BuildContext context) {
        return Stack(
          children: [
            // Dismiss si se hace tap fuera del dropdown
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeDropdown,
              ),
            ),
            // Menú desplegable con campo de texto personalizado y lista de planes
            Positioned(
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 44),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
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
                            // Campo de texto para input personalizado
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                onChanged: (value) {
                                  _customPlan = value;
                                  if (value.isNotEmpty) {
                                    _selectedIcon = Icons.lightbulb;
                                  }
                                },
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: "Escribe tu plan...",
                                  hintStyle:
                                      const TextStyle(color: Colors.white70),
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color:
                                            Colors.white.withOpacity(0.8)),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color:
                                            Colors.white.withOpacity(0.8)),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(
                                        color: Colors.white, width: 1.5),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                            // Separador
                            const Divider(
                              color: Colors.white30,
                              thickness: 0.3,
                              height: 0,
                            ),
                            // Lista de planes
                            Expanded(
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemCount: _plans.length,
                                itemBuilder: (context, index) {
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 4.0,
                                      ),
                                      dense: true,
                                      leading: Icon(
                                        _plans[index]['icon'],
                                        color: const Color.fromARGB(
                                            235, 229, 229, 252),
                                      ),
                                      title: Text(
                                        _plans[index]['name'],
                                        style: const TextStyle(
                                          color: Color.fromARGB(
                                              255, 218, 207, 207),
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _selectedPlan = _plans[index]['name'];
                                          _selectedIcon = _plans[index]['icon'];
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
        );
      },
    );
  }

  // Función para seleccionar imagen (paso 2)
  void _showImageSelectionPopup() {
    showGeneralDialog(
      context: context,
      barrierLabel: "Selecciona imagen",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D253F),
                  Color(0xFF1B3A57),
                  Color(0xFF12232E),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Selecciona una imagen",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedImage = "imagen_por_defecto";
                    });
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Imagen por defecto",
                    style: TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedImage = "imagen_de_galeria";
                    });
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Desde la galería",
                    style: TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedImage = "imagen_de_camara";
                    });
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Tomar una foto",
                    style: TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
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

  // Sección de selección de imagen (paso 2)
  Widget _buildImageSelectionArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Text(
          "Selecciona un fondo que represente a tu Plan",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            decoration: TextDecoration.none,
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _showImageSelectionPopup,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 124, 120, 120)
                      .withOpacity(0.2),
                  border: Border.all(
                    color: const Color.fromARGB(255, 151, 121, 215),
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: (_selectedImage == null)
                      ? SvgPicture.asset(
                          'assets/anadir-imagen.svg',
                          width: 30,
                          height: 30,
                          color: Colors.white,
                        )
                      : Text(
                          "Fondo seleccionado: $_selectedImage",
                          style: const TextStyle(color: Colors.white),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Función para contar los pasos (barra de progreso)
  int _countCompletedSteps() {
    int completed = 0;
    if (_selectedPlan != null || _customPlan != null) completed++;
    if (_selectedImage != null) completed++;
    if (_selectedDateTime != null) completed++;
    if (_location != null && _location!.isNotEmpty) completed++;
    if (_maxParticipants != null && _maxParticipants! > 0) completed++;
    if (_minAge != null && _maxAge != null && _minAge! <= _maxAge!) completed++;
    if (_planDescription != null && _planDescription!.isNotEmpty) completed++;
    return completed;
  }

  // Barra de progreso vertical (7 ranuras)
  Widget _buildVerticalProgressBar() {
    int completedSteps = _countCompletedSteps();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(7, (index) {
        final stepIndex = index + 1;
        bool isCompleted = stepIndex <= completedSteps;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          height: 15,
          width: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: isCompleted
                ? const LinearGradient(
                    colors: [Colors.blueAccent, Colors.blue],
                  )
                : null,
            color: isCompleted ? null : Colors.grey[300],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Contenido principal
        SingleChildScrollView(
          padding: const EdgeInsets.only(right: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER: Logo centrado
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: headerHorizontalInset),
                child: Center(
                  child: Image.asset(
                    'assets/plan-sin-fondo.png',
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Área de datos
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: fieldsHorizontalInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "¡Hazle saber a la gente el Plan que deseas compartir!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Roboto',
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // CompositedTransformTarget para anclar el Overlay
                    CompositedTransformTarget(
                      link: _layerLink,
                      child: GestureDetector(
                        onTap: _toggleDropdown,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              width: 260,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 124, 120, 120)
                                    .withOpacity(0.2),
                                border: Border.all(
                                  color: const Color.fromARGB(255, 151, 121, 215),
                                ),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        if (_selectedIcon != null)
                                          Icon(
                                            _selectedIcon,
                                            color: const Color.fromARGB(
                                                235, 229, 229, 252),
                                          ),
                                        if (_selectedIcon != null)
                                          const SizedBox(width: 10),
                                        Flexible(
                                          child: Text(
                                            _customPlan ??
                                                _selectedPlan ??
                                                "Elige un plan",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Roboto',
                                              fontSize: 14,
                                              decoration: TextDecoration.none,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColors.blue,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Selección de imagen solo si hay plan o customPlan
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, -0.3),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        );
                      },
                      child: ((_selectedPlan != null) ||
                              (_customPlan != null))
                          ? Column(
                              key: const ValueKey(1),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(height: _separatorSpacing),
                                Container(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                const SizedBox(height: 20),
                                _buildImageSelectionArea(),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 20),
                    // Botón finalizar (opcional)
                    ElevatedButton(
                      onPressed: () {
                        if ((_selectedPlan != null) ||
                            (_customPlan != null)) {
                          final plan = PlanModel(
                            id: '',
                            type: _customPlan ?? _selectedPlan!,
                            description: '',
                            minAge: 0,
                            maxAge: 0,
                            location: '',
                            date: DateTime.now(),
                            createdBy: '',
                          );
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PlanDescriptionScreen(plan: plan),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "Finalizar Plan",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Botón de cierre
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(0),
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: AppColors.blue,
              ),
            ),
          ),
        ),
        // Barra de progreso (derecha)
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          child: Container(
            width: 2,
            alignment: Alignment.center,
            child: _buildVerticalProgressBar(),
          ),
        ),
      ],
    );
  }
}
