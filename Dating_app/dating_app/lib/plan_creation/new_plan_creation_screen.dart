import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import '../main/colors.dart';
import 'plan_description_screen.dart';
import '../models/plan_model.dart';

class NewPlanCreationScreen {
  /// Método estático para mostrar el pop up sobre la ventana actual
  static void showPopup(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierLabel: "Nuevo Plan",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5), // Fondo semitransparente
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
                  Color(0xFF0D253F), // Azul oscuro metálico
                  Color(0xFF1B3A57),
                  Color(0xFF12232E),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 10,
                  offset: Offset(0, 5),
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
  String? _selectedPlan;
  String? _customPlan;
  IconData? _selectedIcon;
  bool _isDropdownOpen = false;
  OverlayEntry? _overlayEntry;

  // Lista de planes (conserva todos los tipos)
  final List<Map<String, dynamic>> _plans = [
    {'icon': Icons.lightbulb, 'name': 'Otro (Especificar)'},
    {'icon': Icons.sports_basketball, 'name': 'Baloncesto'},
    {'icon': Icons.book, 'name': 'Biblioteca'},
    {'icon': Icons.local_dining, 'name': 'Cena'},
    {'icon': Icons.shopping_cart, 'name': 'Compras'},
    {'icon': Icons.movie, 'name': 'Cine'},
    {'icon': Icons.coffee, 'name': 'Café'},
    {'icon': Icons.directions_bike, 'name': 'Ciclismo'},
    {'icon': Icons.music_note, 'name': 'Concierto'},
    {'icon': Icons.nature_people, 'name': 'Excursión'},
    {'icon': Icons.beach_access, 'name': 'Playa'},
    {'icon': Icons.pool, 'name': 'Natación'},
    {'icon': Icons.brush, 'name': 'Pintura'},
    {'icon': Icons.camera, 'name': 'Fotografía'},
    {'icon': Icons.fitness_center, 'name': 'Gimnasio'},
    {'icon': Icons.local_florist, 'name': 'Jardinería'},
    {'icon': Icons.flight_takeoff, 'name': 'Viaje'},
    {'icon': Icons.theater_comedy, 'name': 'Teatro'},
    {'icon': Icons.sports_soccer, 'name': 'Fútbol'},
    {'icon': Icons.directions_run, 'name': 'Correr'},
    {'icon': Icons.work, 'name': 'Trabajo'},
    {'icon': Icons.school, 'name': 'Estudiar'},
    {'icon': Icons.pets, 'name': 'Paseo con mascotas'},
    {'icon': Icons.gamepad, 'name': 'Videojuegos'},
    {'icon': Icons.sports_mma, 'name': 'Boxeo'},
    {'icon': Icons.sports_volleyball, 'name': 'Voleibol'},
    {'icon': Icons.directions_walk, 'name': 'Senderismo'},
    {'icon': Icons.nightlife, 'name': 'Discoteca'},
    {'icon': Icons.volunteer_activism, 'name': 'Voluntariado'},
    {'icon': Icons.kitchen, 'name': 'Cocinar'},
    {'icon': Icons.golf_course, 'name': 'Golf'},
    {'icon': Icons.bike_scooter, 'name': 'Patinaje'},
    {'icon': Icons.home, 'name': 'Reunión en casa'},
    {'icon': Icons.public, 'name': 'Visitar monumentos'},
    {'icon': Icons.art_track, 'name': 'Museos'},
    {'icon': Icons.wb_sunny, 'name': 'Camping'},
    {'icon': Icons.gesture, 'name': 'Yoga'},
    {'icon': Icons.restaurant_menu, 'name': 'Degustación de comida'},
    {'icon': Icons.attractions, 'name': 'Parque de atracciones'},
    {'icon': Icons.rowing, 'name': 'Remo'},
    {'icon': Icons.accessibility_new, 'name': 'Zumba'},
    {'icon': Icons.handyman, 'name': 'Talleres'},
    {'icon': Icons.shopping_bag, 'name': 'Mercados'},
    {'icon': Icons.water, 'name': 'Pesca'},
    {'icon': Icons.auto_awesome, 'name': 'Fotografía nocturna'},
    {'icon': Icons.sports_tennis, 'name': 'Tenis'},
    {'icon': Icons.local_bar, 'name': 'Bar'},
    {'icon': Icons.fireplace, 'name': 'Fogata'},
    {'icon': Icons.car_repair, 'name': 'Rally'},
    {'icon': Icons.snowboarding, 'name': 'Esquí'},
  ];

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

  // Overlay para la lista desplegable con efecto frosted glass (cristalino)
  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _closeDropdown,
        child: Stack(
          children: [
            Positioned(
              left: 76,
              top: 360,
              width: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    color: const Color.fromARGB(255, 165, 159, 159).withOpacity(0.2),
                    child: Container(
                      height: 400,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: ListView.builder(
                        itemCount: _plans.length,
                        itemBuilder: (context, index) {
                          return Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white,
                                  width: 0.3, // Línea fina blanca
                                ),
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                _plans[index]['icon'],
                                color: const Color.fromARGB(235, 229, 229, 252),
                              ),
                              title: Text(
                                _plans[index]['name'],
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 218, 207, 207),
                                  fontFamily: 'Roboto',
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              onTap: () {
                                if (_plans[index]['name'] == 'Otro (Especificar)') {
                                  _closeDropdown();
                                  _showCustomPlanDialog();
                                } else {
                                  setState(() {
                                    _selectedPlan = _plans[index]['name'];
                                    _selectedIcon = _plans[index]['icon'];
                                    _customPlan = null;
                                  });
                                  _closeDropdown();
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pop up para "Otro (Especificar)" con posición y dimensiones definidas
  void _showCustomPlanDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
            Positioned(
              left: 76,
              top: 380,
              width: 260,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 151, 149, 149).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Pon un nombre a tu Plan",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          maxLength: 30,
                          controller: TextEditingController(text: _customPlan ?? ''),
                          onChanged: (value) {
                            _customPlan = value;
                          },
                          style: const TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                          decoration: InputDecoration(
                            hintText: "Introduce...",
                            hintStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white, width: 1.5),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                "Cancelar",
                                style: TextStyle(
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _customPlan = (_customPlan?.isNotEmpty ?? false)
                                      ? _customPlan
                                      : null;
                                  _selectedPlan = null;
                                  _selectedIcon = Icons.lightbulb;
                                });
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                "Aceptar",
                                style: TextStyle(
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
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
            ),
          ],
        );
      },
    );
  }

  // Función para mostrar la región adicional de selección de imagen,
  // que aparece animadamente justo debajo del desplegable, solo cuando se ha elegido un plan.
  Widget _buildImageSelectionArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          "Genial, ahora elige un fondo que represente a tu Plan",
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
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[850]!.withOpacity(0.5),
                  border: Border.all(color: Colors.white.withOpacity(0.8)),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/anadir-imagen.svg',
                    width: 40,
                    height: 40,
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

  // Función que muestra un pop up para elegir imágenes (puedes personalizarla)
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
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 10,
                  offset: Offset(0, 5),
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
                // Aquí podrías agregar opciones:
                // • Imagenes por defecto (por ejemplo, en un GridView)
                // • Opción para abrir la galería
                // • Opción para tomar una foto
                // Por simplicidad, mostramos tres botones de ejemplo:
                TextButton(
                  onPressed: () {
                    // Implementa la acción para imagen por defecto
                  },
                  child: const Text(
                    "Imagen por defecto",
                    style: TextStyle(color: Colors.white, decoration: TextDecoration.none),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Implementa la acción para elegir de la galería
                  },
                  child: const Text(
                    "Desde la galería",
                    style: TextStyle(color: Colors.white, decoration: TextDecoration.none),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Implementa la acción para tomar una foto
                  },
                  child: const Text(
                    "Tomar una foto",
                    style: TextStyle(color: Colors.white, decoration: TextDecoration.none),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Botón de cierre en la esquina superior derecha
        Align(
          alignment: Alignment.topRight,
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Container(
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
        const SizedBox(height: 10),
        // Logo
        Image.asset(
          'assets/plan-sin-fondo.png',
          height: 80,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 10),
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
        // Desplegable para seleccionar el tipo de plan con efecto frosted glass
        GestureDetector(
          onTap: _toggleDropdown,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 260,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 124, 120, 120).withOpacity(0.2),
                  border: Border.all(color: const Color.fromARGB(255, 151, 121, 215)!),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (_selectedIcon != null)
                            Icon(_selectedIcon, color: const Color.fromARGB(235, 229, 229, 252)),
                          if (_selectedIcon != null)
                            const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _customPlan ?? _selectedPlan ?? "Elige un plan",
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
        // Aquí se muestra la nueva región de selección de fondo solo si se ha elegido un plan.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.3),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
          child: (_selectedPlan != null)
              ? _buildImageSelectionArea()
              : const SizedBox.shrink(),
        ),
        const Spacer(),
        // Botón para proceder a la siguiente acción
        Align(
          alignment: Alignment.bottomRight,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.blue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 32,
              ),
              onPressed: () {
                if (_selectedPlan != null || _customPlan != null) {
                  final plan = PlanModel(
                    id: '', // Se generará más adelante
                    type: _customPlan ?? _selectedPlan!,
                    description: '',
                    minAge: 0,
                    maxAge: 0,
                    location: '',
                    date: DateTime.now(),
                    createdBy: '', // Reemplaza con el ID del usuario actual
                  );
                  Navigator.pop(context); // Cierra el pop up
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlanDescriptionScreen(plan: plan),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
